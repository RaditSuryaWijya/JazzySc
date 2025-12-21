-- [[ FISH NOTIFIER V12: PLUS FEATURES ]]
-- Fitur: Kode Asli V12 + Anti-AFK + Sell All + Test Button.

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local VirtualUser = game:GetService("VirtualUser") -- Ditambahkan untuk Anti-AFK

-- ====================================================
-- 1. KONFIGURASI GLOBAL (DITAMBAH OPSI BARU)
-- ====================================================
getgenv().FishConfig = {
    Active = false,
    WebhookUrl = "", 
    AntiAFK = false, -- Baru
    AutoSell = false, -- Baru
    -- Filter Multi-Select (Default: Rare ke atas Nyala)
    RarityFilter = {
        [1] = false, -- Common
        [2] = false, -- Uncommon
        [3] = true,  -- Rare
        [4] = true,  -- Epic
        [5] = true,  -- Legendary
        [6] = true,  -- Mythic
        [7] = true   -- SECRET
    }
}

local DEFAULT_WEBHOOK = "https://discord.com/api/webhooks/1451390752054841376/FT_84n6GyaPJQ06T_7Nv8T8E1rEWcgGwIgycywysRUsA4Az7bKbhPuBZs5zKqXo2KJVJ"
local RarityList = {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "SECRET"}

-- ====================================================
-- 2. SETUP GUI (RAYFIELD)
-- ====================================================
local Window = Rayfield:CreateWindow({
   Name = "Fish Tracker V12+ 🎣",
   LoadingTitle = "FishTrackerV12Plus",
   LoadingSubtitle = "by Jazzy",
   ConfigurationSaving = {
      Enabled = true,
      FolderName = "FishTrackerV12Plus",
      FileName = "Config"
   },
   Discord = { Enabled = false },
   KeySystem = false,
})

local MainTab = Window:CreateTab("Dashboard", 4483345998)
local UtilTab = Window:CreateTab("Utilities", 4483345998) -- Tab Baru

-- [SECTION 1: WEBHOOK & MASTER SWITCH]
MainTab:CreateParagraph({Title = "Status", Content = "Masukkan Webhook & Centang Rarity yang diinginkan."})

MainTab:CreateInput({
   Name = "Webhook URL",
   PlaceholderText = "Paste Webhook Disini...",
   RemoveTextAfterFocusLost = false,
   Callback = function(Text)
      getgenv().FishConfig.WebhookUrl = Text
   end,
})

-- Set Default jika kosong
if getgenv().FishConfig.WebhookUrl == "" then
    getgenv().FishConfig.WebhookUrl = DEFAULT_WEBHOOK
end

MainTab:CreateToggle({
   Name = "🔥 Master Switch (ON/OFF)",
   CurrentValue = false,
   Flag = "MasterSwitch", 
   Callback = function(Value)
      getgenv().FishConfig.Active = Value
   end,
})

-- [FITUR BARU: TEST BUTTON]
MainTab:CreateButton({
   Name = "🧪 Test Webhook (Klik Ini)",
   Callback = function() 
      if getgenv().TestWebhook then getgenv().TestWebhook() end 
   end,
})

-- [SECTION 2: MULTI-SELECT RARITY]
MainTab:CreateSection("Pilih Rarity (Bisa Banyak)")

-- Loop membuat tombol untuk setiap Rarity
for i, rarityName in ipairs(RarityList) do
    MainTab:CreateToggle({
       Name = "Kirim " .. rarityName,
       CurrentValue = getgenv().FishConfig.RarityFilter[i], -- Mengambil status default
       Flag = "Filter_" .. rarityName, 
       Callback = function(Value)
          getgenv().FishConfig.RarityFilter[i] = Value
       end,
    })
end

-- ====================================================
-- [TAB UTILITIES: FITUR TAMBAHAN]
-- ====================================================

-- [FITUR BARU: SELL ALL]
UtilTab:CreateSection("Selling System")

UtilTab:CreateButton({
   Name = "💰 Jual Semua Ikan (Sell All)",
   Callback = function()
      if getgenv().SellAllFish then getgenv().SellAllFish() end
   end,
})

UtilTab:CreateToggle({
   Name = "Auto-Sell (Jual otomatis saat dapat ikan)",
   CurrentValue = false,
   Flag = "AutoSell",
   Callback = function(Value)
      getgenv().FishConfig.AutoSell = Value
   end,
})

-- [FITUR BARU: ANTI-AFK]
UtilTab:CreateSection("AFK System")

UtilTab:CreateToggle({
   Name = "🔄 Anti-AFK (Biar gak dikick)",
   CurrentValue = false,
   Flag = "AntiAFK",
   Callback = function(Value)
       getgenv().FishConfig.AntiAFK = Value
       if Value then
           Rayfield:Notify({Title="Anti-AFK", Content="Aktif!", Duration=3})
       end
   end,
})

-- ====================================================
-- 3. LOGIKA SISTEM (BACKEND)
-- ====================================================
local httpRequest = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
if not httpRequest then 
    Rayfield:Notify({Title = "Error", Content = "Executor tidak support HTTP!", Duration = 5})
    return 
end

-- Helper: Remote Finder (Diupdate sedikit agar bisa cari RF/SellAllItems)
local function getRemote(name)
    local index = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("_Index", 5)
    if not index then return nil end
    for _, child in pairs(index:GetChildren()) do
        if string.find(child.Name, "sleitnick_net") then
            local net = child:FindFirstChild("net")
            -- Cari Remote (Bisa RF atau RE)
            local found = net:FindFirstChild(name) or net:FindFirstChild(string.gsub(name, "/", "."))
            if found then return found end
        end
    end
    return nil
end

-- Helper: Get Real Image
local function getRealImageUrl(assetId)
    if not assetId then return "https://i.imgur.com/HuM55gA.png" end
    local apiUrl = "https://thumbnails.roblox.com/v1/assets?assetIds="..assetId.."&size=420x420&format=Png&isCircular=false"
    local response = httpRequest({Url = apiUrl, Method = "GET"})
    if response and response.Body then
        local data = HttpService:JSONDecode(response.Body)
        if data and data.data and data.data[1] then return data.data[1].imageUrl end
    end
    return "https://i.imgur.com/HuM55gA.png"
end

-- Database Builder
local FishDatabase = {} 
local ItemsFolder = ReplicatedStorage:WaitForChild("Items")
local TierColors = {[1]=16777215, [2]=65280, [3]=255, [4]=10181046, [5]=16766720, [6]=16711680, [7]=65450}

for _, module in pairs(ItemsFolder:GetChildren()) do
    if module:IsA("ModuleScript") then
        local s, r = pcall(function() return require(module) end)
        if s and r.Data and r.Data.Id then
            local d = r.Data
            FishDatabase[d.Id] = {Name=d.Name, Tier=d.Tier, Icon=d.Icon}
        end
    end
end

-- [FUNGSI ASLI V12 - TIDAK DIUBAH SAMA SEKALI]
local function sendWebhook(fishData, dynamicStats)
    if not getgenv().FishConfig.Active then return end
    local url = getgenv().FishConfig.WebhookUrl
    if url == "" then url = DEFAULT_WEBHOOK end

    local iconID = string.match(tostring(fishData.Icon), "%d+")
    local realImageUrl = getRealImageUrl(iconID)
    local playerName = LocalPlayer.DisplayName
    local playerProfileLink = "https://www.roblox.com/users/" .. LocalPlayer.UserId .. "/profile"

    local embedFields = {{["name"]="💎 Rarity", ["value"]=RarityList[fishData.Tier] or "Unknown", ["inline"]=true}}

    if dynamicStats and type(dynamicStats) == "table" then
        for k, v in pairs(dynamicStats) do
            if k ~= "VariantSeed" then
                local t, val, icon = k, tostring(v), "🔹"
                if k == "VariantId" then t, icon = "Mutation", "🧬" end
                if k == "Weight" then t, val, icon = "Weight", val.." kg", "⚖️" end
                if string.find(k, "Shiny") then icon = "✨" end
                if string.find(k, "Big") then icon = "🐳" end
                table.insert(embedFields, {["name"]=icon.." "..t, ["value"]="**"..val.."**", ["inline"]=true})
            end
        end
    end

    local payload = {
        ["username"] = "Fish Tracker V12",
        ["avatar_url"] = "https://i.imgur.com/4M7IwwP.png",
        ["embeds"] = {{
            ["title"] = "🎣 Ikan Baru Ditangkap!",
            ["description"] = "**" .. fishData.Name .. "** Sudah Di Tas.",
            ["color"] = TierColors[fishData.Tier] or 16777215,
            ["author"] = {["name"] = "Player: " .. playerName, ["url"] = playerProfileLink},
            ["fields"] = embedFields,
            ["thumbnail"] = {["url"] = realImageUrl},
            ["footer"] = {["text"] = "Rayfield V12 | " .. os.date("%X")}
        }}
    }

    httpRequest({
        Url = url,
        Method = "POST",
        Headers = {["Content-Type"]="application/json"},
        Body = HttpService:JSONEncode(payload)
    })
end

-- ====================================================
-- 4. FUNGSI TAMBAHAN (DI LUAR WEBHOOK)
-- ====================================================

-- [Fungsi Sell All]
getgenv().SellAllFish = function()
    local sellRemote = getRemote("RF/SellAllItems")
    if sellRemote then
        sellRemote:InvokeServer()
        Rayfield:Notify({Title = "💰 Sold!", Content = "Semua ikan berhasil dijual.", Duration = 3})
    else
        Rayfield:Notify({Title = "Error", Content = "Remote SellAllItems tidak ketemu!", Duration = 5})
    end
end

-- [Fungsi Test Webhook]
getgenv().TestWebhook = function()
    local testData = {Name="Test Fish V12", Tier=4, Icon="rbxassetid://0"}
    local testStats = {Weight=99.9, VariantId="Dark"} -- Simulasi data V12
    Rayfield:Notify({Title="Testing...", Content="Mengirim data test...", Duration=3})
    sendWebhook(testData, testStats)
end

-- [Fungsi Anti-AFK]
local function setupAntiAFK()
    LocalPlayer.Idled:Connect(function()
        if getgenv().FishConfig.AntiAFK then
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end
    end)
    spawn(function()
        while wait(60) do 
            if getgenv().FishConfig.AntiAFK then
                pcall(function() VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new()) end)
            end
        end
    end)
end
setupAntiAFK()


-- Listener (Ditambah logika Auto-Sell)
local remote = getRemote("RE/ObtainedNewFishNotification")

if remote then
    Rayfield:Notify({Title = "Tracker Siap", Content = "Menu V12 Aktif (Multi-Select)", Duration = 5})
    
    remote.OnClientEvent:Connect(function(...)
        local args = {...}
        local arg1, arg2 = args[1], args[2]
        
        if type(arg1) == "number" then
            local info = FishDatabase[arg1]
            if info then
                -- 1. KIRIM WEBHOOK (V12 Logic)
                if getgenv().FishConfig.Active and getgenv().FishConfig.RarityFilter[info.Tier] == true then
                    local stats = (type(arg2) == "table" and arg2) or {}
                    sendWebhook(info, stats)
                end
                
                -- 2. AUTO-SELL (Fitur Tambahan)
                if getgenv().FishConfig.AutoSell then
                    getgenv().SellAllFish()
                end
            end
        end
    end)
end
