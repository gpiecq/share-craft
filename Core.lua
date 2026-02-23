local addonName, SC = ...

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

local scanPending = false
local craftScanPending = false

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == addonName then
            ShareCraftDB = ShareCraftDB or {}
            SC.db = ShareCraftDB
            print("|cff00ccff[ShareCraft]|r Addon charge. Tapez /sc pour ouvrir.")
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
    end
end)

-- Slash command
SLASH_SHARECRAFT1 = "/sc"
SLASH_SHARECRAFT2 = "/sharecraft"
SlashCmdList["SHARECRAFT"] = function(msg)
    msg = (msg or ""):trim():lower()

    if msg == "debug" then
        SC.debug = not SC.debug
        print("|cff00ccff[ShareCraft]|r Debug " .. (SC.debug and "active" or "desactive"))
        return
    end

    if msg == "scan" then
        print("|cff00ccff[ShareCraft]|r Scan manuel...")
        SC:ScanTradeSkill()
        return
    end

    if not SC.db then
        SC.db = ShareCraftDB or {}
    end
    SC:ToggleMainWindow()
end
