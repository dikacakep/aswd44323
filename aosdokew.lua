local HttpService = game:GetService("HttpService")
local player = game:GetService("Players").LocalPlayer

-- UI Reference
local gearShop = player.PlayerGui:WaitForChild("Gear_Shop", 5)
local frame = gearShop:WaitForChild("Frame", 5)
local gearFrame = frame:WaitForChild("ScrollingFrame", 5)
local timerGear = player.PlayerGui.Gear_Shop.Frame.Frame:WaitForChild("Timer", 5)

-- Webhook URL
local webhookGear = "https://discord.com/api/webhooks/1380214167889379378/vzIRr2W4_ug9Zs1Lj89a81XayIj3FwLzJko0OSBZInmfT3ymjp__poAQomL5DaZdCiti"

if not gearFrame or not timerGear then
    warn("Gagal menemukan gearFrame atau timerGear. Periksa struktur UI!")
    return
end

local emojiMap = {
    ["Watering Can"] = "🚿", ["Magnifying Glass"] = "🛠", ["Tanning Mirror"] = "🛠", ["Levelup Lollipop"] = "🛠", ["Medium Toy"] = "🛠", ["Medium Treat"] = "🛠", ["Trowel"] = "🛠", ["Recall Wrench"] = "🔧", ["Basic Sprinkler"] = "💧",
    ["Advanced Sprinkler"] = "💧", ["Godly Sprinkler"] = "💦", ["Master Sprinkler"] = "💦", ["Grandmaster Sprinkler"] = "⚡", ["Trading Ticket"] = "⚡", ["Lightning Rod"] = "⚡",
    ["Favorite Tool"] = "❤", ["Friendship Pot"] = "🫂", ["Cleaning Spray"] = "💦", ["Harvest Tool"] = "🚜"
}

local lastSentMinute = -1
local gearFrames = {}
local previousStocks = {}
local maxRetryAttempts = 5
local retryDelay = 0

-- Inisialisasi cache frame
for gearName, _ in pairs(emojiMap) do
    local gearPath = gearFrame:FindFirstChild(gearName)
    if gearPath and gearPath:IsA("Frame") then
        local mainFrame = gearPath:FindFirstChild("Main_Frame")
        local stockLabel = mainFrame and mainFrame:FindFirstChild("Stock_Text")
        if stockLabel and stockLabel:IsA("TextLabel") then
            gearFrames[gearName] = stockLabel
            previousStocks[gearName] = -1
        end
    end
end

local function getStock(stockLabel)
    local stockText = stockLabel.Text:match("X(%d+)")
    return stockText and tonumber(stockText) or nil
end

local function extractGears()
    local result = {}
    local seen = {}
    local threads = {}

    for gearName, stockLabel in pairs(gearFrames) do
        table.insert(threads, coroutine.create(function()
            local stock = getStock(stockLabel)
            local emoji = emojiMap[gearName]
            if stock and stock > 0 and not seen[gearName] then
                seen[gearName] = true
                table.insert(result, {
                    key = "Gear_" .. gearName,
                    name = gearName,
                    displayName = emoji ~= "" and (emoji .. " " .. gearName) or gearName,
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
            title = "🛠️ DIKAGAMTENG • Gear Stocks",
            color = 0xF1C40F,
            fields = {{
                name = "Gear Stock Update",
                value = table.concat(lines, "\n"),
                inline = false
            }},
            timestamp = DateTime.now():ToIsoDate()
        }}
    })
    local success, result = pcall(function()
        return request({
            Url = webhookGear,
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

local function stocksAreDifferent(newGears)
    local isDifferent = false
    for _, gear in ipairs(newGears) do
        local previousStock = previousStocks[gear.name] or -1
        if gear.stock ~= previousStock then
            isDifferent = true
        end
        previousStocks[gear.name] = gear.stock
    end
    return isDifferent
end

local function checkAndSendGear()
    local gears = {}
    local attempts = 0
    local hasChanges = false

    while attempts < maxRetryAttempts do
        gears = extractGears()
        if stocksAreDifferent(gears) then
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
    for _, gear in ipairs(gears) do
        table.insert(lines, gear.displayName .. " **x" .. gear.stock .. "**")
    end

    if #lines > 0 and sendEmbed(lines) then
        lastSentMinute = os.date("*t").min
        print("Webhook terkirim: " .. os.time())
    end
end

local function monitorGear()
    timerGear:GetPropertyChangedSignal("Text"):Connect(function()
        local nowText = timerGear.Text
        if nowText == "00:00:00" or nowText == "Restocking..." or string.match(nowText, "^00:0[0-2]:") or string.match(nowText, "^04:5[0-9]:") or string.match(nowText, "^05:0[0-9]:") then
            task.spawn(checkAndSendGear)
        end
    end)
    while true do
        task.spawn(checkAndSendGear)
        task.wait()
    end
end

task.spawn(monitorGear)

