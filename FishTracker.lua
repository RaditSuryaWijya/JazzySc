-- [[ FISH NOTIFIER V12: MULTI-SELECT FILTER ]]
-- Fitur: Pilih banyak rarity secara spesifik menggunakan Toggle (Centang)

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local VirtualUser = game:GetService("VirtualUser")

-- ====================================================
-- 1. KONFIGURASI GLOBAL
-- ====================================================
getgenv().FishConfig = {
    Active = false,
    WebhookUrl = "", 
    AntiAFK = false,
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
   Name = "Fish Tracker V12 🎣",
   LoadingTitle = "Fish Tracker Multi-Select",
   LoadingSubtitle = "by Gemini",
   ConfigurationSaving = {
      Enabled = true,
      FolderName = "FishTrackerV12",
      FileName = "Config"
   },
   Discord = { Enabled = false },
   KeySystem = false,
})

local MainTab = Window:CreateTab("Dashboard", 4483345998)

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

-- Test Webhook Button
MainTab:CreateButton({
   Name = "🧪 Test Webhook",
   Callback = function()
      if getgenv().TestWebhook then
         getgenv().TestWebhook()
      else
         Rayfield:Notify({Title = "Loading...", Content = "Tunggu sebentar, fungsi sedang diinisialisasi.", Duration = 3})
      end
   end,
})

-- [SECTION 2: ANTI-AFK]
MainTab:CreateSection("Anti-AFK")
MainTab:CreateToggle({
   Name = "🔄 Anti-AFK (ON/OFF)",
   CurrentValue = false,
   Flag = "AntiAFK",
   Callback = function(Value)
      getgenv().FishConfig.AntiAFK = Value
   end,
})

-- [SECTION 3: MULTI-SELECT RARITY]
MainTab:CreateSection("Pilih Rarity (Bisa Banyak)")

-- Loop membuat tombol untuk setiap Rarity
for i, rarityName in ipairs(RarityList) do
    MainTab:CreateToggle({
       Name = "Kirim " .. rarityName,
       CurrentValue = getgenv().FishConfig.RarityFilter[i], -- Mengambil status default
       Flag = "Filter_" .. rarityName, 
       Callback = function(Value)
          getgenv().FishConfig.RarityFilter[i] = Value
          -- print("Filter update: " .. rarityName .. " = " .. tostring(Value))
       end,
    })
end

-- ====================================================
-- 3. LOGIKA SISTEM (BACKEND)
-- ====================================================
local httpRequest = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
if not httpRequest then 
    Rayfield:Notify({Title = "Error", Content = "Executor tidak support HTTP!", Duration = 5})
    return 
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
local TierColors = {[1]=16777215, [2]=65280, [3]=255, [4]=10181046, [5]=16766720, [6]=16711680, [7]=0}

for _, module in pairs(ItemsFolder:GetChildren()) do
    if module:IsA("ModuleScript") then
        local s, r = pcall(function() return require(module) end)
        if s and r.Data and r.Data.Id then
            local d = r.Data
            FishDatabase[d.Id] = {Name=d.Name, Tier=d.Tier, Icon=d.Icon}
        end
    end
end

-- Sender Function
local function sendWebhook(fishData, dynamicStats)
    if not getgenv().FishConfig.Active then return end
    local url = getgenv().FishConfig.WebhookUrl
    if url == "" then url = DEFAULT_WEBHOOK end

    -- Validasi fishData
    if not fishData then
        warn("❌ fishData is nil in sendWebhook")
        return
    end
    
    local iconID = fishData.Icon and string.match(tostring(fishData.Icon), "%d+") or nil
    local realImageUrl = getRealImageUrl(iconID)
    local playerName = (LocalPlayer and LocalPlayer.DisplayName) or "Player"
    local playerUserId = (LocalPlayer and LocalPlayer.UserId) or 0
    local playerProfileLink = "https://www.roblox.com/users/" .. tostring(playerUserId) .. "/profile"
    local fishTier = fishData.Tier or 1
    local rarityName = RarityList[fishTier] or "Unknown"

    -- Build embed fields sesuai format gambar
    local embedFields = {}
    
    -- Field 1: Fish Name (dengan validasi)
    table.insert(embedFields, {
        ["name"] = "Fish Name",
        ["value"] = fishData.Name or "Unknown Fish",
        ["inline"] = false
    })
    
    -- Field 2: Fish Tier
    table.insert(embedFields, {
        ["name"] = "Fish Tier",
        ["value"] = rarityName,
        ["inline"] = false
    })
    
    -- Field 3: Weight (jika ada)
    local weight = nil
    if dynamicStats and type(dynamicStats) == "table" and dynamicStats.Weight then
        weight = tostring(dynamicStats.Weight)
        -- Format weight dengan 2 desimal jika perlu
        if tonumber(weight) then
            weight = string.format("%.2f", tonumber(weight))
        end
        table.insert(embedFields, {
            ["name"] = "Weight",
            ["value"] = tostring(weight) .. " Kg",
            ["inline"] = false
        })
    end
    
    -- Field 4: Mutation (Hanya Shiny, Big, atau VariantSeed - VariantId TIDAK ditampilkan)
    local mutationParts = {}
    
    if dynamicStats and type(dynamicStats) == "table" then
        -- Prioritas 1: Jika ada VariantSeed, format sebagai "shiny + VariantSeed"
        if dynamicStats.VariantSeed then
            table.insert(mutationParts, "shiny + " .. tostring(dynamicStats.VariantSeed))
        else
            -- Prioritas 2: Cek Shiny (boolean atau string)
            -- Catatan: VariantId diabaikan/tidak ditampilkan
            if dynamicStats.Shiny then
                local shinyValue = dynamicStats.Shiny
                if type(shinyValue) == "boolean" and shinyValue == true then
                    table.insert(mutationParts, "Shiny")
                elseif type(shinyValue) == "string" and shinyValue ~= "" then
                    table.insert(mutationParts, shinyValue)
                elseif type(shinyValue) ~= "boolean" and shinyValue then
                    table.insert(mutationParts, tostring(shinyValue))
                end
            end
            
            -- Prioritas 3: Cek Big (boolean atau string)
            if dynamicStats.Big then
                local bigValue = dynamicStats.Big
                if type(bigValue) == "boolean" and bigValue == true then
                    table.insert(mutationParts, "Big")
                elseif type(bigValue) == "string" and bigValue ~= "" then
                    table.insert(mutationParts, bigValue)
                elseif type(bigValue) ~= "boolean" and bigValue then
                    table.insert(mutationParts, tostring(bigValue))
                end
            end
        end
        -- Catatan: VariantId sengaja diabaikan dan tidak ditampilkan di mutation field
    end
    
    -- Tambahkan Mutation field jika ada mutation parts
    if #mutationParts > 0 then
        local mutationValue = table.concat(mutationParts, ", ")
        table.insert(embedFields, {
            ["name"] = "Mutation",
            ["value"] = mutationValue,
            ["inline"] = false
        })
    end

    -- Build description sesuai format gambar (dengan validasi untuk mencegah nil concatenation)
    local fishName = (fishData.Name and tostring(fishData.Name)) or "Unknown Fish"
    local description
    -- Pastikan semua variabel tidak nil sebelum concatenation
    playerName = tostring(playerName or "Player")
    fishName = tostring(fishName or "Unknown Fish")
    rarityName = tostring(rarityName or "Unknown")
    
    if weight then
        weight = tostring(weight)
        description = playerName .. " You have obtained a new fish! **" .. fishName .. "** with rarity " .. rarityName .. " and weight " .. weight .. " Kg"
    else
        description = playerName .. " You have obtained a new fish! **" .. fishName .. "** with rarity " .. rarityName
    end

    local payload = {
        ["username"] = "Fish Tracker V12",
        ["avatar_url"] = "https://i.imgur.com/4M7IwwP.png",
        ["embeds"] = {{
            ["description"] = description,
            ["color"] = TierColors[fishTier] or 16777215,
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

-- Test Webhook Function (bypass master switch)
local function testWebhook()
    local url = getgenv().FishConfig.WebhookUrl
    if url == "" then url = DEFAULT_WEBHOOK end
    
    if not url or url == "" then
        Rayfield:Notify({Title = "Error", Content = "Webhook URL kosong! Masukkan webhook URL terlebih dahulu.", Duration = 5})
        return
    end
    
    -- Data dummy untuk test
    local testFishData = {
        Name = "Test Fish",
        Tier = 4,  -- Epic
        Icon = "rbxassetid://0"  -- Dummy icon
    }
    
    local testDynamicStats = {
        Weight = 24.60,
        Shiny = true,
        VariantSeed = 12345
    }
    
    local playerName = LocalPlayer.DisplayName
    local rarityName = RarityList[testFishData.Tier] or "Unknown"
    local iconID = string.match(tostring(testFishData.Icon), "%d+")
    local realImageUrl = getRealImageUrl(iconID)
    
    -- Build embed fields
    local embedFields = {}
    
    -- Field 1: Fish Name
    table.insert(embedFields, {
        ["name"] = "Fish Name",
        ["value"] = testFishData.Name,
        ["inline"] = false
    })
    
    -- Field 2: Fish Tier
    table.insert(embedFields, {
        ["name"] = "Fish Tier",
        ["value"] = rarityName,
        ["inline"] = false
    })
    
    -- Field 3: Weight
    local weight = string.format("%.2f", testDynamicStats.Weight)
    table.insert(embedFields, {
        ["name"] = "Weight",
        ["value"] = weight .. " Kg",
        ["inline"] = false
    })
    
    -- Field 4: Mutation
    local mutationValue = "shiny + " .. tostring(testDynamicStats.VariantSeed)
    table.insert(embedFields, {
        ["name"] = "Mutation",
        ["value"] = mutationValue,
        ["inline"] = false
    })
    
    -- Build description
    local description = playerName .. " You have obtained a new fish! **" .. testFishData.Name .. "** with rarity " .. rarityName .. " and weight " .. weight .. " Kg"
    
    local payload = {
        ["username"] = "Fish Tracker V12 [TEST]",
        ["avatar_url"] = "https://i.imgur.com/4M7IwwP.png",
        ["embeds"] = {{
            ["description"] = description,
            ["color"] = TierColors[testFishData.Tier] or 16777215,
            ["fields"] = embedFields,
            ["thumbnail"] = {["url"] = realImageUrl},
            ["footer"] = {["text"] = "Rayfield V12 | TEST | " .. os.date("%X")}
        }}
    }
    
    -- Send test webhook
    local success, response = pcall(function()
        return httpRequest({
            Url = url,
            Method = "POST",
            Headers = {["Content-Type"]="application/json"},
            Body = HttpService:JSONEncode(payload)
        })
    end)
    
    if success then
        Rayfield:Notify({Title = "Success", Content = "Test webhook berhasil dikirim! Cek Discord webhook Anda.", Duration = 5})
    else
        Rayfield:Notify({Title = "Error", Content = "Gagal mengirim test webhook: " .. tostring(response), Duration = 5})
    end
end

-- Expose test function to global untuk bisa dipanggil dari button
getgenv().TestWebhook = testWebhook

-- Listener
local function getRemote(name)
    local index = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("_Index", 5)
    if not index then return nil end
    for _, child in pairs(index:GetChildren()) do
        if string.find(child.Name, "sleitnick_net") then
            local net = child:FindFirstChild("net")
            return net and (net:FindFirstChild(name) or net:FindFirstChild(string.gsub(name, "/", ".")))
        end
    end
    return nil
end

local remote = getRemote("RE/ObtainedNewFishNotification")

if remote then
    Rayfield:Notify({Title = "Tracker Siap", Content = "Menu V12 Aktif (Multi-Select)", Duration = 5})
    
    remote.OnClientEvent:Connect(function(...)
        -- Cek Master Switch
        if not getgenv().FishConfig.Active then return end

        local args = {...}
        local arg1, arg2 = args[1], args[2]
        
        if type(arg1) == "number" then
            local info = FishDatabase[arg1]
            if info then
                -- [[ LOGIKA FILTER BARU (MULTI-SELECT) ]]
                -- Cek apakah Rarity ikan ini dicentang (True) di Config
                if getgenv().FishConfig.RarityFilter[info.Tier] == true then
                    local stats = (type(arg2) == "table" and arg2) or {}
                    sendWebhook(info, stats)
                end
            end
        end
    end)
end

-- ====================================================
-- 4. ANTI-AFK SYSTEM
-- ====================================================
local function setupAntiAFK()
    -- Connect to Idled event untuk trigger anti-AFK
    LocalPlayer.Idled:Connect(function()
        if getgenv().FishConfig.AntiAFK then
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end
    end)
    
    -- Also setup periodic check untuk lebih reliable
    spawn(function()
        while wait(20) do -- Check setiap 20 detik
            if getgenv().FishConfig.AntiAFK then
                pcall(function()
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new())
                end)
            end
        end
    end)
end

-- Initialize Anti-AFK
setupAntiAFK()
