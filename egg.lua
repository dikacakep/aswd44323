local HttpService = game:GetService("HttpService")
local player = game:GetService("Players").LocalPlayer

-- UI Reference
local eggShop = player.PlayerGui:WaitForChild("PetShop_UI", 5)
local frame = eggShop:WaitForChild("Frame", 5)
local eggLocations = frame:WaitForChild("ScrollingFrame", 5)
local timerEgg = player.PlayerGui.PetShop_UI.Frame.Frame:WaitForChild("Timer", 5)

-- Webhook URL
local webhookEgg = "https://discord.com/api/webhooks/1380214366422700052/riWFfin5nJTqHWAzYU86lYFJXX8rXhXGyCgEu-K-fGlisx0DpYpXnprNzyfN8f4rhUHc"

-- Check if UI elements are found
if not eggLocations or not timerEgg then
    warn("Gagal menemukan eggLocations atau timerEgg. Periksa struktur UI!")
    return
end

-- Emoji map for eggs
local emojiMap = {
    ["Common Egg"] = "🥚", ["Bee Egg"] = "🥚", ["Uncommon Egg"] = "🥚", ["Rare Egg"] = "🍳", ["Legendary Egg"] = "🍳",
    ["Mythical Egg"] = "🐣", ["Paradise Egg"] = "🐣", ["Rare Summer Egg"] = "🐣", ["Common Summer Egg"] = "🐣", ["Bug Egg"] = "🐣", ["Night Egg"] = "🥚"
}

-- Last sent minute and previous stock
local lastSentMinute = -1
local eggFrames = {}
local previousStocks = {}
local maxRetryAttempts = 5
local retryDelay = 0

-- Initialize cache for egg frames
for eggName, _ in pairs(emojiMap) do
    local eggPath = eggLocations:FindFirstChild(eggName)
    if eggPath and eggPath:IsA("Frame") then
        local mainFrame = eggPath:FindFirstChild("Main_Frame")
        local stockLabel = mainFrame and mainFrame:FindFirstChild("Stock_Text")
        if stockLabel and stockLabel:IsA("TextLabel") then
            eggFrames[eggName] = stockLabel
            previousStocks[eggName] = -1
        end
    end
end

local function getStock(stockLabel)
    local stockText = stockLabel.Text:match("X(%d+)")
    return stockText and tonumber(stockText) or nil
end

local function extractEggs()
    local result = {}
    local seen = {}
    local threads = {}

    for eggName, stockLabel in pairs(eggFrames) do
        table.insert(threads, coroutine.create(function()
            local stock = getStock(stockLabel)
            local emoji = emojiMap[eggName]
            if stock and stock > 0 and not seen[eggName] then
                seen[eggName] = true
                table.insert(result, {
                    key = "Egg_" .. eggName,
                    name = eggName,
                    displayName = emoji ~= "" and (emoji .. " " .. eggName) or eggName,
                    stock = stock
                })
            end
        end))
    end

    for _, thread in ipairs(threads) do
        coroutine.resume(thread)
    end
    return result
end

local function sendEmbed(lines)
    if #lines == 0 then return false end
    local payload = HttpService:JSONEncode({
        embeds = {{
            title = "🥚 DIKAGAMTENG • Egg Stocks",
            color = 0x57F287,
            fields = {{
                name = "Egg Stock Update",
                value = table.concat(lines, "\n"),
                inline = false
            }},
            timestamp = DateTime.now():ToIsoDate()
        }}
    })
    local success, result = pcall(function()
        return request({
            Url = webhookEgg,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = payload
        })
    end)
    if not success then
        warn("Webhook failed: " .. tostring(result))
    end
    return success
end

local function stocksAreDifferent(newEggs)
    local isDifferent = false
    for _, egg in ipairs(newEggs) do
        local previousStock = previousStocks[egg.name] or -1
        if egg.stock ~= previousStock then
            isDifferent = true
        end
        previousStocks[egg.name] = egg.stock
    end
    return isDifferent
end

local function checkAndSendEggs()
    local eggs = {}
    local attempts = 0
    local hasChanges = false

    while attempts < maxRetryAttempts do
        eggs = extractEggs()
        if stocksAreDifferent(eggs) then
            hasChanges = true
            break
        end
        attempts = attempts + 1
        if retryDelay > 0 then
            task.wait(retryDelay)
        end
    end

    if not hasChanges then
        return
    end

    local lines = {}
    for _, egg in ipairs(eggs) do
        table.insert(lines, egg.displayName .. " **x" .. egg.stock .. "**")
    end

    if #lines > 0 and sendEmbed(lines) then
        lastSentMinute = os.date("*t").min
        print("Webhook terkirim: " .. os.time())
    end
end

local function monitorEggs()
    timerEgg:GetPropertyChangedSignal("Text"):Connect(function()
        local nowText = timerEgg.Text
        if nowText == "00:00:00" or nowText == "Restocking..." or string.match(nowText, "^00:0[0-2]:") or string.match(nowText, "^04:5[0-9]:") or string.match(nowText, "^05:0[0-9]:") then
            print("Timer triggered: " .. nowText)
            task.spawn(checkAndSendEggs)
        end
    end)
    while true do
        task.spawn(checkAndSendEggs)
        task.wait()
    end
end

-- Start monitoring eggs
task.spawn(monitorEggs)