-- Layanan Roblox yang diperlukan
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- URL webhook Discord
local webhookCosmetic = "https://discord.com/api/webhooks/1385165786833748038/-qhLaE_r_BzdBd3wn5ccXTWrGVpW2RoQdZJicBuvqR0JUaGW-0FeuGnYc6-T7n1BW2Pi"

-- Inisialisasi UI dengan timeout
local cosmeticShop = player.PlayerGui:WaitForChild("CosmeticShop_UI", 20)
if not cosmeticShop then
    warn("Gagal menemukan CosmeticShop_UI!")
    return
end

local cosmeticMain = cosmeticShop:WaitForChild("CosmeticShop", 10)
if not cosmeticMain then
    warn("Gagal menemukan CosmeticShop!")
    return
end

local main = cosmeticMain:WaitForChild("Main", 10)
if not main then
    warn("Gagal menemukan Main!")
    return
end

-- Debug: Cetak struktur UI untuk memeriksa anak-anak dari Main
print("Struktur UI dari Main:")
local function printHierarchy(obj, indent)
    indent = indent or ""
    print(indent .. obj.Name .. " (" .. obj.ClassName .. ")")
    for _, child in ipairs(obj:GetChildren()) do
        printHierarchy(child, indent .. "  ")
    end
end
printHierarchy(main)

local holder = main:WaitForChild("Holder", 10)
if not holder then
    warn("Gagal menemukan Holder!")
    return
end

local header = holder:WaitForChild("Header", 10)
if not header then
    warn("Gagal menemukan Header!")
    return
end

local shop = holder:WaitForChild("Shop", 10)
if not shop then
    warn("Gagal menemukan Shop!")
    return
end

local contentFrame = shop:WaitForChild("ContentFrame", 10)
if not contentFrame then
    warn("Gagal menemukan ContentFrame!")
    return
end

local bottomSegment = contentFrame:WaitForChild("BottomSegment", 10)
local topSegment = contentFrame:WaitForChild("TopSegment", 10)
local timer = header:WaitForChild("TimerLabel", 10)
if not bottomSegment or not topSegment or not timer then
    warn("Gagal menemukan BottomSegment, TopSegment, atau TimerLabel!")
    return
end

-- Peta emoji untuk item
local emojiMap = {
    ["Brick Stack"] = "🧱", ["Compost Bin"] = "🧺", ["Stone Lantern"] = "🪵", ["Beach Crate"] = "🪵",
    ["Market Cart"] = "🪵", ["Log"] = "🪵", ["Wood Pile"] = "🪵", ["Torch"] = "🔥",
    ["Small Circle Tile"] = "🔘", ["Medium Circle Tile"] = "⚪", ["Small Path Tile"] = "🛣️",
    ["Medium Path Tile"] = "🛤️", ["Large Path Tile"] = "🛞", ["Rock Pile"] = "🪨",
    ["Red Pottery"] = "🏺", ["White Pottery"] = "🏺", ["Rake"] = "🧹", ["Orange Umbrella"] = "☂️",
    ["Yellow Umbrella"] = "🌂", ["Log Bench"] = "🪵", ["Brown Bench"] = "🪑",
    ["Pink Cooler Chest"] = "🪵", ["White Bench"] = "🪑", ["Hay Bale"] = "🌾",
    ["Small Stone Pad"] = "🪨", ["Large Stone Pad"] = "🪨", ["Blue Cooler Chest"] = "🪵",
    ["Small Stone Table"] = "🪨", ["Medium Stone Table"] = "🪨", ["Long Stone Table"] = "🪨",
    ["Wood Fence"] = "🪵", ["Small Wood Flooring"] = "🪵", ["Medium Wood Flooring"] = "🪵",
    ["Large Wood Flooring"] = "🪵", ["Mini TV"] = "📺", ["Viney Beam"] = "🌿",
    ["Light On Ground"] = "💡", ["Water Trough"] = "🪣", ["Shovel Grave"] = "⚰️",
    ["Small Stone Lantern"] = "🏮", ["Bookshelf"] = "📚", ["Axe Stump"] = "🪓",
    ["Brown Stone Pillar"] = "🗿", ["Grey Stone Pillar"] = "🗿", ["Dark Stone Pillar"] = "🗿",
    ["Small Wood Table"] = "🪵", ["Large Wood Table"] = "🪵", ["Curved Canopy"] = "⛺",
    ["Flat Canopy"] = "⛺", ["Campfire"] = "🔥", ["Cooking Pot"] = "🍲", ["Clothesline"] = "👕",
    ["Small Wood Arbour"] = "🌳", ["Square Metal Arbour"] = "🌳", ["Bird Bath"] = "🐦",
    ["Lamp Post"] = "💡", ["Metal Wind Chime"] = "🎐", ["Bamboo Wind Chimes"] = "🎍",
    ["Brown Well"] = "⛲", ["Red Well"] = "⛲", ["Blue Well"] = "⛲", ["Ring Walkway"] = "⭕",
    ["Viney Ring Walkway"] = "🟢", ["Red Tractor"] = "🚜", ["Green Tractor"] = "🚜",
    ["Large Wood Arbour"] = "🌲", ["Round Metal Arbour"] = "🔩", ["Farmers Gnome Crate"] = "📦",
    ["Sign Crate"] = "📦", ["Common Gnome Crate"] = "📦", ["Classic Gnome Crate"] = "📦",
    ["Bloodmoon Crate"] = "📦", ["Twilight Crate"] = "📦", ["Mysterious Crate"] = "🎁",
    ["Frog Fountain"] = "🐸", ["Beta Gnome"] = "🧌", ["Green Female Gnome"] = "🧝‍♀️",
    ["Blue Gnome"] = "🧝", ["Wheelbarrow"] = "🛒", ["Fun Crate"] = "🎉",
    ["Monster Mash Trophy"] = "🏆"
}

-- Variabel global
local stockFrames = {}
local previousStocks = {}
local lastSentTime = 0
local lastHourlyCheck = 0
local minInterval = 60 -- Interval minimum antar webhook (kembali ke 60 detik)
local restockInterval = 4 * 3600 -- 4 jam dalam detik
local maxRetryAttempts = 3
local retryDelay = 1

-- Fungsi untuk mendapatkan kunci tabel
local function getTableKeys(tbl)
    local keys = {}
    for key, _ in pairs(tbl) do
        table.insert(keys, key)
    end
    return keys
end

-- Fungsi untuk mendapatkan stok dari label
local function getStock(stockLabel)
    local stockText
    for i = 1, 3 do
        stockText = stockLabel.Text:match("x(%d+)") or stockLabel.Text:match("X(%d+)") or stockLabel.Text:match("%d+")
        print("Stock text for", stockLabel.Parent.Parent.Parent.Name, ":", stockLabel.Text) -- Debug teks stok
        if stockText then break end
        task.wait(0.1)
    end
    return stockText and tonumber(stockText) or nil
end

-- Inisialisasi frame stok secara dinamis
local function initializeStockFrames()
    stockFrames = {} -- Reset stockFrames untuk memastikan pembaruan
    for _, segment in ipairs({bottomSegment, topSegment}) do
        for _, itemFrame in ipairs(segment:GetChildren()) do
            if itemFrame:IsA("Frame") then
                local mainFrame = itemFrame:FindFirstChild("Main")
                local stockLabel = mainFrame and mainFrame:FindFirstChild("Stock") and mainFrame.Stock:FindFirstChild("STOCK_TEXT")
                if stockLabel and stockLabel:IsA("TextLabel") then
                    stockFrames[itemFrame.Name] = stockLabel
                    if not previousStocks[itemFrame.Name] then
                        previousStocks[itemFrame.Name] = -1 -- Hanya set -1 jika belum ada
                    end
                    if not emojiMap[itemFrame.Name] then
                        emojiMap[itemFrame.Name] = "❓" -- Emoji default untuk item baru
                    end
                end
            end
        end
    end
    if not next(stockFrames) then
        warn("Tidak ada item yang ditemukan di BottomSegment atau TopSegment!")
    else
        print("Stock frames initialized:", table.concat(getTableKeys(stockFrames), ", "))
    end
end
initializeStockFrames()

-- Fungsi untuk mengekstrak item
local function extractItems()
    local result = {}
    local seen = {}
    local threads = {}

    for itemName, stockLabel in pairs(stockFrames) do
        table.insert(threads, coroutine.create(function()
            local stock = getStock(stockLabel)
            local emoji = emojiMap[itemName] or "❓"
            if stock and stock > 0 and not seen[itemName] then
                seen[itemName] = true
                table.insert(result, {
                    key = "Item_" .. itemName,
                    name = itemName,
                    displayName = emoji ~= "" and (emoji .. " " .. itemName) or itemName,
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

-- Fungsi untuk mengirim embed ke webhook (kembali ke kode asli)
local function sendEmbed(lines)
    if #lines == 0 then 
        print("No items to send in webhook.")
        return false 
    end
    local payload = HttpService:JSONEncode({
        embeds = {{
            title = "🛒 DIKAGAMTENG • Cosmetic Shop Stocks",
            color = 0xFFD700,
            fields = {{
                name = "Cosmetic Stock Update",
                value = table.concat(lines, "\n"),
                inline = false
            }},
            timestamp = DateTime.now():ToIsoDate()
        }}
    })

    local success, result
    for i = 1, maxRetryAttempts do
        success, result = pcall(function()
            if not request then
                error("request function is nil")
            end
            return request({
                Url = webhookCosmetic,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = payload
            })
        end)
        if success then break end
        warn("Webhook attempt " .. i .. " failed: " .. tostring(result))
        task.wait(retryDelay)
    end
    if not success then
        warn("Webhook failed after retries: " .. tostring(result))
    else
        print("Webhook successfully sent.")
    end
    return success
end

-- Fungsi untuk memeriksa apakah stok berbeda
local function stocksAreDifferent(newItems)
    local isDifferent = false
    for _, item in ipairs(newItems) do
        local previousStock = previousStocks[item.name] or -1
        if item.stock ~= previousStock then
            isDifferent = true
            print("Stock changed for", item.name, ": from", previousStock, "to", item.stock)
        end
        previousStocks[item.name] = item.stock
    end
    return isDifferent
end

-- Fungsi untuk memeriksa dan mengirim pembaruan stok
local function checkAndSendItems()
    initializeStockFrames() -- Perbarui frame stok setiap pemeriksaan
    local items = extractItems()
    print("Current Stocks:")
    for _, item in ipairs(items) do
        print(item.name .. ": " .. item.stock)
    end

    local forceSend = os.time() - lastHourlyCheck >= restockInterval
    local stockChanged = stocksAreDifferent(items)

    if not (forceSend or stockChanged) then
        print("No stock changes detected and not time for periodic check.")
        return
    end

    print("Sending webhook. Reason: ", forceSend and "4-hour interval" or "Stock change detected")

    local lines = {}
    for _, item in ipairs(items) do
        table.insert(lines, item.displayName .. " **x" .. item.stock .. "**")
    end

    if #lines > 0 and (os.time() - lastSentTime >= minInterval) then
        if sendEmbed(lines) then
            lastSentTime = os.time()
            lastHourlyCheck = forceSend and os.time() or lastHourlyCheck -- Hanya perbarui lastHourlyCheck jika forceSend
            print("Webhook sent at: " .. os.time())
        end
    else
        print("Webhook not sent: minInterval not reached or no items.")
    end
end

-- Fungsi untuk memantau item dan timer
local function monitorItems()
    local lastTimerTrigger = 0
    timer:GetPropertyChangedSignal("Text"):Connect(function()
        local nowText = timer.Text
        if os.time() - lastTimerTrigger < 5 then return end -- Hindari trigger berulang dalam 5 detik
        lastTimerTrigger = os.time()
        print("Timer Changed to:", nowText)
        if nowText == "00:00:00" or nowText == "Restocking..." or string.match(nowText, "^00:0[0-5]:") then
            print("Restock condition met, checking stocks...")
            task.spawn(checkAndSendItems)
        end
    end)

    -- Dengarkan RemoteEvent jika tersedia
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local restockEvent = ReplicatedStorage:FindFirstChild("RestockEvent")
    if restockEvent then
        restockEvent.OnClientEvent:Connect(function()
            print("Restock event received from server!")
            task.spawn(checkAndSendItems)
        end)
    end

    while true do
        local success, err = pcall(function()
            task.spawn(checkAndSendItems)
        end)
        if not success then
            warn("Error in monitorItems loop: ", err)
        end
        task.wait(0.5) -- Periksa setiap 0.5 detik
    end
end

-- Jalankan pemantauan
task.spawn(monitorItems)
