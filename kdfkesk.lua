local HttpService = game:GetService("HttpService")
local player = game:GetService("Players").LocalPlayer

-- UI Reference
local harvestFrame = player.PlayerGui:WaitForChild("EventShop_UI"):WaitForChild("Frame"):WaitForChild("ScrollingFrame")
local timerHarvest = player.PlayerGui:WaitForChild("EventShop_UI"):WaitForChild("Frame"):WaitForChild("Frame"):WaitForChild("Timer")

-- Webhook URL
local webhookHarvest = "https://discord.com/api/webhooks/1380214440552693882/EUjRCcGdCm-GslZzoQCBELcoqb6ZVOhY3SJRw8m5a63Ie_Pd0cVlI7wKk6movSkiaexj"

-- Emoji map for harvest items
local emojiMap = {
    ["Zen Seed Pack"] = "🌱", 
    ["Zen Egg"] = "🥚", 
    ["Hot Spring"] = "♨️", 
    ["Zen Sand"] = "🏜️", 
    ["Zen Flare"] = "✨", 
    ["Zen Crate"] = "📦", 
    ["Soft Sunshine"] = "☀️", 
    ["Koi"] = "🐟", 
    ["Sakura Bush"] = "🐟",
    ["Corrupt Radar"] = "🐟",
    ["Pet Shard Corrupted"] = "🐟",
    ["Raiju"] = "🐟",
    ["Zen Gnome Crate"] = "🧙‍♂️", 
    ["Spiked Mango"] = "🥭", 
    ["Tranquil Radar"] = "💎",
    ["Pet Shard Tranquil"] = "💎"
}

-- Last sent time and previous stock
local lastSentTime = -1
local harvestFrames = {}
local previousStocks = {}
local maxRetryAttempts = 20
local isFirstRun = true

-- Initialize frame cache with retries
for harvestName, _ in pairs(emojiMap) do
    local attempts = 3
    local item = nil
    for i = 1, attempts do
        item = harvestFrame:FindFirstChild(harvestName)
        if item and item:IsA("Frame") then break end
        task.wait(0.5)
    end
    if item and item:IsA("Frame") then
        local main = item:FindFirstChild("Main_Frame")
        local stockLabel = main and main:FindFirstChild("Stock_Text")
        if stockLabel and stockLabel:IsA("TextLabel") then
            harvestFrames[harvestName] = stockLabel
            previousStocks[harvestName] = -1
        else
            warn("Failed to find stock label for " .. harvestName)
        end
    else
        warn("Failed to find frame for " .. harvestName)
    end
end

-- Function to get stock
local function getStock(stockLabel)
    local attempts = 3
    local stock = nil
    for i = 1, attempts do
        local stockText = stockLabel.Text:match("X(%d+)")
        stock = stockText and tonumber(stockText) or nil
        if stock then break end
        task.wait()
    end
    return stock
end

local function extractHarvest()
    local result = {}
    local seen = {}
    for harvestName, stockLabel in pairs(harvestFrames) do
        local stock = getStock(stockLabel)
        local emoji = emojiMap[harvestName] or ""
        if stock and stock > 0 and not seen[harvestName] then
            seen[harvestName] = true
            table.insert(result, {
                key = "Harvest_" .. harvestName,
                name = harvestName,
                displayName = emoji ~= "" and (emoji .. " " .. harvestName) or harvestName,
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
            title = "🌾 DIKAGAMTENG • Harvest Stocks",
            color = 0x57F287,
            fields = {{
                name = "Harvest Stock Update",
                value = table.concat(lines, "\n"),
                inline = false
            }},
            timestamp = DateTime.now():ToIsoDate()
        }}
    })
    local success, result = pcall(function()
        return request({
            Url = webhookHarvest,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = payload
        })
    end)
    if not success then
        warn("Webhook failed: " .. tostring(result))
    else
        print("Webhook sent successfully")
    end
    return success
end

local function isRestockHourly()
    local t = os.date("*t")
    return t.min == 0 and t.sec <= 10, t.min
end

local function stocksAreDifferent(newItems)
    local isDifferent = false
    for _, item in ipairs(newItems) do
        local previousStock = previousStocks[item.name] or -1
        if item.stock ~= previousStock then
            isDifferent = true
        end
        previousStocks[item.name] = item.stock
    end
    return isDifferent
end

local function checkAndSendHarvest()
    local isRestock, currentTime = isRestockHourly()
    if not isFirstRun and (not isRestock or currentTime == lastSentTime) then
        return
    end

    local attempts = 0
    local harvestItems = {}
    local hasChanges = false

    while attempts < maxRetryAttempts do
        harvestItems = extractHarvest()
        if stocksAreDifferent(harvestItems) then
            hasChanges = true
            break
        end
        attempts = attempts + 1
        print("Attempt " .. attempts .. ": No stock changes detected")
    end

    if not hasChanges then
        print("No stock changes detected after " .. attempts .. " attempts")
        return
    end

    local lines = {}
    for _, item in ipairs(harvestItems) do
        print("Detected: " .. item.displayName .. " x" .. item.stock)
        table.insert(lines, item.displayName .. " **x" .. item.stock .. "**")
    end

    if #lines > 0 and sendEmbed(lines) then
        lastSentTime = currentTime
        isFirstRun = false
        print("Harvest webhook sent at time " .. currentTime)
    else
        print("No items to send or webhook failed")
    end
end

local function monitorHarvest()
    timerHarvest:GetPropertyChangedSignal("Text"):Connect(function()
        local nowText = timerHarvest.Text
        if nowText == "00:00:00" or nowText == "Restocking..." or string.match(nowText, "^00:00:0[0-5]") then
            print("Timer triggered: " .. nowText)
            task.spawn(checkAndSendHarvest)
        end
    end)
    while true do
        task.spawn(checkAndSendHarvest)
        task.wait()
    end
end

-- Start monitoring harvest
task.spawn(monitorHarvest)
