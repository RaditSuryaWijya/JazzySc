-- [[ FISH DATABASE EXTRACTOR ]]
-- Fungsi: Ekstrak semua data ikan dari ReplicatedStorage.Items
-- Bisa digunakan sebagai module (require) atau script standalone
--
-- FUNGSI UTAMA UNTUK GET SEMUA DATA (TANPA FILTER):
--   1. buildFishDatabaseRaw() - Build database dengan SEMUA field dari module
--   2. exportAllDataToJSON() - Export semua field ke JSON (tidak filter kolom)
--   3. getAllData() - Return seluruh database tanpa filter
--
-- CONTOH PENGGUNAAN:
--   local FishDB = require(script.FishDatabaseExtractor)
--   local allData = FishDB.getAllData(FishDB.DatabaseRaw)  -- Semua field
--   local jsonAll = FishDB.exportAllDataToJSON(FishDB.DatabaseRaw, true)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

-- ====================================================
-- KONFIGURASI
-- ====================================================
local RarityList = {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "SECRET"}
local TierColors = {
    [1] = 16777215,  -- Common (White)
    [2] = 65280,     -- Uncommon (Green)
    [3] = 255,       -- Rare (Blue)
    [4] = 10181046,  -- Epic (Purple)
    [5] = 16766720,  -- Legendary (Orange)
    [6] = 16711680,  -- Mythic (Red)
    [7] = 0          -- SECRET (Black)
}

-- ====================================================
-- FUNGSI UTAMA: BUILD DATABASE (Filtered - Backward Compatible)
-- ====================================================
local function buildFishDatabase()
    local FishDatabase = {}
    local ItemsFolder = ReplicatedStorage:WaitForChild("Items", 10)
    
    if not ItemsFolder then
        warn("❌ Items folder tidak ditemukan!")
        return FishDatabase
    end
    
    local totalModules = 0
    local successCount = 0
    local failCount = 0
    
    print("🔍 Memulai ekstraksi database ikan...")
    print("📁 Lokasi: ReplicatedStorage.Items")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    for _, module in pairs(ItemsFolder:GetChildren()) do
        if module:IsA("ModuleScript") then
            totalModules = totalModules + 1
            
            local success, result = pcall(function()
                return require(module)
            end)
            
            if success and result and result.Data and result.Data.Id then
                local data = result.Data
                local fishId = data.Id
                
                -- Extract asset ID dari icon string
                local iconAssetId = nil
                if data.Icon then
                    iconAssetId = string.match(tostring(data.Icon), "%d+")
                end
                
                -- Build fish entry
                FishDatabase[fishId] = {
                    Id = fishId,
                    Name = data.Name or "Unknown",
                    Tier = data.Tier or 1,
                    Rarity = RarityList[data.Tier] or "Unknown",
                    Icon = data.Icon or "",
                    IconAssetId = iconAssetId,
                    -- Store original module name untuk referensi
                    ModuleName = module.Name
                }
                
                successCount = successCount + 1
            else
                failCount = failCount + 1
                warn("⚠️ Gagal extract: " .. module.Name)
            end
        end
    end
    
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("✅ Ekstraksi selesai!")
    print("📊 Statistik:")
    print("   • Total ModuleScripts: " .. totalModules)
    print("   • Berhasil: " .. successCount)
    print("   • Gagal: " .. failCount)
    print("   • Total Ikan: " .. successCount)
    
    return FishDatabase
end

-- ====================================================
-- FUNGSI: BUILD DATABASE RAW (Semua Field dari Module)
-- ====================================================
local function buildFishDatabaseRaw()
    local FishDatabase = {}
    local ItemsFolder = ReplicatedStorage:WaitForChild("Items", 10)
    
    if not ItemsFolder then
        warn("❌ Items folder tidak ditemukan!")
        return FishDatabase
    end
    
    local totalModules = 0
    local successCount = 0
    local failCount = 0
    
    print("🔍 Memulai ekstraksi database RAW (semua field)...")
    print("📁 Lokasi: ReplicatedStorage.Items")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    for _, module in pairs(ItemsFolder:GetChildren()) do
        if module:IsA("ModuleScript") then
            totalModules = totalModules + 1
            
            local success, result = pcall(function()
                return require(module)
            end)
            
            if success and result and result.Data and result.Data.Id then
                local data = result.Data
                local fishId = data.Id
                
                -- Copy SEMUA field dari data (deep copy)
                local rawEntry = {}
                for key, value in pairs(data) do
                    rawEntry[key] = value
                end
                
                -- Tambahkan metadata tambahan (tidak overwrite jika sudah ada)
                if not rawEntry.ModuleName then
                    rawEntry.ModuleName = module.Name
                end
                
                -- Tambahkan Rarity string untuk kemudahan (jika Tier ada)
                if rawEntry.Tier and not rawEntry.Rarity then
                    rawEntry.Rarity = RarityList[rawEntry.Tier] or "Unknown"
                end
                
                -- Extract IconAssetId untuk kemudahan
                if rawEntry.Icon and not rawEntry.IconAssetId then
                    rawEntry.IconAssetId = string.match(tostring(rawEntry.Icon), "%d+")
                end
                
                FishDatabase[fishId] = rawEntry
                successCount = successCount + 1
            else
                failCount = failCount + 1
                warn("⚠️ Gagal extract: " .. module.Name)
            end
        end
    end
    
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("✅ Ekstraksi RAW selesai!")
    print("📊 Statistik:")
    print("   • Total ModuleScripts: " .. totalModules)
    print("   • Berhasil: " .. successCount)
    print("   • Gagal: " .. failCount)
    print("   • Total Ikan: " .. successCount)
    
    return FishDatabase
end

-- ====================================================
-- FUNGSI: PRINT DATABASE (HUMAN READABLE)
-- ====================================================
local function printDatabase(FishDatabase)
    if not FishDatabase or next(FishDatabase) == nil then
        print("❌ Database kosong!")
        return
    end
    
    print("\n" .. string.rep("=", 70))
    print("📚 FISH DATABASE - DAFTAR LENGKAP IKAN")
    print(string.rep("=", 70))
    
    -- Sort by ID untuk output yang lebih rapi
    local sortedIds = {}
    for id, _ in pairs(FishDatabase) do
        table.insert(sortedIds, id)
    end
    table.sort(sortedIds)
    
    -- Print by Rarity (Tier)
    for tier = 1, 7 do
        local rarityName = RarityList[tier]
        local tierFishes = {}
        
        for _, id in ipairs(sortedIds) do
            local fish = FishDatabase[id]
            if fish.Tier == tier then
                table.insert(tierFishes, fish)
            end
        end
        
        if #tierFishes > 0 then
            print("\n💎 " .. rarityName .. " (Tier " .. tier .. ") - " .. #tierFishes .. " ikan:")
            print(string.rep("-", 70))
            
            for _, fish in ipairs(tierFishes) do
                local iconInfo = fish.IconAssetId and ("AssetID: " .. fish.IconAssetId) or "No Icon"
                print(string.format(
                    "  ID: %-6s | %s | %s",
                    tostring(fish.Id),
                    fish.Name,
                    iconInfo
                ))
            end
        end
    end
    
    print("\n" .. string.rep("=", 70))
    print("📊 TOTAL: " .. #sortedIds .. " ikan")
    print(string.rep("=", 70) .. "\n")
end

-- ====================================================
-- FUNGSI: EXPORT KE JSON (Filtered - Backward Compatible)
-- ====================================================
local function exportToJSON(FishDatabase, prettyPrint)
    if not FishDatabase or next(FishDatabase) == nil then
        return nil
    end
    
    -- Convert to array format untuk JSON yang lebih readable
    local exportData = {}
    for id, fish in pairs(FishDatabase) do
        table.insert(exportData, {
            Id = fish.Id,
            Name = fish.Name,
            Tier = fish.Tier,
            Rarity = fish.Rarity,
            Icon = fish.Icon,
            IconAssetId = fish.IconAssetId
        })
    end
    
    -- Sort by ID
    table.sort(exportData, function(a, b) return a.Id < b.Id end)
    
    return HttpService:JSONEncode(exportData)
end

-- ====================================================
-- FUNGSI: EXPORT SEMUA DATA KE JSON (Tanpa Filter Kolom)
-- ====================================================
local function exportAllDataToJSON(FishDatabase, prettyPrint)
    if not FishDatabase or next(FishDatabase) == nil then
        return nil
    end
    
    -- Convert to array format, keep ALL fields
    local exportData = {}
    for id, fish in pairs(FishDatabase) do
        -- Copy semua field dari fish entry
        local fishEntry = {}
        for key, value in pairs(fish) do
            fishEntry[key] = value
        end
        table.insert(exportData, fishEntry)
    end
    
    -- Sort by ID (jika ada)
    table.sort(exportData, function(a, b) 
        local idA = a.Id or 0
        local idB = b.Id or 0
        return idA < idB
    end)
    
    return HttpService:JSONEncode(exportData)
end

-- ====================================================
-- FUNGSI: GET ALL DATA (Return Full Database - Semua Field)
-- ====================================================
-- Fungsi ini mengembalikan seluruh database tanpa filter kolom
-- Semua field dari module akan tetap ada (tidak hanya Id, Name, Tier, dll)
--
-- CONTOH PENGGUNAAN:
--   local allData = getAllData(FishDatabaseRaw)
--   for id, fish in pairs(allData) do
--       print(fish.Id, fish.Name)
--       -- Akses SEMUA field yang ada di module (tanpa perlu tahu nama kolom)
--       for key, value in pairs(fish) do
--           print(key, value)  -- Semua field akan muncul
--       end
--   end
local function getAllData(FishDatabase)
    if not FishDatabase or next(FishDatabase) == nil then
        return {}
    end
    
    -- Return copy dari database (semua field tetap ada)
    -- Note: Ini adalah shallow copy, nested tables akan reference yang sama
    local allData = {}
    for id, fish in pairs(FishDatabase) do
        allData[id] = fish
    end
    
    return allData
end

-- ====================================================
-- FUNGSI: GET FISH BY ID
-- ====================================================
local function getFishById(FishDatabase, fishId)
    return FishDatabase[fishId]
end

-- ====================================================
-- FUNGSI: GET FISH BY RARITY/TIER
-- ====================================================
local function getFishByTier(FishDatabase, tier)
    local result = {}
    for id, fish in pairs(FishDatabase) do
        if fish.Tier == tier then
            table.insert(result, fish)
        end
    end
    return result
end

-- ====================================================
-- FUNGSI: SEARCH BY NAME
-- ====================================================
local function searchFishByName(FishDatabase, searchTerm)
    searchTerm = string.lower(searchTerm)
    local result = {}
    
    for id, fish in pairs(FishDatabase) do
        local fishName = string.lower(fish.Name)
        if string.find(fishName, searchTerm, 1, true) then
            table.insert(result, fish)
        end
    end
    
    return result
end

-- ====================================================
-- MODULE EXPORT / STANDALONE EXECUTION
-- ====================================================

-- Build database (filtered - backward compatible)
local FishDatabase = buildFishDatabase()

-- Build raw database (semua field)
local FishDatabaseRaw = buildFishDatabaseRaw()

-- Jika dijalankan sebagai standalone script, print hasil
if not script or script.Parent == nil then
    -- Standalone mode: print database
    printDatabase(FishDatabase)
    
    -- Optional: Export JSON (filtered)
    local jsonData = exportToJSON(FishDatabase, true)
    if jsonData then
        print("📄 JSON Export (Filtered - salin untuk backup):")
        print(string.rep("-", 70))
        print(jsonData)
        print(string.rep("-", 70))
    end
    
    -- Optional: Export JSON (All Data - semua field)
    local jsonDataAll = exportAllDataToJSON(FishDatabaseRaw, true)
    if jsonDataAll then
        print("\n📄 JSON Export (ALL DATA - semua field dari module):")
        print(string.rep("-", 70))
        print(jsonDataAll)
        print(string.rep("-", 70))
    end
else
    -- Module mode: return database dan functions
    return {
        -- Filtered Database (backward compatible)
        Database = FishDatabase,
        
        -- Raw Database (semua field dari module)
        DatabaseRaw = FishDatabaseRaw,
        
        -- Functions
        buildDatabase = buildFishDatabase,
        buildDatabaseRaw = buildFishDatabaseRaw,
        printDatabase = printDatabase,
        exportToJSON = exportToJSON,
        exportAllDataToJSON = exportAllDataToJSON,
        getAllData = getAllData,
        getFishById = getFishById,
        getFishByTier = getFishByTier,
        searchFishByName = searchFishByName,
        RarityList = RarityList,
        TierColors = TierColors
    }
end

