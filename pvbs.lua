-- Full Code for Seeds Script (Improved for Consistency, Keeping Original Webhook)
local HttpService = game:GetService("HttpService")
local player = game:GetService("Players").LocalPlayer
local seedShop = player.PlayerGui:WaitForChild("Main", 10)
local seeds = seedShop:WaitForChild("Seeds", 10)
local frame = seeds:WaitForChild("Frame", 10)
local seedFrame = frame:WaitForChild("ScrollingFrame", 10)
local timerSeed = seeds:WaitForChild("Restock", 10)
local webhookSeed = "https://discord.com/api/webhooks/1380214167889379378/vzIRr2W4_ug9Zs1Lj89a81XayIj3FwLzJko0OSBZInmfT3ymjp__poAQomL5DaZdCiti"

if not seedFrame or not timerSeed then
    warn("Gagal menemukan seedFrame atau timerSeed. Periksa struktur UI!")
    return
end

local seedNames = {
    "Cactus Seed", "Strawberry Seed", "Pumpkin Seed", "Sunflower Seed", "Dragon Fruit Seed",
    "Eggplant Seed", "Watermelon Seed", "Cocotank Seed", "Carnivorous Plant Seed",
    "Mr Carrot Seed", "Tomatrio Seed"
}

local emojiMap = {
    ["Cactus Seed"] = "🌵", ["Strawberry Seed"] = "🍓", ["Pumpkin Seed"] = "🎃",
    ["Sunflower Seed"] = "🌻", ["Dragon Fruit Seed"] = "🌴", ["Eggplant Seed"] = "🍆",
    ["Watermelon Seed"] = "🍉", ["Cocotank Seed"] = "🥥", ["Carnivorous Plant Seed"] = "🌱",
    ["Mr Carrot Seed"] = "🥕", ["Tomatrio Seed"] = "🍅"
}

local lastSentMinute = -1
local seedFrames = {}
local previousStocks = {}
local maxRetryAttempts = 5
local retryDelay = 1

-- Initialize cache with fallback
for _, seedName in ipairs(seedNames) do
    local seedPath = seedFrame:FindFirstChild(seedName)
    if not seedPath then
        for _, child in ipairs(seedFrame:GetChildren()) do
            if string.find(string.lower(child.Name), string.lower(seedName)) then
                seedPath = child
                break
            end
        end
    end
    if seedPath and seedPath:IsA("Frame") then
        local stockLabel = seedPath:FindFirstChild("Stock")
        if not stockLabel then
            local mainFrame = seedPath:FindFirstChild("Main_Frame")
            stockLabel = mainFrame and (mainFrame:FindFirstChild("Stock") or mainFrame:FindFirstChild("Stock_Text"))
        end
        if stockLabel and stockLabel:IsA("TextLabel") then
            seedFrames[seedName] = stockLabel
            previousStocks[seedName] = -1
            print("Cached: " .. seedName)  -- Debug
        else
            warn("Stock label not found for: " .. seedName)
        end
    end
end

local function getStock(stockLabel)
    local text = stockLabel.Text:lower()
    local stockText = text:match("x(%d+)") or text:match("x%s*(%d+)") or text:match("%d+")
    return stockText and tonumber(stockText) or nil
end

local function extractSeeds()
    local result = {}
    local seen = {}
    for seedName, stockLabel in pairs(seedFrames) do
        local stock = getStock(stockLabel)
        local emoji = emojiMap[seedName] or ""
        if stock and stock > 0 and not seen[seedName] then
            seen[seedName] = true
            table.insert(result, {
                key = "Seed_" .. seedName,
                name = seedName,
                displayName = emoji ~= "" and (emoji .. " " .. seedName) or seedName,
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
            title = "🌱 DIKAGAMTENG • Seed Stocks",
            color = 0x57F287,
            fields = {{
                name = "Seed Stock Update",
                value = table.concat(lines, "\n"),
                inline = false
            }},
            timestamp = DateTime.now():ToIsoDate()
        }}
    })
    local success, result = pcall(function()
        return request({
            Url = webhookSeed,
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

local function stocksAreDifferent(newSeeds)
    local isDifferent = false
    for _, seed in ipairs(newSeeds) do
        local previousStock = previousStocks[seed.name] or -1
        if seed.stock and seed.stock ~= previousStock then
            isDifferent = true
        end
        previousStocks[seed.name] = seed.stock or -1
    end
    return isDifferent
end

local function checkAndSendSeeds()
    local seeds = {}
    local attempts = 0
    local hasChanges = false

    while attempts < maxRetryAttempts do
        seeds = extractSeeds()
        if stocksAreDifferent(seeds) then
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
    for _, seed in ipairs(seeds) do
        table.insert(lines, seed.displayName .. " **x" .. seed.stock .. "**")
    end

    if #lines > 0 and sendEmbed(lines) then
        lastSentMinute = os.date("*t").min
        print("Webhook terkirim: " .. os.time())
    end
end

local function monitorSeeds()
    timerSeed:GetPropertyChangedSignal("Text"):Connect(function()
        local nowText = timerSeed.Text
        if nowText == "00:00:00" or nowText == "Restocking..." or string.match(nowText, "^00:0[0-2]:") or 
           string.match(nowText, "^04:5[0-9]:") or string.match(nowText, "^05:0[0-9]:") or 
           string.find(nowText:lower(), "restock") then
            task.spawn(checkAndSendSeeds)
        end
    end)
    while true do
        task.spawn(checkAndSendSeeds)
        task.wait(1)  -- Reduced spam with 1s interval
    end
end

task.spawn(monitorSeeds)
