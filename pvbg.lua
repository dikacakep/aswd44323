-- Full Code for Gears Script (Improved Version for Consistency)
local HttpService = game:GetService("HttpService")
local player = game:GetService("Players").LocalPlayer
local gearShop = player.PlayerGui:WaitForChild("Main", 10)
local gears = gearShop:WaitForChild("Gears", 10)
local frame = gears:WaitForChild("Frame", 10)
local gearFrame = frame:WaitForChild("ScrollingFrame", 10)
local timerGear = gears:WaitForChild("Restock", 10)
local webhookGear = "https://discord.com/api/webhooks/1380214167889379378/vzIRr2W4_ug9Zs1Lj89a81XayIj3FwLzJko0OSBZInmfT3ymjp__poAQomL5DaZdCiti"

if not gearFrame or not timerGear then
    warn("Gagal menemukan gearFrame atau timerGear. Periksa struktur UI!")
    return
end

local gearNames = {
    "Water Bucket", "Frost Grenade", "Banana Gun", "Frost Blower", "Carrot Launcher"
}

local emojiMap = {
    ["Water Bucket"] = "🪣", ["Frost Grenade"] = "❄️💣", ["Banana Gun"] = "🍌🔫",
    ["Frost Blower"] = "❄️🌬️", ["Carrot Launcher"] = "🥕🚀"
}

local lastSentMinute = -1
local gearFrames = {}
local previousStocks = {}
local maxRetryAttempts = 5
local retryDelay = 1  -- Added small delay for retries

-- Inisialisasi cache frame with fallback
for _, gearName in ipairs(gearNames) do
    local gearPath = gearFrame:FindFirstChild(gearName)
    if not gearPath then
        for _, child in ipairs(gearFrame:GetChildren()) do
            if string.find(string.lower(child.Name), string.lower(gearName)) then
                gearPath = child
                break
            end
        end
    end
    if gearPath and gearPath:IsA("Frame") then
        local stockLabel = gearPath:FindFirstChild("Stock")
        if not stockLabel then
            local mainFrame = gearPath:FindFirstChild("Main_Frame")
            stockLabel = mainFrame and (mainFrame:FindFirstChild("Stock") or mainFrame:FindFirstChild("Stock_Text"))
        end
        if stockLabel and stockLabel:IsA("TextLabel") then
            gearFrames[gearName] = stockLabel
            previousStocks[gearName] = -1
        else
            warn("Stock label not found for: " .. gearName)
        end
    end
end

local function getStock(stockLabel)
    local text = stockLabel.Text:lower()
    local stockText = text:match("x(%d+)") or text:match("x%s*(%d+)") or text:match("%d+")
    return stockText and tonumber(stockText) or nil
end

local function extractGears()
    local result = {}
    local seen = {}
    for gearName, stockLabel in pairs(gearFrames) do
        local stock = getStock(stockLabel)
        local emoji = emojiMap[gearName] or ""
        if stock and stock > 0 and not seen[gearName] then
            seen[gearName] = true
            table.insert(result, {
                key = "Gear_" .. gearName,
                name = gearName,
                displayName = emoji ~= "" and (emoji .. " " .. gearName) or gearName,
                stock = stock
            })
        end
    end
    return result
end

local function sendEmbed(lines)
    if #lines == 0 then return false end
    local payload = HttpService:JSONEncode({
        embeds = {{
            title = "🛠️ DIKAGAMTENG • Gear Stocks",
            color = 0x57F287,
            fields = {{
                name = "Gear Stock Update",
                value = table.concat(lines, "\n"),
                inline = false
            }},
            timestamp = DateTime.now():ToIsoDate()
        }}
    })
    local success, result = pcall(function()
        return HttpService:PostAsync(webhookGear, payload, Enum.HttpContentType.ApplicationJson)
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
        if gear.stock and gear.stock ~= previousStock then
            isDifferent = true
        end
        previousStocks[gear.name] = gear.stock
    end
    return isDifferent
end

local function checkAndSendGears()
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

local function monitorGears()
    timerGear:GetPropertyChangedSignal("Text"):Connect(function()
        local nowText = timerGear.Text
        if nowText == "00:00:00" or nowText == "Restocking..." or string.match(nowText, "^00:0[0-2]:") or string.match(nowText, "^04:5[0-9]:") or string.match(nowText, "^05:0[0-9]:") or string.find(nowText:lower(), "restock") then
            task.spawn(checkAndSendGears)
        end
    end)
    while true do
        task.spawn(checkAndSendGears)
        task.wait(1)  -- Changed to 1s interval for less spam
    end
end

task.spawn(monitorGears)
