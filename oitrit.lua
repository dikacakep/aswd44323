local HttpService = game:GetService("HttpService")
local player = game:GetService("Players").LocalPlayer
local seedShop = player.PlayerGui:WaitForChild("Seed_Shop", 5)
local frame = seedShop:WaitForChild("Frame", 5)
local seedFrame = frame:WaitForChild("ScrollingFrame", 5)
local timerSeed = player.PlayerGui.Seed_Shop.Frame.Frame:WaitForChild("Timer", 5)
local webhookSeed = "https://discord.com/api/webhooks/1380214167889379378/vzIRr2W4_ug9Zs1Lj89a81XayIj3FwLzJko0OSBZInmfT3ymjp__poAQomL5DaZdCiti"

if not seedFrame or not timerSeed then
    warn("Gagal menemukan seedFrame atau timerSeed. Periksa struktur UI!")
    return
end

local emojiMap = {
    ["Carrot"] = "🥕", ["Giant Pinecone"] = "🥕", ["Burning Bud"] = "🥕", ["Strawberry"] = "🍓", ["Blueberry"] = "🫐", ["Rafflesia"] = "🌷", ["Orange Tulip"] = "🌷", ["Tomato"] = "🍅", ["Prickly Pear"] = "🍎", ["Pineapple"] = "🍎", ["Green Apple"] = "🍎",
    ["Corn"] = "🌽", ["Daffodil"] = "🌼", ["Watermelon"] = "🍉", ["Pumpkin"] = "🎃", ["Apple"] = "🍎", ["Feijoa"] = "🍎", ["Bell Pepper"] = "🍎", ["Avocado"] = "🍎",
    ["Bamboo"] = "🍋", ["Pitcher Plant"] = "🍋", ["Coconut"] = "🥥", ["Cactus"] = "🌵", ["Dragon Fruit"] = "🌴", ["Mango"] = "🥭", ["Loquat"] = "🍎", ["Kiwi"] = "🍎", ["Banana"] = "🍎", ["Cauliflower"] = "🍎",
    ["Grape"] = "🍇", ["Mushroom"] = "🍄", ["Pepper"] = "🌶", ["Ember Lily"] = "🪻", ["Cacao"] = "🌰", ["Sugar Apple"] = "🧁", ["Beanstalk"] = "🪻"
}

local lastSentMinute = -1
local seedFrames = {}
local previousStocks = {}
local maxRetryAttempts = 5
local retryDelay = 0

-- Inisialisasi cache frame
for seedName, _ in pairs(emojiMap) do
    local seedPath = seedFrame:FindFirstChild(seedName)
    if seedPath and seedPath:IsA("Frame") then
        local mainFrame = seedPath:FindFirstChild("Main_Frame")
        local stockLabel = mainFrame and mainFrame:FindFirstChild("Stock_Text")
        if stockLabel and stockLabel:IsA("TextLabel") then
            seedFrames[seedName] = stockLabel
            previousStocks[seedName] = -1
        end
    end
end

local function getStock(stockLabel)
    local stockText = stockLabel.Text:match("X(%d+)")
    return stockText and tonumber(stockText) or nil
end

local function extractSeeds()
    local result = {}
    local seen = {}
    local threads = {}

    for seedName, stockLabel in pairs(seedFrames) do
        table.insert(threads, coroutine.create(function()
            local stock = getStock(stockLabel)
            local emoji = emojiMap[seedName]
            if stock and stock > 0 and not seen[seedName] then
                seen[seedName] = true
                table.insert(result, {
                    key = "Seed_" .. seedName,
                    name = seedName,
                    displayName = emoji ~= "" and (emoji .. " " .. seedName) or seedName,
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
        if seed.stock ~= previousStock then
            isDifferent = true
        end
        previousStocks[seed.name] = seed.stock
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
        if nowText == "00:00:00" or nowText == "Restocking..." or string.match(nowText, "^00:0[0-2]:") or string.match(nowText, "^04:5[0-9]:") or string.match(nowText, "^05:0[0-9]:") then
            task.spawn(checkAndSendSeeds)
        end
    end)
    while true do
        task.spawn(checkAndSendSeeds)
        task.wait()
    end
end

task.spawn(monitorSeeds)
