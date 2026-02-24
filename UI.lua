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
local COLOR_TAB_ACTIVE = { 0.0, 0.8, 1.0, 1 }
local COLOR_TAB_INACTIVE = { 0.2, 0.2, 0.2, 1 }

-- Item quality/rarity colors (WoW standard)
local QUALITY_COLORS = {
    [0] = { 0.62, 0.62, 0.62 },  -- Poor (grey)
    [1] = { 1.00, 1.00, 1.00 },  -- Common (white)
    [2] = { 0.12, 1.00, 0.00 },  -- Uncommon (green)
    [3] = { 0.00, 0.44, 0.87 },  -- Rare (blue)
    [4] = { 0.64, 0.21, 0.93 },  -- Epic (purple)
    [5] = { 1.00, 0.50, 0.00 },  -- Legendary (orange)
    [6] = { 0.90, 0.80, 0.50 },  -- Artifact (gold)
}

local function GetQualityColor(quality)
    return QUALITY_COLORS[quality] or QUALITY_COLORS[1]
end

-- ============================================================
-- Localization (from Data.lua)
-- ============================================================

local L = SC.L

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
    local left = _G[dropdown:GetName() .. "Left"]
    local middle = _G[dropdown:GetName() .. "Middle"]
    local right = _G[dropdown:GetName() .. "Right"]
    if left then left:SetAlpha(0) end
    if middle then middle:SetAlpha(0) end
    if right then right:SetAlpha(0) end

    local bg = CreateFrame("Frame", nil, dropdown, "BackdropTemplate")
    bg:SetPoint("TOPLEFT", dropdown, "TOPLEFT", 18, -2)
    bg:SetPoint("BOTTOMRIGHT", dropdown, "BOTTOMRIGHT", -18, 2)
    bg:SetBackdrop(BACKDROP_INFO)
    bg:SetBackdropColor(0.12, 0.12, 0.12, 1)
    bg:SetBackdropBorderColor(unpack(COLOR_BORDER))
    bg:SetFrameLevel(dropdown:GetFrameLevel())

    local text = _G[dropdown:GetName() .. "Text"]
    if text then
        text:SetTextColor(unpack(COLOR_TEXT))
    end
end

-- ============================================================
-- Main Window with Tab System
-- ============================================================

local mainFrame = nil
local exportFrame = nil
local privacyFrame = nil

-- "Mes recettes" tab state
local selectedProfession = nil
local selectedCategory = "All"

-- "Guilde" tab state
local guildPlayerFilter = "All"
local guildProfFilter = "All"
local guildRecipeFilter = ""
local activeTab = "welcome"  -- "welcome", "recipes", "guild", or "members"

-- Pools for "Mes recettes" list
local myRecipeHeaderPool = {}
local myRecipeFramePool = {}

-- Pools for guild results (headers = FontStrings, recipes = interactive frames)
local guildHeaderPool = {}
local guildRecipePool = {}
local membersFSPool = {}

local function GetOrCreateMyRecipeHeader(parent, index)
    if myRecipeHeaderPool[index] then
        return myRecipeHeaderPool[index]
    end
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetWordWrap(false)
    myRecipeHeaderPool[index] = fs
    return fs
end

local function GetOrCreateMyRecipeFrame(parent, index)
    if myRecipeFramePool[index] then
        return myRecipeFramePool[index]
    end
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(14)
    f:EnableMouse(true)
    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.text:SetPoint("LEFT", f, "LEFT", 0, 0)
    f.text:SetPoint("RIGHT", f, "RIGHT", 0, 0)
    f.text:SetJustifyH("LEFT")
    f.text:SetWordWrap(false)
    myRecipeFramePool[index] = f
    return f
end

local function HideAllMyRecipeElements()
    for _, fs in pairs(myRecipeHeaderPool) do
        fs:Hide()
    end
    for _, f in pairs(myRecipeFramePool) do
        f:Hide()
    end
end

local function GetOrCreateHeader(parent, index)
    if guildHeaderPool[index] then
        return guildHeaderPool[index]
    end
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    guildHeaderPool[index] = fs
    return fs
end

local function GetOrCreateRecipeFrame(parent, index)
    if guildRecipePool[index] then
        return guildRecipePool[index]
    end
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(14)
    f:EnableMouse(true)
    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.text:SetPoint("LEFT", f, "LEFT", 0, 0)
    f.text:SetPoint("RIGHT", f, "RIGHT", 0, 0)
    f.text:SetJustifyH("LEFT")
    f.text:SetWordWrap(false)
    guildRecipePool[index] = f
    return f
end

local function HideAllGuildElements()
    for _, fs in pairs(guildHeaderPool) do
        fs:Hide()
    end
    for _, f in pairs(guildRecipePool) do
        f:Hide()
    end
end

-- Get localized display name for a recipe (cross-locale via itemID)
local function GetDisplayName(recipe)
    if type(recipe) == "table" then
        if recipe.itemID then
            local localName = GetItemInfo(recipe.itemID)
            if localName then return localName end
        end
        return recipe.itemName or recipe.name
    end
    return recipe
end

-- Tooltip: find recipe details from own ShareCraftDB
local function FindRecipeDetails(recipeName, professionName)
    if not SC.db then return nil end
    -- Search in specific profession first
    if professionName and SC.db[professionName] and SC.db[professionName].recipes then
        for _, recipe in ipairs(SC.db[professionName].recipes) do
            if recipe.name == recipeName then
                return recipe, professionName
            end
        end
    end
    -- Search all professions
    for profName, profData in pairs(SC.db) do
        if type(profData) == "table" and profData.recipes then
            for _, recipe in ipairs(profData.recipes) do
                if recipe.name == recipeName then
                    return recipe, profName
                end
            end
        end
    end
    return nil
end

local function ShowRecipeTooltip(frame, recipeName, professionName, guildRecipeData)
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()

    -- Prefer local data (richer), fall back to synced guild data
    local recipe, foundProf = FindRecipeDetails(recipeName, professionName)
    if not recipe and guildRecipeData then
        recipe = guildRecipeData
        foundProf = professionName
    end
    if recipe then
        -- Item name (colored by quality/rarity)
        local qc = GetQualityColor(recipe.quality)
        GameTooltip:AddLine(recipe.name, qc[1], qc[2], qc[3])
        -- Profession - Category (grey)
        if recipe.category then
            GameTooltip:AddLine(foundProf .. " - " .. recipe.category, 0.6, 0.6, 0.6)
        end
        -- Item level
        if recipe.itemLevel and recipe.itemLevel > 0 then
            GameTooltip:AddLine(string.format(L.tooltip_item_level, recipe.itemLevel), 1, 1, 1)
        end
        -- Armor (white, like WoW tooltip)
        if recipe.stats and recipe.stats.armor and recipe.stats.armor > 0 then
            GameTooltip:AddLine(string.format(L.tooltip_armor, recipe.stats.armor), 1, 1, 1)
        end
        -- Primary stats as single lines (white, like WoW tooltip)
        if recipe.stats then
            local s = recipe.stats
            if s.strength and s.strength > 0 then GameTooltip:AddLine(string.format(L.tooltip_strength, s.strength), 1, 1, 1) end
            if s.agility and s.agility > 0 then GameTooltip:AddLine(string.format(L.tooltip_agility, s.agility), 1, 1, 1) end
            if s.stamina and s.stamina > 0 then GameTooltip:AddLine(string.format(L.tooltip_stamina, s.stamina), 1, 1, 1) end
            if s.intellect and s.intellect > 0 then GameTooltip:AddLine(string.format(L.tooltip_intellect, s.intellect), 1, 1, 1) end
            if s.spirit and s.spirit > 0 then GameTooltip:AddLine(string.format(L.tooltip_spirit, s.spirit), 1, 1, 1) end
        end
        -- Required level
        if recipe.requiredLevel and recipe.requiredLevel > 0 then
            GameTooltip:AddLine(string.format(L.tooltip_required_level, recipe.requiredLevel), 1, 1, 1)
        end
        -- Green lines (Utiliser, Equipe, Complet, set bonuses)
        if recipe.greenLines and #recipe.greenLines > 0 then
            for _, line in ipairs(recipe.greenLines) do
                GameTooltip:AddLine(line, 0, 1, 0, true)
            end
        end
        -- Reagents
        if recipe.reagents and #recipe.reagents > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L.tooltip_reagents, 1, 0.82, 0)
            for _, reagent in ipairs(recipe.reagents) do
                if reagent.count and reagent.count > 1 then
                    GameTooltip:AddLine("  " .. reagent.name .. " x" .. reagent.count, 0.9, 0.9, 0.9)
                else
                    GameTooltip:AddLine("  " .. reagent.name, 0.9, 0.9, 0.9)
                end
            end
        end
    else
        GameTooltip:AddLine(recipeName, 1, 1, 1)
        GameTooltip:AddLine(L.tooltip_no_details, 0.6, 0.6, 0.6)
    end

    GameTooltip:Show()
end

local function GetOrCreateMemberFS(parent, index)
    if membersFSPool[index] then
        return membersFSPool[index]
    end
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    membersFSPool[index] = fs
    return fs
end

local function HideAllMemberFS()
    for _, fs in pairs(membersFSPool) do
        fs:Hide()
    end
end

-- ============================================================
-- Tab Switching
-- ============================================================

local function SetTabActive(tab)
    tab:SetBackdropBorderColor(unpack(COLOR_TAB_ACTIVE))
    tab.text:SetTextColor(unpack(COLOR_ACCENT))
end

local function SetTabInactive(tab)
    tab:SetBackdropBorderColor(unpack(COLOR_TAB_INACTIVE))
    tab.text:SetTextColor(unpack(COLOR_TEXT))
end

-- ============================================================
-- "Mes recettes" Recipe List Display
-- ============================================================

function RefreshRecipeList()
    if not mainFrame or not mainFrame.myRecipeScrollChild then return end

    HideAllMyRecipeElements()

    local scrollChild = mainFrame.myRecipeScrollChild
    local scrollWidth = mainFrame.myRecipeScrollFrame:GetWidth() or 300
    local yOffset = 0
    local headerIndex = 0
    local recipeIndex = 0

    if not selectedProfession or not SC.db or not SC.db[selectedProfession] then
        scrollChild:SetHeight(1)
        return
    end

    local profData = SC.db[selectedProfession]
    if not profData.recipes then
        scrollChild:SetHeight(1)
        return
    end

    local currentCategory = nil

    for _, recipe in ipairs(profData.recipes) do
        -- Filter by category
        if selectedCategory ~= "All" and recipe.category ~= selectedCategory then
            -- skip
        else
            -- Category header
            if recipe.category ~= currentCategory then
                currentCategory = recipe.category
                headerIndex = headerIndex + 1
                local headerFS = GetOrCreateMyRecipeHeader(scrollChild, headerIndex)
                headerFS:ClearAllPoints()
                headerFS:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 4, -yOffset)
                headerFS:SetText(currentCategory or L.label_other)
                headerFS:SetTextColor(unpack(COLOR_ACCENT))
                headerFS:SetFont("Fonts\\FRIZQT__.TTF", 11)
                headerFS:Show()
                yOffset = yOffset + 16
            end

            -- Recipe line
            recipeIndex = recipeIndex + 1
            local rf = GetOrCreateMyRecipeFrame(scrollChild, recipeIndex)
            rf:ClearAllPoints()
            rf:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 20, -yOffset)
            rf:SetSize(scrollWidth - 30, 14)
            local displayName = GetDisplayName(recipe)
            rf.text:SetText(displayName)
            rf.text:SetFont("Fonts\\FRIZQT__.TTF", 10)

            -- Color by quality
            local baseColor = COLOR_TEXT
            if recipe.quality and recipe.quality >= 2 then
                baseColor = GetQualityColor(recipe.quality)
            end
            rf.text:SetTextColor(baseColor[1], baseColor[2], baseColor[3])

            -- Tooltip on hover
            local rName = recipe.name
            local rProf = selectedProfession
            local savedColor = baseColor
            rf:SetScript("OnEnter", function(self)
                self.text:SetTextColor(1, 1, 1)
                ShowRecipeTooltip(self, rName, rProf)
            end)
            rf:SetScript("OnLeave", function(self)
                self.text:SetTextColor(savedColor[1], savedColor[2], savedColor[3])
                GameTooltip:Hide()
            end)

            rf:Show()
            yOffset = yOffset + 14
        end
    end

    scrollChild:SetHeight(math.max(yOffset + 10, 1))
end

local function SwitchTab(tabName)
    if not mainFrame then return end
    activeTab = tabName

    -- Reset all tabs
    SetTabInactive(mainFrame.welcomeTab)
    SetTabInactive(mainFrame.recipesTab)
    SetTabInactive(mainFrame.guildTab)
    SetTabInactive(mainFrame.membersTab)
    mainFrame.welcomeContent:Hide()
    mainFrame.recipesContent:Hide()
    mainFrame.guildContent:Hide()
    mainFrame.membersContent:Hide()

    if tabName == "welcome" then
        SetTabActive(mainFrame.welcomeTab)
        mainFrame.welcomeContent:Show()
    elseif tabName == "recipes" then
        SetTabActive(mainFrame.recipesTab)
        mainFrame.recipesContent:Show()
        RefreshRecipeList()
    elseif tabName == "guild" then
        SetTabActive(mainFrame.guildTab)
        mainFrame.guildContent:Show()
        RefreshGuildResults()
    elseif tabName == "members" then
        SetTabActive(mainFrame.membersTab)
        mainFrame.membersContent:Show()
        RefreshMembersList()
    end
end

-- ============================================================
-- Guild Results Display
-- ============================================================

local function FormatScanTime(timestamp)
    if not timestamp then return "" end
    return date("%d/%m/%Y", timestamp)
end

function RefreshGuildResults()
    if not mainFrame or not mainFrame.guildContent then return end

    local results, _, playerCount = SC:SearchGuild(guildPlayerFilter, guildProfFilter, guildRecipeFilter)

    -- Clear previous results
    HideAllGuildElements()

    -- Build a map: recipeName -> { recipe, profName, crafters[] }
    local recipeMap = {}   -- recipeName -> entry
    local recipeOrder = {} -- ordered list of recipe names
    local playersSet = {}

    for _, entry in ipairs(results) do
        local profName = entry.profession
        for _, recipe in ipairs(entry.recipes) do
            local recipeName = type(recipe) == "table" and recipe.name or recipe
            local displayName = GetDisplayName(recipe)
            -- Group by itemID when available (cross-locale), else by display name
            local groupKey = (type(recipe) == "table" and recipe.itemID)
                and ("id:" .. recipe.itemID) or displayName
            playersSet[entry.charKey] = true

            if not recipeMap[groupKey] then
                recipeMap[groupKey] = {
                    name = recipeName,
                    displayName = displayName,
                    recipe = recipe,
                    profName = profName,
                    crafters = {},
                }
                table.insert(recipeOrder, groupKey)
            end

            -- Avoid duplicate crafter names
            local alreadyListed = false
            for _, c in ipairs(recipeMap[groupKey].crafters) do
                if c == entry.charKey then
                    alreadyListed = true
                    break
                end
            end
            if not alreadyListed then
                table.insert(recipeMap[groupKey].crafters, entry.charKey)
            end

            -- Keep richest recipe data (table with quality > string)
            local existing = recipeMap[groupKey].recipe
            if type(recipe) == "table" and type(existing) ~= "table" then
                recipeMap[groupKey].recipe = recipe
                recipeMap[groupKey].profName = profName
                recipeMap[groupKey].displayName = displayName
            end
        end
    end

    -- Sort recipes alphabetically by display name
    table.sort(recipeOrder, function(a, b)
        local nameA = recipeMap[a].displayName or recipeMap[a].name
        local nameB = recipeMap[b].displayName or recipeMap[b].name
        return nameA:lower() < nameB:lower()
    end)

    -- Update summary label
    mainFrame.guildSummary:SetText(string.format(L.guild_results, #recipeOrder, playerCount))

    local scrollChild = mainFrame.guildScrollChild
    local scrollWidth = mainFrame.guildScrollFrame:GetWidth() or 300
    local yOffset = 0
    local recipeIndex = 0
    local headerIndex = 0

    for _, groupKey in ipairs(recipeOrder) do
        local data = recipeMap[groupKey]
        local recipe = data.recipe
        local profName = data.profName
        local displayName = data.displayName or data.name
        local recipeName = data.name

        -- Recipe line (interactive frame with quality color + tooltip)
        recipeIndex = recipeIndex + 1
        local rf = GetOrCreateRecipeFrame(scrollChild, recipeIndex)
        rf:ClearAllPoints()
        rf:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 4, -yOffset)
        rf:SetSize(scrollWidth - 14, 14)
        rf.text:SetText(displayName)
        rf.text:SetFont("Fonts\\FRIZQT__.TTF", 10)

        -- Color by item quality (synced data or local fallback)
        local baseColor = COLOR_TEXT
        local recipeQuality = type(recipe) == "table" and recipe.quality or nil
        if not recipeQuality then
            local details = FindRecipeDetails(recipeName, profName)
            recipeQuality = details and details.quality
        end
        if recipeQuality and recipeQuality >= 2 then
            baseColor = GetQualityColor(recipeQuality)
        end
        rf.text:SetTextColor(baseColor[1], baseColor[2], baseColor[3])

        -- Tooltip on hover (pass synced data for fallback)
        local rName, rProf = recipeName, profName
        local rData = type(recipe) == "table" and recipe or nil
        local savedColor = baseColor
        rf:SetScript("OnEnter", function(self)
            self.text:SetTextColor(1, 1, 1)
            ShowRecipeTooltip(self, rName, rProf, rData)
        end)
        rf:SetScript("OnLeave", function(self)
            self.text:SetTextColor(savedColor[1], savedColor[2], savedColor[3])
            GameTooltip:Hide()
        end)

        rf:Show()
        yOffset = yOffset + 14

        -- Crafters line (FontString, grey, indented)
        headerIndex = headerIndex + 1
        local headerFS = GetOrCreateHeader(scrollChild, headerIndex)
        headerFS:ClearAllPoints()
        headerFS:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 20, -yOffset)
        table.sort(data.crafters, function(a, b) return a:lower() < b:lower() end)
        headerFS:SetText(table.concat(data.crafters, ", "))
        headerFS:SetTextColor(unpack(COLOR_LABEL))
        headerFS:SetFont("Fonts\\FRIZQT__.TTF", 10)
        headerFS:Show()
        yOffset = yOffset + 14

        yOffset = yOffset + 2  -- small spacing between recipe groups
    end

    -- Update scroll child height
    scrollChild:SetHeight(math.max(yOffset + 10, 1))
end

-- ============================================================
-- Members List Display
-- ============================================================

function RefreshMembersList()
    if not mainFrame or not mainFrame.membersContent then return end

    HideAllMemberFS()

    local members = SC:GetAllMembers()
    local scrollChild = mainFrame.membersScrollChild
    local yOffset = 0
    local fsIndex = 0
    local myKey = SC:GetMyCharKey()

    if #members == 0 then
        fsIndex = fsIndex + 1
        local emptyFS = GetOrCreateMemberFS(scrollChild, fsIndex)
        emptyFS:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 4, 0)
        emptyFS:SetText(L.members_none)
        emptyFS:SetTextColor(unpack(COLOR_LABEL))
        emptyFS:SetFont("Fonts\\FRIZQT__.TTF", 10)
        emptyFS:Show()
        scrollChild:SetHeight(20)
        mainFrame.membersSummary:SetText(L.members_count_zero)
        return
    end

    mainFrame.membersSummary:SetText(string.format(L.members_count, #members, #members > 1 and "s" or ""))

    for _, entry in ipairs(members) do
        local charKey = entry.charKey
        local data = entry.data
        local syncDate = FormatScanTime(data.lastSync)
        local isMe = (charKey == myKey)

        -- Player header
        fsIndex = fsIndex + 1
        local playerFS = GetOrCreateMemberFS(scrollChild, fsIndex)
        playerFS:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 4, -yOffset)
        local playerText = charKey .. "  (" .. syncDate .. ")"
        if isMe then
            playerText = charKey .. "  " .. L.members_me
        end
        playerFS:SetText(playerText)
        playerFS:SetTextColor(unpack(COLOR_ACCENT))
        playerFS:SetFont("Fonts\\FRIZQT__.TTF", 11)
        playerFS:Show()
        yOffset = yOffset + 16

        -- Professions
        if data.professions then
            local profList = {}
            for profName, profData in pairs(data.professions) do
                table.insert(profList, { name = profName, data = profData })
            end
            table.sort(profList, function(a, b) return a.name < b.name end)

            for _, prof in ipairs(profList) do
                local recipeCount = prof.data.recipes and #prof.data.recipes or 0
                local profScanDate = FormatScanTime(prof.data.scanTime)

                fsIndex = fsIndex + 1
                local profFS = GetOrCreateMemberFS(scrollChild, fsIndex)
                profFS:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 20, -yOffset)
                profFS:SetText(string.format(L.members_recipes_fmt, prof.name, recipeCount, profScanDate))
                profFS:SetTextColor(unpack(COLOR_TEXT))
                profFS:SetFont("Fonts\\FRIZQT__.TTF", 10)
                profFS:Show()
                yOffset = yOffset + 14
            end
        end

        yOffset = yOffset + 6
    end

    scrollChild:SetHeight(math.max(yOffset + 10, 1))
end

-- ============================================================
-- Welcome Content Builder
-- ============================================================

local function BuildWelcomeContent(scrollChild)
    local contentWidth = scrollChild:GetWidth() or 700
    local yOffset = -10

    local function AddTitle(text)
        local fs = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 10, yOffset)
        fs:SetWidth(contentWidth - 40)
        fs:SetJustifyH("LEFT")
        fs:SetText(text)
        fs:SetTextColor(unpack(COLOR_ACCENT))
        fs:SetFont("Fonts\\FRIZQT__.TTF", 13)
        fs:SetWordWrap(true)
        yOffset = yOffset - (fs:GetStringHeight() + 12)
    end

    local function AddText(text)
        local fs = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 10, yOffset)
        fs:SetWidth(contentWidth - 40)
        fs:SetJustifyH("LEFT")
        fs:SetText(text)
        fs:SetTextColor(unpack(COLOR_TEXT))
        fs:SetFont("Fonts\\FRIZQT__.TTF", 11)
        fs:SetWordWrap(true)
        yOffset = yOffset - (fs:GetStringHeight() + 10)
    end

    AddTitle(L.welcome_title)

    AddTitle(L.welcome_commands)
    AddText(L.cmd_sc)
    AddText(L.cmd_scan)
    AddText(L.cmd_sync)
    AddText(L.cmd_privacy)
    AddText(L.cmd_debug)

    AddTitle(L.welcome_recipes)
    AddText(L.welcome_recipes_text)

    AddTitle(L.welcome_guild)
    AddText(L.welcome_guild_text)

    AddTitle(L.welcome_members)
    AddText(L.welcome_members_text)

    AddTitle(L.welcome_privacy)
    AddText(L.welcome_privacy_text)

    AddTitle(L.welcome_csv)
    AddText(L.welcome_csv_text)

    AddTitle(L.welcome_tooltip)
    AddText(L.welcome_tooltip_text)

    scrollChild:SetHeight(math.abs(yOffset) + 10)
end

-- ============================================================
-- Create Main Window
-- ============================================================

local function CreateMainWindow()
    local f = CreateFrame("Frame", "ShareCraftMainFrame", UIParent, "BackdropTemplate")
    f:SetSize(760, 600)
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

    -- ============================================================
    -- Tab Buttons
    -- ============================================================

    local tabWidth = 112
    local tabHeight = 22
    local tabGap = 4

    local welcomeTab = CreateFrame("Button", nil, f, "BackdropTemplate")
    welcomeTab:SetSize(tabWidth, tabHeight)
    welcomeTab:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -32)
    welcomeTab:SetBackdrop(BACKDROP_INFO)
    welcomeTab:SetBackdropColor(unpack(COLOR_BTN))
    welcomeTab:SetBackdropBorderColor(unpack(COLOR_TAB_ACTIVE))
    welcomeTab.text = welcomeTab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    welcomeTab.text:SetPoint("CENTER")
    welcomeTab.text:SetText(L.tab_welcome)
    welcomeTab.text:SetTextColor(unpack(COLOR_ACCENT))
    welcomeTab:SetScript("OnClick", function() SwitchTab("welcome") end)
    welcomeTab:SetScript("OnEnter", function(self)
        self:SetBackdropColor(unpack(COLOR_BTN_HOVER))
    end)
    welcomeTab:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(COLOR_BTN))
    end)
    f.welcomeTab = welcomeTab

    local recipesTab = CreateFrame("Button", nil, f, "BackdropTemplate")
    recipesTab:SetSize(tabWidth, tabHeight)
    recipesTab:SetPoint("LEFT", welcomeTab, "RIGHT", tabGap, 0)
    recipesTab:SetBackdrop(BACKDROP_INFO)
    recipesTab:SetBackdropColor(unpack(COLOR_BTN))
    recipesTab:SetBackdropBorderColor(unpack(COLOR_TAB_INACTIVE))
    recipesTab.text = recipesTab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    recipesTab.text:SetPoint("CENTER")
    recipesTab.text:SetText(L.tab_recipes)
    recipesTab.text:SetTextColor(unpack(COLOR_TEXT))
    recipesTab:SetScript("OnClick", function() SwitchTab("recipes") end)
    recipesTab:SetScript("OnEnter", function(self)
        self:SetBackdropColor(unpack(COLOR_BTN_HOVER))
    end)
    recipesTab:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(COLOR_BTN))
    end)
    f.recipesTab = recipesTab

    local guildTab = CreateFrame("Button", nil, f, "BackdropTemplate")
    guildTab:SetSize(tabWidth, tabHeight)
    guildTab:SetPoint("LEFT", recipesTab, "RIGHT", tabGap, 0)
    guildTab:SetBackdrop(BACKDROP_INFO)
    guildTab:SetBackdropColor(unpack(COLOR_BTN))
    guildTab:SetBackdropBorderColor(unpack(COLOR_TAB_INACTIVE))
    guildTab.text = guildTab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    guildTab.text:SetPoint("CENTER")
    guildTab.text:SetText(L.tab_guild)
    guildTab.text:SetTextColor(unpack(COLOR_TEXT))
    guildTab:SetScript("OnClick", function() SwitchTab("guild") end)
    guildTab:SetScript("OnEnter", function(self)
        self:SetBackdropColor(unpack(COLOR_BTN_HOVER))
    end)
    guildTab:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(COLOR_BTN))
    end)
    f.guildTab = guildTab

    local membersTab = CreateFrame("Button", nil, f, "BackdropTemplate")
    membersTab:SetSize(tabWidth, tabHeight)
    membersTab:SetPoint("LEFT", guildTab, "RIGHT", tabGap, 0)
    membersTab:SetBackdrop(BACKDROP_INFO)
    membersTab:SetBackdropColor(unpack(COLOR_BTN))
    membersTab:SetBackdropBorderColor(unpack(COLOR_TAB_INACTIVE))
    membersTab.text = membersTab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    membersTab.text:SetPoint("CENTER")
    membersTab.text:SetText(L.tab_members)
    membersTab.text:SetTextColor(unpack(COLOR_TEXT))
    membersTab:SetScript("OnClick", function() SwitchTab("members") end)
    membersTab:SetScript("OnEnter", function(self)
        self:SetBackdropColor(unpack(COLOR_BTN_HOVER))
    end)
    membersTab:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(COLOR_BTN))
    end)
    f.membersTab = membersTab

    -- Separator under tabs
    local tabSep = f:CreateTexture(nil, "ARTWORK")
    tabSep:SetHeight(1)
    tabSep:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -58)
    tabSep:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -58)
    tabSep:SetColorTexture(unpack(COLOR_BORDER))

    -- ============================================================
    -- "Mes recettes" content (existing functionality)
    -- ============================================================

    local recipesContent = CreateFrame("Frame", nil, f)
    recipesContent:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -62)
    recipesContent:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    f.recipesContent = recipesContent

    -- Profession label + dropdown (left side)
    local profLabel = CreateLabel(recipesContent, L.label_profession)
    profLabel:SetPoint("TOPLEFT", recipesContent, "TOPLEFT", 12, -8)

    local profDropdown = CreateFrame("Frame", "ShareCraftProfDropdown", recipesContent, "UIDropDownMenuTemplate")
    profDropdown:SetPoint("TOPLEFT", profLabel, "BOTTOMLEFT", -16, -2)
    StyleDropdown(profDropdown)
    f.profDropdown = profDropdown

    -- Category label + dropdown (right side, same line)
    local catLabel = CreateLabel(recipesContent, L.label_category)
    catLabel:SetPoint("TOPLEFT", recipesContent, "TOPLEFT", 370, -8)

    local catDropdown = CreateFrame("Frame", "ShareCraftCatDropdown", recipesContent, "UIDropDownMenuTemplate")
    catDropdown:SetPoint("TOPLEFT", catLabel, "BOTTOMLEFT", -16, -2)
    StyleDropdown(catDropdown)
    f.catDropdown = catDropdown

    -- Recipe count
    local countLabel = recipesContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countLabel:SetPoint("TOPLEFT", profDropdown, "BOTTOMLEFT", 20, -6)
    countLabel:SetTextColor(unpack(COLOR_TEXT))
    countLabel:SetText(string.format(L.label_recipes_count, 0))
    f.countLabel = countLabel

    -- Scroll frame for recipe list
    local myRecipeContainer = CreateFrame("Frame", nil, recipesContent, "BackdropTemplate")
    myRecipeContainer:SetPoint("TOPLEFT", countLabel, "BOTTOMLEFT", -8, -6)
    myRecipeContainer:SetPoint("BOTTOMRIGHT", recipesContent, "BOTTOMRIGHT", -8, 44)
    myRecipeContainer:SetBackdrop(BACKDROP_INFO)
    myRecipeContainer:SetBackdropColor(0.06, 0.06, 0.06, 1)
    myRecipeContainer:SetBackdropBorderColor(unpack(COLOR_BORDER))
    myRecipeContainer:SetClipsChildren(true)

    local myRecipeScrollFrame = CreateFrame("ScrollFrame", "ShareCraftMyRecipeScroll", myRecipeContainer, "UIPanelScrollFrameTemplate")
    myRecipeScrollFrame:SetPoint("TOPLEFT", myRecipeContainer, "TOPLEFT", 4, -4)
    myRecipeScrollFrame:SetPoint("BOTTOMRIGHT", myRecipeContainer, "BOTTOMRIGHT", -22, 4)

    local myRecipeScrollBar = _G["ShareCraftMyRecipeScrollScrollBar"]
    if myRecipeScrollBar then
        local thumbTex = myRecipeScrollBar:GetThumbTexture()
        if thumbTex then
            thumbTex:SetColorTexture(0.3, 0.3, 0.3, 0.8)
            thumbTex:SetSize(8, 24)
        end
    end

    local myRecipeScrollChild = CreateFrame("Frame", nil, myRecipeScrollFrame)
    myRecipeScrollChild:SetWidth(myRecipeScrollFrame:GetWidth() or 300)
    myRecipeScrollChild:SetHeight(1)
    myRecipeScrollFrame:SetScrollChild(myRecipeScrollChild)
    f.myRecipeScrollChild = myRecipeScrollChild
    f.myRecipeScrollFrame = myRecipeScrollFrame

    -- Export button
    local exportBtn = CreateStyledButton(recipesContent, 180, 26, L.btn_export_csv)
    exportBtn.text:SetTextColor(unpack(COLOR_ACCENT))
    exportBtn:SetPoint("BOTTOM", recipesContent, "BOTTOM", 0, 12)
    exportBtn:SetScript("OnClick", function()
        if selectedProfession then
            SC:ShowExportWindow(selectedProfession, selectedCategory)
        else
            print("|cff00ccff[ShareCraft]|r " .. L.msg_no_profession)
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

    -- ============================================================
    -- "Guilde" content (new)
    -- ============================================================

    local guildContent = CreateFrame("Frame", nil, f)
    guildContent:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -62)
    guildContent:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    guildContent:Hide()
    f.guildContent = guildContent

    -- Player dropdown (left side)
    local playerLabel = CreateLabel(guildContent, L.label_player)
    playerLabel:SetPoint("TOPLEFT", guildContent, "TOPLEFT", 12, -8)

    local playerDropdown = CreateFrame("Frame", "ShareCraftGuildPlayerDD", guildContent, "UIDropDownMenuTemplate")
    playerDropdown:SetPoint("TOPLEFT", playerLabel, "BOTTOMLEFT", -16, -2)
    StyleDropdown(playerDropdown)
    f.guildPlayerDropdown = playerDropdown

    -- Profession dropdown (right side, same line)
    local gProfLabel = CreateLabel(guildContent, L.label_profession)
    gProfLabel:SetPoint("TOPLEFT", guildContent, "TOPLEFT", 370, -8)

    local gProfDropdown = CreateFrame("Frame", "ShareCraftGuildProfDD", guildContent, "UIDropDownMenuTemplate")
    gProfDropdown:SetPoint("TOPLEFT", gProfLabel, "BOTTOMLEFT", -16, -2)
    StyleDropdown(gProfDropdown)
    f.guildProfDropdown = gProfDropdown

    -- Recipe search EditBox (below dropdowns, full width)
    local recipeLabel = CreateLabel(guildContent, L.label_recipe)
    recipeLabel:SetPoint("TOPLEFT", playerDropdown, "BOTTOMLEFT", 16, -4)

    local searchBox = CreateFrame("EditBox", "ShareCraftGuildSearchBox", guildContent, "BackdropTemplate")
    searchBox:SetSize(500, 22)
    searchBox:SetPoint("TOPLEFT", recipeLabel, "BOTTOMLEFT", 0, -2)
    searchBox:SetBackdrop(BACKDROP_INFO)
    searchBox:SetBackdropColor(0.12, 0.12, 0.12, 1)
    searchBox:SetBackdropBorderColor(unpack(COLOR_BORDER))
    searchBox:SetFontObject(ChatFontNormal)
    searchBox:SetTextColor(unpack(COLOR_TEXT))
    searchBox:SetAutoFocus(false)
    searchBox:SetTextInsets(6, 6, 0, 0)

    searchBox:SetScript("OnEnterPressed", function(self)
        guildRecipeFilter = self:GetText() or ""
        RefreshGuildResults()
        self:ClearFocus()
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    searchBox:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            guildRecipeFilter = self:GetText() or ""
            RefreshGuildResults()
        end
    end)
    f.guildSearchBox = searchBox

    -- Summary label
    local guildSummary = guildContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    guildSummary:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", 0, -8)
    guildSummary:SetTextColor(unpack(COLOR_TEXT))
    guildSummary:SetText(L.guild_results_zero)
    f.guildSummary = guildSummary

    -- Separator
    local resultSep = guildContent:CreateTexture(nil, "ARTWORK")
    resultSep:SetHeight(1)
    resultSep:SetPoint("TOPLEFT", guildSummary, "BOTTOMLEFT", -4, -4)
    resultSep:SetPoint("RIGHT", guildContent, "RIGHT", -12, 0)
    resultSep:SetColorTexture(unpack(COLOR_BORDER))

    -- Scroll frame for results
    local scrollContainer = CreateFrame("Frame", nil, guildContent, "BackdropTemplate")
    scrollContainer:SetPoint("TOPLEFT", resultSep, "BOTTOMLEFT", 0, -2)
    scrollContainer:SetPoint("BOTTOMRIGHT", guildContent, "BOTTOMRIGHT", -8, 44)
    scrollContainer:SetBackdrop(BACKDROP_INFO)
    scrollContainer:SetBackdropColor(0.06, 0.06, 0.06, 1)
    scrollContainer:SetBackdropBorderColor(unpack(COLOR_BORDER))
    scrollContainer:SetClipsChildren(true)

    local scrollFrame = CreateFrame("ScrollFrame", "ShareCraftGuildScroll", scrollContainer, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", scrollContainer, "TOPLEFT", 4, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", scrollContainer, "BOTTOMRIGHT", -22, 4)

    -- Style scrollbar
    local scrollBar = _G["ShareCraftGuildScrollScrollBar"]
    if scrollBar then
        local thumbTex = scrollBar:GetThumbTexture()
        if thumbTex then
            thumbTex:SetColorTexture(0.3, 0.3, 0.3, 0.8)
            thumbTex:SetSize(8, 24)
        end
    end

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(scrollFrame:GetWidth() or 300)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)
    f.guildScrollChild = scrollChild
    f.guildScrollFrame = scrollFrame

    -- Bottom buttons
    local guildExportBtn = CreateStyledButton(guildContent, 120, 24, L.btn_export_csv_short)
    guildExportBtn.text:SetTextColor(unpack(COLOR_ACCENT))
    guildExportBtn:SetPoint("BOTTOMLEFT", guildContent, "BOTTOMLEFT", 12, 12)
    guildExportBtn:SetScript("OnClick", function()
        SC:ShowGuildExportWindow(guildPlayerFilter, guildProfFilter, guildRecipeFilter)
    end)
    guildExportBtn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(unpack(COLOR_ACCENT))
        self:SetBackdropColor(unpack(COLOR_BTN_HOVER))
    end)
    guildExportBtn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(unpack(COLOR_BORDER))
        self:SetBackdropColor(unpack(COLOR_BTN))
    end)

    local privacyBtn = CreateStyledButton(guildContent, 100, 24, L.btn_privacy)
    privacyBtn:SetPoint("LEFT", guildExportBtn, "RIGHT", 6, 0)
    privacyBtn:SetScript("OnClick", function()
        SC:TogglePrivacyWindow()
    end)
    privacyBtn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(unpack(COLOR_ACCENT))
        self:SetBackdropColor(unpack(COLOR_BTN_HOVER))
    end)
    privacyBtn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(unpack(COLOR_BORDER))
        self:SetBackdropColor(unpack(COLOR_BTN))
    end)

    local syncBtn = CreateStyledButton(guildContent, 70, 24, L.btn_sync)
    syncBtn.text:SetTextColor(unpack(COLOR_ACCENT))
    syncBtn:SetPoint("LEFT", privacyBtn, "RIGHT", 6, 0)
    syncBtn:SetScript("OnClick", function()
        print("|cff00ccff[ShareCraft]|r " .. L.msg_manual_sync)
        SC:UpdateMyCharacterData()
        SC.syncCooldowns = {}
        SC:SendHello()
    end)
    syncBtn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(unpack(COLOR_ACCENT))
        self:SetBackdropColor(unpack(COLOR_BTN_HOVER))
    end)
    syncBtn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(unpack(COLOR_BORDER))
        self:SetBackdropColor(unpack(COLOR_BTN))
    end)

    -- ============================================================
    -- "Membres" content
    -- ============================================================

    local membersContent = CreateFrame("Frame", nil, f)
    membersContent:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -62)
    membersContent:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    membersContent:Hide()
    f.membersContent = membersContent

    -- Summary
    local membersSummary = membersContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    membersSummary:SetPoint("TOPLEFT", membersContent, "TOPLEFT", 12, -8)
    membersSummary:SetTextColor(unpack(COLOR_TEXT))
    membersSummary:SetText(L.members_count_zero)
    f.membersSummary = membersSummary

    -- Separator
    local membersSep = membersContent:CreateTexture(nil, "ARTWORK")
    membersSep:SetHeight(1)
    membersSep:SetPoint("TOPLEFT", membersSummary, "BOTTOMLEFT", -4, -4)
    membersSep:SetPoint("RIGHT", membersContent, "RIGHT", -12, 0)
    membersSep:SetColorTexture(unpack(COLOR_BORDER))

    -- Scroll frame
    local membersScrollContainer = CreateFrame("Frame", nil, membersContent, "BackdropTemplate")
    membersScrollContainer:SetPoint("TOPLEFT", membersSep, "BOTTOMLEFT", 0, -2)
    membersScrollContainer:SetPoint("BOTTOMRIGHT", membersContent, "BOTTOMRIGHT", -8, 44)
    membersScrollContainer:SetBackdrop(BACKDROP_INFO)
    membersScrollContainer:SetBackdropColor(0.06, 0.06, 0.06, 1)
    membersScrollContainer:SetBackdropBorderColor(unpack(COLOR_BORDER))
    membersScrollContainer:SetClipsChildren(true)

    local membersScrollFrame = CreateFrame("ScrollFrame", "ShareCraftMembersScroll", membersScrollContainer, "UIPanelScrollFrameTemplate")
    membersScrollFrame:SetPoint("TOPLEFT", membersScrollContainer, "TOPLEFT", 4, -4)
    membersScrollFrame:SetPoint("BOTTOMRIGHT", membersScrollContainer, "BOTTOMRIGHT", -22, 4)

    local membersScrollBar = _G["ShareCraftMembersScrollScrollBar"]
    if membersScrollBar then
        local thumbTex = membersScrollBar:GetThumbTexture()
        if thumbTex then
            thumbTex:SetColorTexture(0.3, 0.3, 0.3, 0.8)
            thumbTex:SetSize(8, 24)
        end
    end

    local membersScrollChild = CreateFrame("Frame", nil, membersScrollFrame)
    membersScrollChild:SetWidth(membersScrollFrame:GetWidth() or 300)
    membersScrollChild:SetHeight(1)
    membersScrollFrame:SetScrollChild(membersScrollChild)
    f.membersScrollChild = membersScrollChild

    -- Bottom buttons
    local membersSyncBtn = CreateStyledButton(membersContent, 70, 24, L.btn_sync)
    membersSyncBtn.text:SetTextColor(unpack(COLOR_ACCENT))
    membersSyncBtn:SetPoint("BOTTOMLEFT", membersContent, "BOTTOMLEFT", 12, 12)
    membersSyncBtn:SetScript("OnClick", function()
        print("|cff00ccff[ShareCraft]|r " .. L.msg_manual_sync)
        SC:UpdateMyCharacterData()
        SC.syncCooldowns = {}
        SC:SendHello()
    end)
    membersSyncBtn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(unpack(COLOR_ACCENT))
        self:SetBackdropColor(unpack(COLOR_BTN_HOVER))
    end)
    membersSyncBtn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(unpack(COLOR_BORDER))
        self:SetBackdropColor(unpack(COLOR_BTN))
    end)

    local membersPrivacyBtn = CreateStyledButton(membersContent, 100, 24, L.btn_privacy)
    membersPrivacyBtn:SetPoint("LEFT", membersSyncBtn, "RIGHT", 6, 0)
    membersPrivacyBtn:SetScript("OnClick", function()
        SC:TogglePrivacyWindow()
    end)
    membersPrivacyBtn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(unpack(COLOR_ACCENT))
        self:SetBackdropColor(unpack(COLOR_BTN_HOVER))
    end)
    membersPrivacyBtn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(unpack(COLOR_BORDER))
        self:SetBackdropColor(unpack(COLOR_BTN))
    end)

    -- ============================================================
    -- "Bienvenue" / "Welcome" content
    -- ============================================================

    local welcomeContent = CreateFrame("Frame", nil, f)
    welcomeContent:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -62)
    welcomeContent:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    welcomeContent:Hide()
    f.welcomeContent = welcomeContent

    local welcomeScrollContainer = CreateFrame("Frame", nil, welcomeContent, "BackdropTemplate")
    welcomeScrollContainer:SetPoint("TOPLEFT", welcomeContent, "TOPLEFT", 8, -8)
    welcomeScrollContainer:SetPoint("BOTTOMRIGHT", welcomeContent, "BOTTOMRIGHT", -8, 8)
    welcomeScrollContainer:SetBackdrop(BACKDROP_INFO)
    welcomeScrollContainer:SetBackdropColor(0.06, 0.06, 0.06, 1)
    welcomeScrollContainer:SetBackdropBorderColor(unpack(COLOR_BORDER))
    welcomeScrollContainer:SetClipsChildren(true)

    local welcomeScrollFrame = CreateFrame("ScrollFrame", "ShareCraftWelcomeScroll", welcomeScrollContainer, "UIPanelScrollFrameTemplate")
    welcomeScrollFrame:SetPoint("TOPLEFT", welcomeScrollContainer, "TOPLEFT", 4, -4)
    welcomeScrollFrame:SetPoint("BOTTOMRIGHT", welcomeScrollContainer, "BOTTOMRIGHT", -22, 4)

    local welcomeScrollBar = _G["ShareCraftWelcomeScrollScrollBar"]
    if welcomeScrollBar then
        local thumbTex = welcomeScrollBar:GetThumbTexture()
        if thumbTex then
            thumbTex:SetColorTexture(0.3, 0.3, 0.3, 0.8)
            thumbTex:SetSize(8, 24)
        end
    end

    local welcomeScrollChild = CreateFrame("Frame", nil, welcomeScrollFrame)
    welcomeScrollChild:SetWidth(welcomeScrollFrame:GetWidth() or 300)
    welcomeScrollChild:SetHeight(1)
    welcomeScrollFrame:SetScrollChild(welcomeScrollChild)

    BuildWelcomeContent(welcomeScrollChild)

    -- ESC to close
    tinsert(UISpecialFrames, "ShareCraftMainFrame")

    f:Hide()
    return f
end

-- ============================================================
-- "Mes recettes" dropdown helpers (unchanged logic)
-- ============================================================

local function GetAvailableProfessions()
    local professions = {}
    if SC.db then
        for profName, profData in pairs(SC.db) do
            if type(profData) == "table" and profData.recipes then
                table.insert(professions, profName)
            end
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
        mainFrame.countLabel:SetText(string.format(L.label_recipes_count, count))
    else
        mainFrame.countLabel:SetText(string.format(L.label_recipes_count, 0))
    end
    RefreshRecipeList()
end

local function RefreshCategoryDropdown()
    if not mainFrame then return end
    selectedCategory = "All"
    UIDropDownMenu_SetText(mainFrame.catDropdown, L.label_all)
    UpdateRecipeCount()
end

local function InitProfessionDropdown(frame, level)
    local professions = GetAvailableProfessions()

    if #professions == 0 then
        local info = UIDropDownMenu_CreateInfo()
        info.text = L.msg_no_profession_scanned
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
    allInfo.text = L.label_all
    allInfo.checked = (selectedCategory == "All")
    allInfo.func = function()
        selectedCategory = "All"
        UIDropDownMenu_SetText(mainFrame.catDropdown, L.label_all)
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

local function SetupRecipesDropdowns()
    UIDropDownMenu_SetWidth(mainFrame.profDropdown, 200)
    UIDropDownMenu_Initialize(mainFrame.profDropdown, InitProfessionDropdown)

    local professions = GetAvailableProfessions()
    if #professions > 0 and not selectedProfession then
        selectedProfession = professions[1]
    end
    if selectedProfession then
        UIDropDownMenu_SetText(mainFrame.profDropdown, selectedProfession)
    else
        UIDropDownMenu_SetText(mainFrame.profDropdown, L.label_select)
    end

    UIDropDownMenu_SetWidth(mainFrame.catDropdown, 200)
    UIDropDownMenu_Initialize(mainFrame.catDropdown, InitCategoryDropdown)
    UIDropDownMenu_SetText(mainFrame.catDropdown, L.label_all)

    selectedCategory = "All"
    UpdateRecipeCount()
end

-- ============================================================
-- "Guilde" dropdown helpers
-- ============================================================

local function InitGuildPlayerDropdown(frame, level)
    local allInfo = UIDropDownMenu_CreateInfo()
    allInfo.text = L.label_all
    allInfo.checked = (guildPlayerFilter == "All")
    allInfo.func = function()
        guildPlayerFilter = "All"
        UIDropDownMenu_SetText(mainFrame.guildPlayerDropdown, L.label_all)
        RefreshGuildResults()
        CloseDropDownMenus()
    end
    UIDropDownMenu_AddButton(allInfo, level)

    local players = SC:GetGuildPlayers()
    for _, charKey in ipairs(players) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = charKey
        info.checked = (guildPlayerFilter == charKey)
        info.func = function()
            guildPlayerFilter = charKey
            UIDropDownMenu_SetText(mainFrame.guildPlayerDropdown, charKey)
            RefreshGuildResults()
            CloseDropDownMenus()
        end
        UIDropDownMenu_AddButton(info, level)
    end
end

local function InitGuildProfDropdown(frame, level)
    local allInfo = UIDropDownMenu_CreateInfo()
    allInfo.text = L.label_all
    allInfo.checked = (guildProfFilter == "All")
    allInfo.func = function()
        guildProfFilter = "All"
        UIDropDownMenu_SetText(mainFrame.guildProfDropdown, L.label_all)
        RefreshGuildResults()
        CloseDropDownMenus()
    end
    UIDropDownMenu_AddButton(allInfo, level)

    local professions = SC:GetGuildProfessions()
    for _, profName in ipairs(professions) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = profName
        info.checked = (guildProfFilter == profName)
        info.func = function()
            guildProfFilter = profName
            UIDropDownMenu_SetText(mainFrame.guildProfDropdown, profName)
            RefreshGuildResults()
            CloseDropDownMenus()
        end
        UIDropDownMenu_AddButton(info, level)
    end
end

local function SetupGuildDropdowns()
    UIDropDownMenu_SetWidth(mainFrame.guildPlayerDropdown, 200)
    UIDropDownMenu_Initialize(mainFrame.guildPlayerDropdown, InitGuildPlayerDropdown)
    UIDropDownMenu_SetText(mainFrame.guildPlayerDropdown, L.label_all)

    UIDropDownMenu_SetWidth(mainFrame.guildProfDropdown, 200)
    UIDropDownMenu_Initialize(mainFrame.guildProfDropdown, InitGuildProfDropdown)
    UIDropDownMenu_SetText(mainFrame.guildProfDropdown, L.label_all)

    guildPlayerFilter = "All"
    guildProfFilter = "All"
    guildRecipeFilter = ""
    if mainFrame.guildSearchBox then
        mainFrame.guildSearchBox:SetText("")
    end
end

-- ============================================================
-- ToggleMainWindow
-- ============================================================

function SC:ToggleMainWindow()
    if not mainFrame then
        mainFrame = CreateMainWindow()
    end

    if mainFrame:IsShown() then
        mainFrame:Hide()
    else
        SetupRecipesDropdowns()
        SetupGuildDropdowns()
        SwitchTab(activeTab)
        mainFrame:Show()
    end
end

-- ============================================================
-- Export Window (unchanged)
-- ============================================================

local function CreateExportWindow()
    local f = CreateFrame("Frame", "ShareCraftExportFrame", UIParent, "BackdropTemplate")
    f:SetSize(620, 420)
    f:SetPoint("CENTER", UIParent, "CENTER", 200, 0)
    StyleFrame(f)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("FULLSCREEN_DIALOG")

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
    instructions:SetText(L.export_instructions)
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

    local closeBtn = TradeSkillFrameCloseButton or _G["TradeSkillFrameCloseButton"]
    if closeBtn and closeBtn:IsVisible() then
        btn:SetPoint("RIGHT", closeBtn, "LEFT", -4, 0)
    else
        btn:SetPoint("TOPRIGHT", TradeSkillFrame, "TOPRIGHT", -28, -2)
    end

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
            print("|cff00ccff[ShareCraft]|r " .. L.msg_no_profession_open)
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
            print("|cff00ccff[ShareCraft]|r " .. L.msg_no_profession_open)
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
        print("|cff00ccff[ShareCraft]|r " .. L.msg_no_recipes_export)
        return
    end

    if not exportFrame then
        exportFrame = CreateExportWindow()
    end

    exportFrame.editBox:SetText(csv)
    exportFrame.editBox:SetWidth(exportFrame.scrollFrame:GetWidth())
    exportFrame.title:SetText(string.format(L.export_title_personal, count))

    exportFrame:Show()

    C_Timer.After(0.1, function()
        exportFrame.editBox:SetFocus()
        exportFrame.editBox:HighlightText()
    end)
end

-- ============================================================
-- ShowGuildExportWindow
-- ============================================================

function SC:ShowGuildExportWindow(playerFilter, profFilter, recipeFilter)
    local csv, count = self:GenerateGuildCSV(playerFilter, profFilter, recipeFilter)
    if not csv or count == 0 then
        print("|cff00ccff[ShareCraft]|r " .. L.msg_no_guild_export)
        return
    end

    if not exportFrame then
        exportFrame = CreateExportWindow()
    end

    exportFrame.editBox:SetText(csv)
    exportFrame.editBox:SetWidth(exportFrame.scrollFrame:GetWidth())
    exportFrame.title:SetText(string.format(L.export_title_guild, count))

    exportFrame:Show()

    C_Timer.After(0.1, function()
        exportFrame.editBox:SetFocus()
        exportFrame.editBox:HighlightText()
    end)
end

-- ============================================================
-- Privacy Window
-- ============================================================

local function CreatePrivacyWindow()
    local f = CreateFrame("Frame", "ShareCraftPrivacyFrame", UIParent, "BackdropTemplate")
    f:SetSize(280, 200)
    f:SetPoint("CENTER")
    StyleFrame(f)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(20)

    -- Title
    f.title = CreateTitle(f, L.privacy_title)

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
    instructions:SetText(L.privacy_instructions)
    instructions:SetTextColor(unpack(COLOR_LABEL))

    -- Container for checkboxes
    local container = CreateFrame("Frame", nil, f)
    container:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -48)
    container:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 8)
    f.checkContainer = container

    f.checkboxes = {}

    tinsert(UISpecialFrames, "ShareCraftPrivacyFrame")

    f:Hide()
    return f
end

local function RefreshPrivacyWindow()
    if not privacyFrame then return end

    -- Clear existing checkboxes
    for _, cb in ipairs(privacyFrame.checkboxes) do
        cb:Hide()
    end
    privacyFrame.checkboxes = {}

    local professions = SC:GetMySharedProfessions()
    local charKey = SC:GetMyCharKey()

    if #professions == 0 then
        local noData = privacyFrame.checkContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        noData:SetPoint("TOPLEFT", privacyFrame.checkContainer, "TOPLEFT", 0, 0)
        noData:SetText(L.privacy_no_data)
        noData:SetTextColor(unpack(COLOR_LABEL))
        table.insert(privacyFrame.checkboxes, noData)
        return
    end

    -- Resize window based on profession count
    privacyFrame:SetHeight(80 + #professions * 26)

    for i, prof in ipairs(professions) do
        local cb = CreateFrame("CheckButton", "ShareCraftPrivacyCB" .. i, privacyFrame.checkContainer, "UICheckButtonTemplate")
        cb:SetSize(24, 24)
        cb:SetPoint("TOPLEFT", privacyFrame.checkContainer, "TOPLEFT", 0, -(i - 1) * 26)
        cb:SetChecked(prof.shared)

        local label = cb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        label:SetText(string.format(L.privacy_prof_fmt, prof.name, prof.recipeCount))
        label:SetTextColor(unpack(COLOR_TEXT))

        cb:SetScript("OnClick", function(self)
            local shared = self:GetChecked()
            SC:SetProfessionPrivacy(charKey, prof.name, shared)
            SC:UpdateMyCharacterData()

            if not shared then
                SC:SendPrivacy(charKey, prof.name, false)
            else
                SC:SendHello()
            end
        end)

        table.insert(privacyFrame.checkboxes, cb)
    end
end

-- ============================================================
-- Minimap Button
-- ============================================================

function SC:CreateMinimapButton()
    if self.minimapButton then return end

    local button = CreateFrame("Button", "ShareCraftMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:EnableMouse(true)
    button:SetMovable(true)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")

    -- Icon
    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(18, 18)
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -6)
    icon:SetTexture("Interface\\Icons\\Trade_BlackSmithing")

    -- Border overlay (texture is not centered, must anchor TOPLEFT)
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(56, 56)
    border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    -- Highlight
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetSize(18, 18)
    highlight:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -6)
    highlight:SetTexture("Interface\\Icons\\Trade_BlackSmithing")
    highlight:SetAlpha(0.3)

    -- Position helper
    local function UpdatePosition(angle)
        local radius = 80
        local rad = math.rad(angle)
        button:ClearAllPoints()
        button:SetPoint("CENTER", Minimap, "CENTER", math.cos(rad) * radius, math.sin(rad) * radius)
    end

    -- Initial position
    local savedAngle = SC.db.minimapAngle or 220
    UpdatePosition(savedAngle)

    -- Drag
    local isDragging = false

    button:SetScript("OnDragStart", function(self)
        isDragging = true
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            local angle = math.deg(math.atan2(cy - my, cx - mx))
            SC.db.minimapAngle = angle
            UpdatePosition(angle)
        end)
    end)

    button:SetScript("OnDragStop", function(self)
        isDragging = false
        self:SetScript("OnUpdate", nil)
    end)

    -- Click
    button:SetScript("OnClick", function()
        SC:ToggleMainWindow()
    end)

    -- Tooltip
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(L.tooltip_sharecraft)
        GameTooltip:AddLine(L.minimap_click, 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    self.minimapButton = button
end

function SC:TogglePrivacyWindow()
    if not privacyFrame then
        privacyFrame = CreatePrivacyWindow()
    end

    if privacyFrame:IsShown() then
        privacyFrame:Hide()
    else
        RefreshPrivacyWindow()
        privacyFrame:Show()
    end
end

-- ============================================================
-- GameTooltip: show guild crafters for hovered items
-- ============================================================

local craftersShown = {}

local function GetTooltipItemName(tooltip)
    -- Try GetItem first (works for item hyperlinks)
    local itemName = select(1, tooltip:GetItem())
    if itemName and itemName ~= "" then return itemName end

    -- Fallback: read the first line of the tooltip text
    -- Handles spell/enchant links (AtlasLoot, etc.) where GetItem() returns empty
    local ttName = tooltip:GetName()
    if ttName then
        local firstLine = _G[ttName .. "TextLeft1"]
        if firstLine then
            local text = firstLine:GetText()
            if text and text ~= "" then return text end
        end
    end

    return nil
end

local function AddCraftersToTooltip(tooltip)
    if craftersShown[tooltip] then return end

    local itemName = GetTooltipItemName(tooltip)
    if not itemName then return end

    local crafters = SC:FindCrafters(itemName)
    if not crafters then return end

    craftersShown[tooltip] = true

    tooltip:AddLine(" ")
    tooltip:AddLine("ShareCraft :", COLOR_ACCENT[1], COLOR_ACCENT[2], COLOR_ACCENT[3])
    for profName, players in pairs(crafters) do
        tooltip:AddLine("  " .. profName .. " : " .. table.concat(players, ", "), COLOR_LABEL[1], COLOR_LABEL[2], COLOR_LABEL[3])
    end
    tooltip:Show()
end

-- Hook tooltip methods that display items
local methodsToHook = {
    "SetBagItem", "SetInventoryItem", "SetHyperlink",
    "SetMerchantItem", "SetTradeSkillItem", "SetCraftItem",
    "SetLootItem", "SetQuestItem", "SetQuestLogItem",
    "SetAuctionItem", "SetAuctionSellItem",
    "SetItemByID",
}

local hookedTooltips = {}

local function HookTooltipFrame(tooltip)
    if not tooltip or hookedTooltips[tooltip] then return end
    hookedTooltips[tooltip] = true

    tooltip:HookScript("OnTooltipCleared", function(self)
        craftersShown[self] = nil
    end)

    for _, method in ipairs(methodsToHook) do
        if tooltip[method] then
            hooksecurefunc(tooltip, method, function(self)
                AddCraftersToTooltip(self)
            end)
        end
    end
end

-- Hook standard tooltips immediately
HookTooltipFrame(GameTooltip)
HookTooltipFrame(ItemRefTooltip)

-- Hook addon tooltips (AtlasLoot, etc.) once they're created
C_Timer.After(2, function()
    HookTooltipFrame(_G["AtlasLootTooltip"])
end)
