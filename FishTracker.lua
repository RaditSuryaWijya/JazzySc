-- [[ FISH NOTIFIER V15: SMART IDLE SYSTEM ]]
-- Fitur: V14 + Validasi Input (Tidak warning jika player aktif bergerak/klik)

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService") -- Service Baru
local LocalPlayer = Players.LocalPlayer
local VirtualUser = game:GetService("VirtualUser")

-- ====================================================
-- 1. KONFIGURASI GLOBAL
-- ====================================================
getgenv().FishConfig = {
    Active = false,
    WebhookUrl = "", 
    AntiAFK = false,
    AutoSell = false,
    -- Config Monitoring Smart
    LastCatchTime = tick(), -- Waktu terakhir dapat ikan
    LastInputTime = tick(), -- Waktu terakhir player gerak/klik
    IdleWarningSent = false,
    -- Filter Multi-Select
    RarityFilter = {
        [1] = false, [2] = false, 
        [3] = true,  [4] = true,  
        [5] = true,  [6] = true, [7] = true
    }
}

local DEFAULT_WEBHOOK = "https://discord.com/api/webhooks/1451390752054841376/FT_84n6GyaPJQ06T_7Nv8T8E1rEWcgGwIgycywysRUsA4Az7bKbhPuBZs5zKqXo2KJVJ"
local RarityList = {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "SECRET"}

-- ====================================================
-- 2. DETEKSI INPUT (WASD & KLIK)
-- ====================================================
-- Fungsi ini akan mereset timer "LastInputTime" setiap kamu menekan tombol/klik
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    local inputType = input.UserInputType
    local keyCode = input.KeyCode

    -- Cek Mouse Click (Kiri/Kanan)
    if inputType == Enum.UserInputType.MouseButton1 or inputType == Enum.UserInputType.MouseButton2 then
        getgenv().FishConfig.LastInputTime = tick()
    end

    -- Cek Keyboard (WASD, Spasi, Panah, dll)
    if inputType == Enum.UserInputType.Keyboard then
        -- Kita update waktu interaksi apapun tombolnya (indikasi user aktif)
        getgenv().FishConfig.LastInputTime = tick()
    end
end)

-- ====================================================
-- 3. SETUP HTTP & SYSTEM NOTIFICATION
-- ====================================================
local httpRequest = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
if not httpRequest then 
    Rayfield:Notify({Title = "Error", Content = "Executor tidak support HTTP!", Duration = 5})
    return 
end

local function sendSystemWebhook(title, message, color)
    local url = getgenv().FishConfig.WebhookUrl
    if url == "" then url = DEFAULT_WEBHOOK end
    
    local payload = {
        ["username"] = "Fish Monitor V15",
        ["avatar_url"] = "https://i.imgur.com/4M7IwwP.png",
        ["embeds"] = {{
            ["title"] = title,
            ["description"] = message,
            ["color"] = color, 
            ["footer"] = {["text"] = "Smart Monitor | " .. os.date("%X")}
        }}
    }
    
    httpRequest({Url = url, Method = "POST", Headers = {["Content-Type"]="application/json"}, Body = HttpService:JSONEncode(payload)})
end

-- ====================================================
-- 4. SETUP GUI (RAYFIELD)
-- ====================================================
local Window = Rayfield:CreateWindow({
   Name = "Fish Tracker V15 🎣",
   LoadingTitle = "Smart Idle System",
   LoadingSubtitle = "by Jazzy",
   ConfigurationSaving = { Enabled = true, FolderName = "FishTrackerV15", FileName = "Config" },
   Discord = { Enabled = false },
   KeySystem = false,
})

local MainTab = Window:CreateTab("Dashboard", 4483345998)
local UtilTab = Window:CreateTab("Utilities", 4483345998)

-- [DASHBOARD]
MainTab:CreateParagraph({Title = "Status", Content = "Masukkan Webhook & Nyalakan Master Switch."})
MainTab:CreateInput({
   Name = "Webhook URL", PlaceholderText = "Paste Webhook...", RemoveTextAfterFocusLost = false,
   Callback = function(Text) getgenv().FishConfig.WebhookUrl = Text end,
})
if getgenv().FishConfig.WebhookUrl == "" then getgenv().FishConfig.WebhookUrl = DEFAULT_WEBHOOK end

MainTab:CreateToggle({
   Name = "🔥 Master Switch (ON/OFF)", CurrentValue = false, Flag = "MasterSwitch", 
   Callback = function(Value)
      getgenv().FishConfig.Active = Value
      if Value then
          -- Reset semua timer saat dinyalakan
          getgenv().FishConfig.LastCatchTime = tick()
          getgenv().FishConfig.LastInputTime = tick()
          getgenv().FishConfig.IdleWarningSent = false
          sendSystemWebhook("🟢 SYSTEM ONLINE", "Player: **" .. LocalPlayer.DisplayName .. "** ONLINE. Smart Monitor Aktif.", 65280)
      end
   end,
})

-- [RARITY SELECT]
MainTab:CreateSection("Pilih Rarity")
for i, rarityName in ipairs(RarityList) do
    MainTab:CreateToggle({
       Name = "Kirim " .. rarityName, CurrentValue = getgenv().FishConfig.RarityFilter[i],
       Flag = "Filter_" .. rarityName, Callback = function(Value) getgenv().FishConfig.RarityFilter[i] = Value end,
    })
end

-- [UTILITIES]
UtilTab:CreateSection("Selling & AFK")
UtilTab:CreateButton({Name = "💰 Jual Semua (Sell All)", Callback = function() if getgenv().SellAllFish then getgenv().SellAllFish() end end})
UtilTab:CreateToggle({Name = "Auto-Sell", CurrentValue = false, Flag = "AutoSell", Callback = function(Value) getgenv().FishConfig.AutoSell = Value end})
UtilTab:CreateToggle({Name = "🔄 Anti-AFK", CurrentValue = false, Flag = "AntiAFK", Callback = function(Value) getgenv().FishConfig.AntiAFK = Value end})

-- ====================================================
-- 5. LOGIKA MONITORING (SMART CHECK)
-- ====================================================

-- Disconnect Monitor
Players.PlayerRemoving:Connect(function(player)
    if player == LocalPlayer and getgenv().FishConfig.Active then
         sendSystemWebhook("🔴 SYSTEM OFFLINE", "Player: **" .. LocalPlayer.Name .. "** Disconnect/Keluar.", 16711680)
    end
end)

-- Smart Idle Checker Loop
spawn(function()
    while wait(5) do
        if getgenv().FishConfig.Active then
            local currentTime = tick()
            local timeSinceCatch = currentTime - getgenv().FishConfig.LastCatchTime
            local timeSinceInput = currentTime - getgenv().FishConfig.LastInputTime
            
            -- LOGIKA BARU:
            -- Kirim warning HANYA JIKA:
            -- 1. Gak dapet ikan > 60 detik
            -- 2. Gak ada input (WASD/Klik) > 60 detik
            -- 3. Belum pernah kirim warning sebelumnya
            
            if timeSinceCatch > 60 and timeSinceInput > 60 and not getgenv().FishConfig.IdleWarningSent then
                sendSystemWebhook(
                    "⚠️ IDLE ALERT (BENAR-BENAR AFK)", 
                    "Akun **" .. LocalPlayer.Name .. "** terdeteksi:\n1. Tidak dapat ikan (>1 menit)\n2. Tidak ada pergerakan mouse/keyboard (>1 menit)\n\nKemungkinan script/macro mati atau stuck.",
                    16753920 -- Orange
                )
                getgenv().FishConfig.IdleWarningSent = true 
            elseif timeSinceInput < 60 and getgenv().FishConfig.IdleWarningSent then
                -- (Opsional) Jika user bergerak lagi, kita bisa reset status warning agar bisa kirim lagi nanti
                getgenv().FishConfig.IdleWarningSent = false
            end
        end
    end
end)

-- ====================================================
-- 6. LOGIKA UTAMA (SAMA SEPERTI V14)
-- ====================================================
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

local function sendWebhook(fishData, dynamicStats)
    if not getgenv().FishConfig.Active then return end
    local url = getgenv().FishConfig.WebhookUrl
    if url == "" then url = DEFAULT_WEBHOOK end

    local iconID = string.match(tostring(fishData.Icon), "%d+")
    local realImageUrl = getRealImageUrl(iconID)
    local playerName = LocalPlayer.DisplayName
    local playerProfileLink = "https://www.roblox.com/users/" .. LocalPlayer.UserId .. "/profile"
    local tier = fishData.Tier or 1
    local rarityName = RarityList[tier] or "Unknown"
    local embedFields = {{["name"]="💎 Rarity", ["value"]= "**"..rarityName.."**", ["inline"]=true}}

    if dynamicStats and type(dynamicStats) == "table" then
        for k, v in pairs(dynamicStats) do
            if k ~= "VariantSeed" and k ~= "VariantId" and k ~= "Shiny" and k ~= "Big" then
                local t, val, icon = k, tostring(v), "🔹"
                if k == "Weight" then t, val, icon = "Weight", val.." kg", "⚖️" end
                table.insert(embedFields, {["name"]=icon.." "..t, ["value"]="**"..val.."**", ["inline"]=true})
            end
        end
        local mutParts = {}
        if dynamicStats.VariantId then table.insert(mutParts, tostring(dynamicStats.VariantId)) end
        if dynamicStats.Shiny then table.insert(mutParts, "Shiny") end
        if dynamicStats.Big then table.insert(mutParts, "Big") end
        if dynamicStats.VariantSeed then 
            if #mutParts > 0 then table.insert(mutParts, "+ " .. tostring(dynamicStats.VariantSeed))
            else table.insert(mutParts, "Seed: " .. tostring(dynamicStats.VariantSeed)) end
        end
        if #mutParts > 0 then
            table.insert(embedFields, {["name"]="🧬 Mutation", ["value"]="**"..table.concat(mutParts, " ").."**", ["inline"]=true})
        end
    end

    local payload = {
        ["username"] = "Fish Tracker V15",
        ["avatar_url"] = "https://i.imgur.com/4M7IwwP.png",
        ["embeds"] = {{
            ["title"] = "🎣 Ikan Baru Ditangkap!",
            ["description"] = "**" .. fishData.Name .. "** berhasil diamankan.",
            ["color"] = TierColors[tier] or 16777215,
            ["author"] = {["name"] = "Player: " .. playerName, ["url"] = playerProfileLink},
            ["fields"] = embedFields,
            ["thumbnail"] = {["url"] = realImageUrl},
            ["footer"] = {["text"] = "Rayfield V15 | " .. os.date("%X")}
        }}
    }
    httpRequest({Url = url, Method = "POST", Headers = {["Content-Type"]="application/json"}, Body = HttpService:JSONEncode(payload)})
end

getgenv().SellAllFish = function()
    local sellRemote = getRemote("RF/SellAllItems")
    if sellRemote then sellRemote:InvokeServer(); Rayfield:Notify({Title = "💰 Sold!", Content = "Semua ikan dijual.", Duration = 3}) end
end

local remote = getRemote("RE/ObtainedNewFishNotification")
if remote then
    Rayfield:Notify({Title = "System Ready", Content = "Smart Monitor V15 Aktif", Duration = 5})
    
    remote.OnClientEvent:Connect(function(...)
        local args = {...}
        local arg1, arg2 = args[1], args[2]
        
        -- Reset Idle Timer karena berhasil dapat ikan
        getgenv().FishConfig.LastCatchTime = tick()
        getgenv().FishConfig.IdleWarningSent = false 
        
        if type(arg1) == "number" then
            local info = FishDatabase[arg1]
            if info then
                if getgenv().FishConfig.Active and getgenv().FishConfig.RarityFilter[info.Tier] == true then
                    local stats = (type(arg2) == "table" and arg2) or {}
                    sendWebhook(info, stats)
                end
                if getgenv().FishConfig.AutoSell then getgenv().SellAllFish() end
            end
        end
    end)
end

local function setupAntiAFK()
    LocalPlayer.Idled:Connect(function()
        if getgenv().FishConfig.AntiAFK then VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new()) end
    end)
    spawn(function()
        while wait(60) do if getgenv().FishConfig.AntiAFK then pcall(function() VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new()) end) end end
    end)
end
setupAntiAFK()
