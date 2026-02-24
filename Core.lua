local addonName, SC = ...
local L = SC.L

-- Debug mode (toggle with /sc debug)
SC.debug = false

local function debugPrint(...)
    if SC.debug then
        print("|cffff9900[SC Debug]|r", ...)
    end
end
SC.debugPrint = debugPrint

-- Initialize saved variables
ShareCraftDB = ShareCraftDB or {}

-- Main event frame
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("TRADE_SKILL_SHOW")
frame:RegisterEvent("TRADE_SKILL_UPDATE")
frame:RegisterEvent("CRAFT_SHOW")
frame:RegisterEvent("CRAFT_UPDATE")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

local scanPending = false
local craftScanPending = false

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == addonName then
            ShareCraftDB = ShareCraftDB or {}
            SC.db = ShareCraftDB
            SC:CreateMinimapButton()
            print("|cff00ccff[ShareCraft]|r " .. L.msg_addon_loaded)
            self:UnregisterEvent("ADDON_LOADED")
        end
    elseif event == "TRADE_SKILL_SHOW" then
        debugPrint("Event: TRADE_SKILL_SHOW")
        scanPending = true
        C_Timer.After(0.5, function()
            if scanPending then
                scanPending = false
                SC:ScanTradeSkill()
            end
        end)
    elseif event == "TRADE_SKILL_UPDATE" then
        debugPrint("Event: TRADE_SKILL_UPDATE")
        if scanPending then
            scanPending = false
            C_Timer.After(0.3, function()
                SC:ScanTradeSkill()
            end)
        end
    elseif event == "CRAFT_SHOW" then
        debugPrint("Event: CRAFT_SHOW")
        craftScanPending = true
        C_Timer.After(0.5, function()
            if craftScanPending then
                craftScanPending = false
                SC:ScanCraft()
            end
        end)
    elseif event == "CRAFT_UPDATE" then
        debugPrint("Event: CRAFT_UPDATE")
        if craftScanPending then
            craftScanPending = false
            C_Timer.After(0.3, function()
                SC:ScanCraft()
            end)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        debugPrint("Event: PLAYER_ENTERING_WORLD")
        SC:InitGuildDB()
        SC:InitComm()
        SC:UpdateMyCharacterData()
        SC:CleanOldMembers()
        -- Delay SendHello to let guild channel initialize
        C_Timer.After(5, function()
            SC:SendHello()
        end)
    end
end)

-- Slash command
SLASH_SHARECRAFT1 = "/sc"
SLASH_SHARECRAFT2 = "/sharecraft"
SlashCmdList["SHARECRAFT"] = function(msg)
    msg = (msg or ""):trim():lower()

    if msg == "debug" then
        SC.debug = not SC.debug
        print("|cff00ccff[ShareCraft]|r " .. (SC.debug and L.msg_debug_enabled or L.msg_debug_disabled))
        return
    end

    if msg == "scan" then
        print("|cff00ccff[ShareCraft]|r " .. L.msg_scan_manual)
        SC:ScanTradeSkill()
        return
    end

    if msg == "sync" then
        print("|cff00ccff[ShareCraft]|r " .. L.msg_manual_sync)
        SC:UpdateMyCharacterData()
        SC.syncCooldowns = {}  -- Reset cooldowns for force sync
        SC:SendHello()
        return
    end

    if msg == "privacy" then
        SC:TogglePrivacyWindow()
        return
    end

    if not SC.db then
        SC.db = ShareCraftDB or {}
    end
    SC:ToggleMainWindow()
end
