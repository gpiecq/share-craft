local addonName, SC = ...

-- ============================================================
-- ElvUI-style helpers
-- ============================================================

local BACKDROP_INFO = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
}

local COLOR_BG = { 0.1, 0.1, 0.1, 0.92 }
local COLOR_BORDER = { 0.2, 0.2, 0.2, 1 }
local COLOR_BORDER_HIGHLIGHT = { 0.4, 0.4, 0.4, 1 }
local COLOR_BTN = { 0.15, 0.15, 0.15, 1 }
local COLOR_BTN_HOVER = { 0.25, 0.25, 0.25, 1 }
local COLOR_ACCENT = { 0.0, 0.8, 1.0, 1 }
local COLOR_TEXT = { 0.9, 0.9, 0.9, 1 }
local COLOR_LABEL = { 0.6, 0.6, 0.6, 1 }

local function StyleFrame(f)
    f:SetBackdrop(BACKDROP_INFO)
    f:SetBackdropColor(unpack(COLOR_BG))
    f:SetBackdropBorderColor(unpack(COLOR_BORDER))
end

local function CreateStyledButton(parent, width, height, text)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width, height)
    btn:SetBackdrop(BACKDROP_INFO)
    btn:SetBackdropColor(unpack(COLOR_BTN))
    btn:SetBackdropBorderColor(unpack(COLOR_BORDER))

    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.text:SetPoint("CENTER")
    btn.text:SetText(text)
    btn.text:SetTextColor(unpack(COLOR_TEXT))

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(unpack(COLOR_ACCENT))
        self:SetBackdropColor(unpack(COLOR_BTN_HOVER))
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(unpack(COLOR_BORDER))
        self:SetBackdropColor(unpack(COLOR_BTN))
    end)

    return btn
end

local function CreateCloseButton(parent)
    local btn = CreateStyledButton(parent, 20, 20, "x")
    btn.text:SetTextColor(1, 0.3, 0.3)
    btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -4, -4)
    btn:SetScript("OnClick", function() parent:Hide() end)
    btn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(1, 0.3, 0.3, 1)
        self:SetBackdropColor(unpack(COLOR_BTN_HOVER))
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(unpack(COLOR_BORDER))
        self:SetBackdropColor(unpack(COLOR_BTN))
    end)
    return btn
end

local function CreateTitle(parent, text)
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", parent, "TOP", 0, -8)
    title:SetText(text)
    title:SetTextColor(unpack(COLOR_ACCENT))
    return title
end

local function CreateLabel(parent, text)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetText(text)
    label:SetTextColor(unpack(COLOR_LABEL))
    return label
end

local function StyleDropdown(dropdown)
    -- Try to skin the dropdown background to be darker
    local left = _G[dropdown:GetName() .. "Left"]
    local middle = _G[dropdown:GetName() .. "Middle"]
    local right = _G[dropdown:GetName() .. "Right"]
    if left then left:SetAlpha(0) end
    if middle then middle:SetAlpha(0) end
    if right then right:SetAlpha(0) end

    -- Add dark backdrop behind dropdown
    local bg = CreateFrame("Frame", nil, dropdown, "BackdropTemplate")
    bg:SetPoint("TOPLEFT", dropdown, "TOPLEFT", 18, -2)
    bg:SetPoint("BOTTOMRIGHT", dropdown, "BOTTOMRIGHT", -18, 2)
    bg:SetBackdrop(BACKDROP_INFO)
    bg:SetBackdropColor(0.12, 0.12, 0.12, 1)
    bg:SetBackdropBorderColor(unpack(COLOR_BORDER))
    bg:SetFrameLevel(dropdown:GetFrameLevel())

    -- Style the text
    local text = _G[dropdown:GetName() .. "Text"]
    if text then
        text:SetTextColor(unpack(COLOR_TEXT))
    end
end

-- ============================================================
-- Main Window
-- ============================================================

local mainFrame = nil
local exportFrame = nil

local selectedProfession = nil
local selectedCategory = "All"

local function CreateMainWindow()
    local f = CreateFrame("Frame", "ShareCraftMainFrame", UIParent, "BackdropTemplate")
    f:SetSize(300, 260)
    f:SetPoint("CENTER")
    StyleFrame(f)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("DIALOG")

    -- Title
    f.title = CreateTitle(f, "ShareCraft")

    -- Close button
    CreateCloseButton(f)

    -- Separator under title
    local sep = f:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -26)
    sep:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -26)
    sep:SetColorTexture(unpack(COLOR_BORDER))

    -- Profession label + dropdown
    local profLabel = CreateLabel(f, "Metier")
    profLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -36)

    local profDropdown = CreateFrame("Frame", "ShareCraftProfDropdown", f, "UIDropDownMenuTemplate")
    profDropdown:SetPoint("TOPLEFT", profLabel, "BOTTOMLEFT", -16, -2)
    StyleDropdown(profDropdown)
    f.profDropdown = profDropdown

    -- Category label + dropdown
    local catLabel = CreateLabel(f, "Categorie")
    catLabel:SetPoint("TOPLEFT", profDropdown, "BOTTOMLEFT", 16, -6)

    local catDropdown = CreateFrame("Frame", "ShareCraftCatDropdown", f, "UIDropDownMenuTemplate")
    catDropdown:SetPoint("TOPLEFT", catLabel, "BOTTOMLEFT", -16, -2)
    StyleDropdown(catDropdown)
    f.catDropdown = catDropdown

    -- Recipe count
    local countLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countLabel:SetPoint("TOPLEFT", catDropdown, "BOTTOMLEFT", 20, -6)
    countLabel:SetTextColor(unpack(COLOR_TEXT))
    countLabel:SetText("Recettes : 0")
    f.countLabel = countLabel

    -- Export button
    local exportBtn = CreateStyledButton(f, 180, 26, "Exporter en CSV")
    exportBtn.text:SetTextColor(unpack(COLOR_ACCENT))
    exportBtn:SetPoint("BOTTOM", f, "BOTTOM", 0, 12)
    exportBtn:SetScript("OnClick", function()
        if selectedProfession then
            SC:ShowExportWindow(selectedProfession, selectedCategory)
        else
            print("|cff00ccff[ShareCraft]|r Aucun metier selectionne.")
        end
    end)
    exportBtn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(unpack(COLOR_ACCENT))
        self:SetBackdropColor(unpack(COLOR_BTN_HOVER))
    end)
    exportBtn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(unpack(COLOR_BORDER))
        self:SetBackdropColor(unpack(COLOR_BTN))
    end)
    f.exportBtn = exportBtn

    -- ESC to close
    tinsert(UISpecialFrames, "ShareCraftMainFrame")

    f:Hide()
    return f
end

local function GetAvailableProfessions()
    local professions = {}
    if SC.db then
        for profName, _ in pairs(SC.db) do
            table.insert(professions, profName)
        end
    end
    table.sort(professions)
    return professions
end

local function GetCategories()
    if not selectedProfession or not SC.db or not SC.db[selectedProfession] then
        return {}
    end
    return SC.db[selectedProfession].categories or {}
end

local function UpdateRecipeCount()
    if not mainFrame then return end
    if selectedProfession then
        local count = SC:CountRecipes(selectedProfession, selectedCategory)
        mainFrame.countLabel:SetText("Recettes : " .. count)
    else
        mainFrame.countLabel:SetText("Recettes : 0")
    end
end

local function RefreshCategoryDropdown()
    if not mainFrame then return end
    selectedCategory = "All"
    UIDropDownMenu_SetText(mainFrame.catDropdown, "Tous")
    UpdateRecipeCount()
end

local function InitProfessionDropdown(frame, level)
    local professions = GetAvailableProfessions()

    if #professions == 0 then
        local info = UIDropDownMenu_CreateInfo()
        info.text = "Aucun metier scanne"
        info.disabled = true
        info.notCheckable = true
        UIDropDownMenu_AddButton(info, level)
        return
    end

    for _, profName in ipairs(professions) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = profName
        info.checked = (selectedProfession == profName)
        info.func = function()
            selectedProfession = profName
            UIDropDownMenu_SetText(mainFrame.profDropdown, profName)
            RefreshCategoryDropdown()
            CloseDropDownMenus()
        end
        UIDropDownMenu_AddButton(info, level)
    end
end

local function InitCategoryDropdown(frame, level)
    local allInfo = UIDropDownMenu_CreateInfo()
    allInfo.text = "Tous"
    allInfo.checked = (selectedCategory == "All")
    allInfo.func = function()
        selectedCategory = "All"
        UIDropDownMenu_SetText(mainFrame.catDropdown, "Tous")
        UpdateRecipeCount()
        CloseDropDownMenus()
    end
    UIDropDownMenu_AddButton(allInfo, level)

    local categories = GetCategories()
    for _, cat in ipairs(categories) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = cat
        info.checked = (selectedCategory == cat)
        info.func = function()
            selectedCategory = cat
            UIDropDownMenu_SetText(mainFrame.catDropdown, cat)
            UpdateRecipeCount()
            CloseDropDownMenus()
        end
        UIDropDownMenu_AddButton(info, level)
    end
end

local function SetupDropdowns()
    UIDropDownMenu_SetWidth(mainFrame.profDropdown, 160)
    UIDropDownMenu_Initialize(mainFrame.profDropdown, InitProfessionDropdown)

    local professions = GetAvailableProfessions()
    if #professions > 0 and not selectedProfession then
        selectedProfession = professions[1]
    end
    if selectedProfession then
        UIDropDownMenu_SetText(mainFrame.profDropdown, selectedProfession)
    else
        UIDropDownMenu_SetText(mainFrame.profDropdown, "Selectionner...")
    end

    UIDropDownMenu_SetWidth(mainFrame.catDropdown, 160)
    UIDropDownMenu_Initialize(mainFrame.catDropdown, InitCategoryDropdown)
    UIDropDownMenu_SetText(mainFrame.catDropdown, "Tous")

    selectedCategory = "All"
    UpdateRecipeCount()
end

function SC:ToggleMainWindow()
    if not mainFrame then
        mainFrame = CreateMainWindow()
    end

    if mainFrame:IsShown() then
        mainFrame:Hide()
    else
        SetupDropdowns()
        mainFrame:Show()
    end
end

-- ============================================================
-- Export Window
-- ============================================================

local function CreateExportWindow()
    local f = CreateFrame("Frame", "ShareCraftExportFrame", UIParent, "BackdropTemplate")
    f:SetSize(620, 420)
    f:SetPoint("CENTER")
    StyleFrame(f)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("DIALOG")

    -- Title
    f.title = CreateTitle(f, "ShareCraft - Export CSV")

    -- Close button
    CreateCloseButton(f)

    -- Separator
    local sep = f:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -26)
    sep:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -26)
    sep:SetColorTexture(unpack(COLOR_BORDER))

    -- Instructions
    local instructions = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    instructions:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -32)
    instructions:SetText("Ctrl+A pour tout selectionner, puis Ctrl+C pour copier")
    instructions:SetTextColor(unpack(COLOR_LABEL))

    -- EditBox container with dark bg
    local container = CreateFrame("Frame", nil, f, "BackdropTemplate")
    container:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -48)
    container:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 8)
    container:SetBackdrop(BACKDROP_INFO)
    container:SetBackdropColor(0.06, 0.06, 0.06, 1)
    container:SetBackdropBorderColor(unpack(COLOR_BORDER))

    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", "ShareCraftExportScroll", container, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", container, "TOPLEFT", 6, -6)
    scrollFrame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -24, 6)

    -- Style scrollbar
    local scrollBar = _G["ShareCraftExportScrollScrollBar"]
    if scrollBar then
        local thumbTex = scrollBar:GetThumbTexture()
        if thumbTex then
            thumbTex:SetColorTexture(0.3, 0.3, 0.3, 0.8)
            thumbTex:SetSize(8, 24)
        end
    end

    -- EditBox
    local editBox = CreateFrame("EditBox", "ShareCraftExportEditBox", scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetWidth(scrollFrame:GetWidth() or 560)
    editBox:SetAutoFocus(false)
    editBox:SetTextColor(0.85, 0.85, 0.85)

    editBox:SetScript("OnChar", function() end)
    editBox:SetScript("OnKeyDown", function(self, key)
        if IsControlKeyDown() then
            if key == "A" then
                self:HighlightText()
            end
        end
        if key == "ESCAPE" then
            f:Hide()
        end
    end)

    editBox:SetScript("OnEscapePressed", function()
        f:Hide()
    end)

    scrollFrame:SetScrollChild(editBox)
    f.editBox = editBox
    f.scrollFrame = scrollFrame

    tinsert(UISpecialFrames, "ShareCraftExportFrame")

    f:Hide()
    return f
end

-- ============================================================
-- Button on TradeSkillFrame
-- ============================================================

local tradeSkillButton = nil

local function AttachTradeSkillButton()
    if tradeSkillButton then return end
    if not TradeSkillFrame then return end

    local btn = CreateFrame("Button", "ShareCraftTradeSkillBtn", TradeSkillFrame, "BackdropTemplate")
    btn:SetSize(90, 22)
    btn:SetBackdrop(BACKDROP_INFO)
    btn:SetBackdropColor(unpack(COLOR_BTN))
    btn:SetBackdropBorderColor(unpack(COLOR_BORDER))

    -- Anchor next to "Fermer" button if it exists, otherwise top-right
    local closeBtn = TradeSkillFrameCloseButton or _G["TradeSkillFrameCloseButton"]
    if closeBtn and closeBtn:IsVisible() then
        btn:SetPoint("RIGHT", closeBtn, "LEFT", -4, 0)
    else
        btn:SetPoint("TOPRIGHT", TradeSkillFrame, "TOPRIGHT", -28, -2)
    end

    -- Raise above ElvUI elements
    btn:SetFrameStrata("HIGH")
    btn:SetFrameLevel(TradeSkillFrame:GetFrameLevel() + 10)

    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.text:SetPoint("CENTER")
    btn.text:SetText("Export CSV")
    btn.text:SetTextColor(unpack(COLOR_ACCENT))

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(unpack(COLOR_ACCENT))
        self:SetBackdropColor(unpack(COLOR_BTN_HOVER))
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(unpack(COLOR_BORDER))
        self:SetBackdropColor(unpack(COLOR_BTN))
    end)
    btn:SetScript("OnClick", function()
        local skillName = GetTradeSkillLine()
        if not skillName or skillName == "" or skillName == "UNKNOWN" then
            print("|cff00ccff[ShareCraft]|r Aucun metier ouvert.")
            return
        end
        SC:ScanTradeSkill()
        SC:ShowExportWindow(skillName, "All")
    end)

    tradeSkillButton = btn
end

-- ============================================================
-- Button on CraftFrame (Enchanting)
-- ============================================================

local craftButton = nil

local function AttachCraftButton()
    if craftButton then return end
    if not CraftFrame then return end

    local btn = CreateFrame("Button", "ShareCraftCraftBtn", CraftFrame, "BackdropTemplate")
    btn:SetSize(90, 22)
    btn:SetBackdrop(BACKDROP_INFO)
    btn:SetBackdropColor(unpack(COLOR_BTN))
    btn:SetBackdropBorderColor(unpack(COLOR_BORDER))

    local closeBtn = CraftFrameCloseButton or _G["CraftFrameCloseButton"]
    if closeBtn and closeBtn:IsVisible() then
        btn:SetPoint("RIGHT", closeBtn, "LEFT", -4, 0)
    else
        btn:SetPoint("TOPRIGHT", CraftFrame, "TOPRIGHT", -28, -2)
    end

    btn:SetFrameStrata("HIGH")
    btn:SetFrameLevel(CraftFrame:GetFrameLevel() + 10)

    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.text:SetPoint("CENTER")
    btn.text:SetText("Export CSV")
    btn.text:SetTextColor(unpack(COLOR_ACCENT))

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(unpack(COLOR_ACCENT))
        self:SetBackdropColor(unpack(COLOR_BTN_HOVER))
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(unpack(COLOR_BORDER))
        self:SetBackdropColor(unpack(COLOR_BTN))
    end)
    btn:SetScript("OnClick", function()
        local skillName = GetCraftDisplaySkillLine()
        if not skillName or skillName == "" then
            print("|cff00ccff[ShareCraft]|r Aucun metier ouvert.")
            return
        end
        SC:ScanCraft()
        SC:ShowExportWindow(skillName, "All")
    end)

    craftButton = btn
end

-- Hook into both TradeSkillFrame and CraftFrame
local hookFrame = CreateFrame("Frame")
hookFrame:RegisterEvent("TRADE_SKILL_SHOW")
hookFrame:RegisterEvent("CRAFT_SHOW")
hookFrame:SetScript("OnEvent", function(self, event)
    if event == "TRADE_SKILL_SHOW" then
        AttachTradeSkillButton()
    elseif event == "CRAFT_SHOW" then
        AttachCraftButton()
    end
end)

-- ============================================================
-- ShowExportWindow
-- ============================================================

function SC:ShowExportWindow(professionName, categoryFilter)
    local csv, count = self:GenerateCSV(professionName, categoryFilter)
    if not csv or count == 0 then
        print("|cff00ccff[ShareCraft]|r Aucune recette a exporter pour ce filtre.")
        return
    end

    if not exportFrame then
        exportFrame = CreateExportWindow()
    end

    exportFrame.editBox:SetText(csv)
    exportFrame.editBox:SetWidth(exportFrame.scrollFrame:GetWidth())
    exportFrame.title:SetText("ShareCraft - Export CSV (" .. count .. " recettes)")

    exportFrame:Show()

    C_Timer.After(0.1, function()
        exportFrame.editBox:SetFocus()
        exportFrame.editBox:HighlightText()
    end)
end
