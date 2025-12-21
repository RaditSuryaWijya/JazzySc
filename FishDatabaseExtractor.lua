-- [[ EVENT DATA EXTRACTOR: ObtainedNewFishNotification ]]
-- Fungsi: Capture dan extract semua data dari RE/ObtainedNewFishNotification
-- Tujuan: Analisis struktur data yang dikirim server tanpa filter/processing

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- ====================================================
-- KONFIGURASI
-- ====================================================
local ENABLE_PRINT = true           -- Print ke console saat event terjadi
local ENABLE_LOG_SAVE = false       -- Simpan ke log (jika executor support)
local MAX_LOG_ENTRIES = 100         -- Maksimal entri yang disimpan di memory

-- Storage untuk log data
local EventLog = {}
local EventCount = 0

-- ====================================================
-- HELPER: FORMAT DATA UNTUK PRINT
-- ====================================================
local function formatValue(value, indent, visited)
    indent = indent or 0
    visited = visited or {}
    
    -- Prevent infinite recursion untuk circular references
    if type(value) == "table" then
        if visited[value] then
            return "{...}" -- Circular reference
        end
        visited[value] = true
    end
    
    local indentStr = string.rep("  ", indent)
    local valueType = type(value)
    
    if valueType == "table" then
        local result = "{\n"
        local isEmpty = true
        for k, v in pairs(value) do
            isEmpty = false
            local keyStr = type(k) == "string" and ('"' .. k .. '"') or tostring(k)
            local formattedValue = formatValue(v, indent + 1, visited)
            result = result .. indentStr .. "  [" .. keyStr .. "] = " .. formattedValue .. ",\n"
        end
        if isEmpty then
            result = result .. indentStr .. "  -- (empty table)\n"
        end
        result = result .. indentStr .. "}"
        return result
    elseif valueType == "string" then
        return '"' .. tostring(value) .. '"'
    elseif valueType == "number" then
        return tostring(value)
    elseif valueType == "boolean" then
        return value and "true" or "false"
    elseif valueType == "nil" then
        return "nil"
    else
        return tostring(value) .. " (" .. valueType .. ")"
    end
end

-- ====================================================
-- HELPER: GET REMOTE EVENT
-- ====================================================
local function getRemote(name)
    local index = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("_Index", 5)
    if not index then 
        warn("❌ _Index folder tidak ditemukan!")
        return nil 
    end
    
    for _, child in pairs(index:GetChildren()) do
        if string.find(child.Name, "sleitnick_net") then
            local net = child:FindFirstChild("net")
            if net then
                local remote = net:FindFirstChild(name) or net:FindFirstChild(string.gsub(name, "/", "."))
                if remote then
                    return remote
                end
            end
        end
    end
    
    warn("❌ Remote event '" .. name .. "' tidak ditemukan!")
    return nil
end

-- ====================================================
-- FUNGSI: EXTRACT DAN DISPLAY DATA
-- ====================================================
local function extractEventData(...)
    EventCount = EventCount + 1
    local args = {...}
    local timestamp = os.date("%Y-%m-%d %X")
    
    -- Build data structure
    local eventData = {
        EventNumber = EventCount,
        Timestamp = timestamp,
        PlayerName = LocalPlayer.DisplayName,
        PlayerId = LocalPlayer.UserId,
        ArgumentCount = #args,
        Arguments = {}
    }
    
    -- Extract semua argumen
    for i, arg in ipairs(args) do
        local argType = type(arg)
        local argData = {
            Index = i,
            Type = argType,
            Value = arg,
            Formatted = formatValue(arg, 0)
        }
        
        -- Special handling untuk argumen pertama (biasanya Item ID)
        if i == 1 and argType == "number" then
            argData.Description = "Item ID (Fish ID)"
        elseif i == 2 and argType == "table" then
            argData.Description = "Dynamic Stats (Weight, Mutations, Shiny, etc)"
            -- Extract semua keys dari table
            argData.Keys = {}
            for k, v in pairs(arg) do
                table.insert(argData.Keys, {
                    Key = k,
                    Type = type(v),
                    Value = v
                })
            end
        end
        
        table.insert(eventData.Arguments, argData)
    end
    
    -- Save ke log (jika enabled)
    if ENABLE_LOG_SAVE then
        table.insert(EventLog, eventData)
        -- Keep only last N entries
        if #EventLog > MAX_LOG_ENTRIES then
            table.remove(EventLog, 1)
        end
    end
    
    -- Print ke console (jika enabled)
    if ENABLE_PRINT then
        print(string.rep("=", 80))
        print("🎣 EVENT #" .. EventCount .. " - ObtainedNewFishNotification")
        print("⏰ Timestamp: " .. timestamp)
        print("👤 Player: " .. LocalPlayer.DisplayName .. " (" .. LocalPlayer.UserId .. ")")
        print(string.rep("-", 80))
        print("📦 Total Arguments: " .. #args)
        print()
        
        for i, argData in ipairs(eventData.Arguments) do
            print("📋 Argument #" .. i .. " (" .. argData.Type .. ")")
            if argData.Description then
                print("   📝 " .. argData.Description)
            end
            
            if argData.Type == "table" then
                print("   📊 Keys in table:")
                if argData.Keys then
                    for _, keyInfo in ipairs(argData.Keys) do
                        local valueStr = tostring(keyInfo.Value)
                        if keyInfo.Type == "string" then
                            valueStr = '"' .. valueStr .. '"'
                        end
                        print(string.format("      • %s (%s) = %s", 
                            tostring(keyInfo.Key), 
                            keyInfo.Type, 
                            valueStr
                        ))
                    end
                end
                print("   📄 Full table structure:")
                print(argData.Formatted)
            else
                print("   💾 Value: " .. argData.Formatted)
            end
            print()
        end
        
        print(string.rep("=", 80))
        print()
    end
    
    return eventData
end

-- ====================================================
-- FUNGSI: EXPORT LOG KE JSON
-- ====================================================
local function exportLogToJSON()
    if #EventLog == 0 then
        print("❌ Tidak ada data log untuk di-export!")
        return nil
    end
    
    local jsonData = HttpService:JSONEncode(EventLog)
    return jsonData
end

-- ====================================================
-- FUNGSI: PRINT SUMMARY LOG
-- ====================================================
local function printLogSummary()
    print(string.rep("=", 80))
    print("📊 EVENT LOG SUMMARY")
    print(string.rep("=", 80))
    print("📈 Total Events Captured: " .. #EventLog)
    print()
    
    if #EventLog > 0 then
        print("📋 Recent Events (Last 5):")
        local startIdx = math.max(1, #EventLog - 4)
        for i = startIdx, #EventLog do
            local event = EventLog[i]
            print(string.format("  #%d - %s (Args: %d)", 
                event.EventNumber, 
                event.Timestamp, 
                event.ArgumentCount
            ))
        end
    end
    
    print(string.rep("=", 80))
end

-- ====================================================
-- FUNGSI: CLEAR LOG
-- ====================================================
local function clearLog()
    EventLog = {}
    EventCount = 0
    print("✅ Log berhasil di-clear!")
end

-- ====================================================
-- MAIN: SETUP LISTENER
-- ====================================================
print("🔍 Mencari remote event: RE/ObtainedNewFishNotification")
local remote = getRemote("RE/ObtainedNewFishNotification")

if remote then
    print("✅ Remote event ditemukan!")
    print("🎧 Listener aktif - Menunggu event...")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print()
    
    remote.OnClientEvent:Connect(function(...)
        extractEventData(...)
    end)
    
    -- Export commands (untuk debugging)
    getgenv().EventExtractor = {
        ExportLog = exportLogToJSON,
        PrintSummary = printLogSummary,
        ClearLog = clearLog,
        GetLog = function() return EventLog end,
        GetLogCount = function() return #EventLog end,
        SetPrintEnabled = function(enabled) ENABLE_PRINT = enabled end,
        SetLogEnabled = function(enabled) ENABLE_LOG_SAVE = enabled end
    }
    
    print("💡 Tips:")
    print("   • EventExtractor.PrintSummary() - Lihat summary log")
    print("   • EventExtractor.ExportLog() - Export log ke JSON")
    print("   • EventExtractor.ClearLog() - Clear log")
    print("   • EventExtractor.GetLog() - Dapatkan log array")
    print("   • EventExtractor.SetPrintEnabled(false) - Disable print")
    print("   • EventExtractor.SetLogEnabled(true) - Enable log saving")
    print()
    
else
    warn("❌ Gagal menemukan remote event!")
    warn("   Pastikan game sudah loaded dan remote event exist!")
end

