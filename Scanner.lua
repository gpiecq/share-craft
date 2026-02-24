local addonName, SC = ...
local L = SC.L

-- Hidden tooltip for scanning
local scanTooltip = CreateFrame("GameTooltip", "ShareCraftScanTooltip", nil, "GameTooltipTemplate")
scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

-- Compute a hash of current recipe names for change detection
local function GetCurrentRecipeHash(skillName)
    if not SC.db or not SC.db[skillName] or not SC.db[skillName].recipes then
        return nil
    end
    local names = {}
    for _, recipe in ipairs(SC.db[skillName].recipes) do
        if recipe.name then
            table.insert(names, recipe.name)
        end
    end
    if #names == 0 then return nil end
    return SC:HashRecipes(names)
end

-- After a scan, detect changes and sync guild if needed
local function SyncGuildIfChanged(skillName, oldHash, newRecipeCount)
    if not SC.guildDB then return end

    local newHash = GetCurrentRecipeHash(skillName)
    if oldHash ~= newHash then
        local msg = string.format(L.scan_recipes, newRecipeCount)
        if oldHash then
            msg = L.scan_new_recipes
        end
        print(string.format("|cff00ccff[ShareCraft]|r " .. L.scan_sync_msg, skillName, msg))
        SC:UpdateMyCharacterData()
        SC:SendHello()
    else
        SC.debugPrint(string.format(L.scan_no_change, skillName))
    end
end

function SC:ScanTradeSkill()
    local debugPrint = SC.debugPrint or function() end

    local skillName = GetTradeSkillLine()
    debugPrint("GetTradeSkillLine() =", tostring(skillName))

    if not skillName or skillName == "" or skillName == "UNKNOWN" then
        debugPrint("Abandon: skillName invalide")
        return
    end

    -- Hash before scan for change detection
    local oldHash = GetCurrentRecipeHash(skillName)

    local numSkills = GetNumTradeSkills()
    debugPrint("GetNumTradeSkills() =", tostring(numSkills))

    if not numSkills or numSkills == 0 then
        debugPrint("Abandon: numSkills = 0")
        return
    end

    -- Expand all headers bottom-to-top to avoid index shifting
    for i = numSkills, 1, -1 do
        local name, skillType = GetTradeSkillInfo(i)
        if skillType == "header" then
            ExpandTradeSkillSubClass(i)
        end
    end

    -- Re-read after expansion
    numSkills = GetNumTradeSkills()
    debugPrint("Apres expansion: numSkills =", tostring(numSkills))

    local recipes = {}
    local categories = {}
    local currentCategory = L.label_other

    for i = 1, numSkills do
        local name, skillType = GetTradeSkillInfo(i)

        if skillType == "header" then
            currentCategory = name or L.label_other
            categories[currentCategory] = true
            debugPrint(string.format("  Header: '%s'", currentCategory))
        elseif name then
            local recipe = {
                name = name,
                category = currentCategory,
                difficulty = skillType,
                spellID = SC:GetSpellID(i),
                reagents = SC:GetReagentsList(i),
                reagentsText = SC:GetReagentsString(i),
            }

            -- Get item info (ilvl, required level, stats)
            SC:FillItemInfo(recipe, i)

            table.insert(recipes, recipe)
        end
    end

    -- Build sorted category list
    local categoryList = {}
    for cat in pairs(categories) do
        table.insert(categoryList, cat)
    end
    table.sort(categoryList)

    -- Store in saved variables
    if not self.db then
        self.db = ShareCraftDB or {}
        ShareCraftDB = self.db
    end

    self.db[skillName] = {
        recipes = recipes,
        categories = categoryList,
        scanTime = time(),
        playerName = UnitName("player"),
    }

    print(string.format("|cff00ccff[ShareCraft]|r " .. L.scan_recipes_count, skillName, #recipes))

    -- Sync guild only if recipes changed
    SyncGuildIfChanged(skillName, oldHash, #recipes)
end

function SC:GetReagentsList(index)
    local list = {}
    local numReagents = GetTradeSkillNumReagents(index)

    for i = 1, numReagents do
        local reagentName, reagentTexture, reagentCount, playerReagentCount = GetTradeSkillReagentInfo(index, i)
        if reagentName then
            table.insert(list, {
                name = reagentName,
                count = reagentCount or 1,
            })
        end
    end

    return list
end

function SC:GetReagentsString(index)
    local parts = {}
    local numReagents = GetTradeSkillNumReagents(index)

    for i = 1, numReagents do
        local reagentName, reagentTexture, reagentCount, playerReagentCount = GetTradeSkillReagentInfo(index, i)
        if reagentName then
            if reagentCount and reagentCount > 1 then
                table.insert(parts, reagentName .. " x" .. reagentCount)
            else
                table.insert(parts, reagentName)
            end
        end
    end

    return table.concat(parts, ", ")
end

function SC:GetSpellID(index)
    local link = GetTradeSkillRecipeLink(index)
    if not link then
        return nil
    end

    local spellID = link:match("|Henchant:(%d+)|h")
    if not spellID then
        spellID = link:match("|Hspell:(%d+)|h")
    end

    return spellID and tonumber(spellID) or nil
end

-- Detect green tooltip lines by text pattern (locale-aware)
local function IsGreenLine(text)
    for _, pattern in ipairs(L.green_patterns) do
        if text:find(pattern) then return true end
    end
    return false
end

-- Parse a tooltip into stats and green lines
local function ParseTooltipLines(recipe)
    local numLines = scanTooltip:NumLines()
    for i = 2, numLines do
        local textLeft = _G["ShareCraftScanTooltipTextLeft" .. i]
        if textLeft then
            local text = textLeft:GetText()
            if text then
                SC:ParseStatLine(recipe.stats, text)
                if IsGreenLine(text) then
                    table.insert(recipe.greenLines, text)
                end
            end
        end
    end
end

function SC:FillItemInfo(recipe, index)
    local itemLink = GetTradeSkillItemLink(index)

    recipe.itemLevel = 0
    recipe.requiredLevel = 0
    recipe.quality = 1
    recipe.stats = {
        armor = 0,
        strength = 0,
        agility = 0,
        stamina = 0,
        intellect = 0,
        spirit = 0,
    }
    recipe.greenLines = {}

    if not itemLink then
        -- Enchanting: no item produced, scan spell tooltip for description
        local recipeLink = GetTradeSkillRecipeLink(index)
        if recipeLink then
            scanTooltip:ClearLines()
            scanTooltip:SetHyperlink(recipeLink)
            ParseTooltipLines(recipe)
        end
        return
    end

    -- Extract itemID from link for cross-locale tooltip matching
    local itemID = tonumber(itemLink:match("item:(%d+)"))
    if itemID then
        recipe.itemID = itemID
    end

    local itemName, _, itemQuality, itemLevel, itemMinLevel = GetItemInfo(itemLink)
    recipe.quality = itemQuality or 1
    recipe.itemLevel = itemLevel or 0
    recipe.requiredLevel = itemMinLevel or 0
    if itemName and itemName ~= recipe.name then
        recipe.itemName = itemName
    end

    scanTooltip:ClearLines()
    scanTooltip:SetHyperlink(itemLink)
    ParseTooltipLines(recipe)
end

-- ============================================================
-- Craft API scanner (Enchanting in TBC)
-- ============================================================

function SC:ScanCraft()
    local debugPrint = SC.debugPrint or function() end

    local skillName = GetCraftDisplaySkillLine()
    debugPrint("GetCraftDisplaySkillLine() =", tostring(skillName))

    if not skillName or skillName == "" then
        debugPrint("Abandon: craft skillName invalide")
        return
    end

    -- Hash before scan for change detection
    local oldHash = GetCurrentRecipeHash(skillName)

    local numCrafts = GetNumCrafts()
    debugPrint("GetNumCrafts() =", tostring(numCrafts))

    if not numCrafts or numCrafts == 0 then
        debugPrint("Abandon: numCrafts = 0")
        return
    end

    -- Expand all headers bottom-to-top
    for i = numCrafts, 1, -1 do
        local name, _, skillType = GetCraftInfo(i)
        if skillType == "header" then
            ExpandCraftSkillLine(i)
        end
    end

    numCrafts = GetNumCrafts()
    debugPrint("Apres expansion: numCrafts =", tostring(numCrafts))

    local recipes = {}
    local categories = {}
    local currentCategory = L.label_other

    for i = 1, numCrafts do
        local name, _, skillType = GetCraftInfo(i)

        if skillType == "header" then
            currentCategory = name or L.label_other
            categories[currentCategory] = true
            debugPrint(string.format("  Header: '%s'", currentCategory))
        elseif name then
            local recipe = {
                name = name,
                category = currentCategory,
                difficulty = skillType,
                spellID = SC:GetCraftSpellID(i),
                reagents = SC:GetCraftReagentsList(i),
                reagentsText = SC:GetCraftReagentsString(i),
            }

            SC:FillCraftItemInfo(recipe, i)

            table.insert(recipes, recipe)
        end
    end

    local categoryList = {}
    for cat in pairs(categories) do
        table.insert(categoryList, cat)
    end
    table.sort(categoryList)

    if not self.db then
        self.db = ShareCraftDB or {}
        ShareCraftDB = self.db
    end

    self.db[skillName] = {
        recipes = recipes,
        categories = categoryList,
        scanTime = time(),
        playerName = UnitName("player"),
    }

    print(string.format("|cff00ccff[ShareCraft]|r " .. L.scan_recipes_count, skillName, #recipes))

    -- Sync guild only if recipes changed
    SyncGuildIfChanged(skillName, oldHash, #recipes)
end

function SC:GetCraftReagentsList(index)
    local list = {}
    local numReagents = GetCraftNumReagents(index)

    for i = 1, numReagents do
        local reagentName, reagentTexture, reagentCount, playerReagentCount = GetCraftReagentInfo(index, i)
        if reagentName then
            table.insert(list, {
                name = reagentName,
                count = reagentCount or 1,
            })
        end
    end

    return list
end

function SC:GetCraftReagentsString(index)
    local parts = {}
    local numReagents = GetCraftNumReagents(index)

    for i = 1, numReagents do
        local reagentName, reagentTexture, reagentCount, playerReagentCount = GetCraftReagentInfo(index, i)
        if reagentName then
            if reagentCount and reagentCount > 1 then
                table.insert(parts, reagentName .. " x" .. reagentCount)
            else
                table.insert(parts, reagentName)
            end
        end
    end

    return table.concat(parts, ", ")
end

function SC:GetCraftSpellID(index)
    local link = GetCraftRecipeLink(index)
    if not link then
        return nil
    end

    local spellID = link:match("|Henchant:(%d+)|h")
    if not spellID then
        spellID = link:match("|Hspell:(%d+)|h")
    end

    return spellID and tonumber(spellID) or nil
end

function SC:FillCraftItemInfo(recipe, index)
    local itemLink = GetCraftItemLink(index)

    recipe.itemLevel = 0
    recipe.requiredLevel = 0
    recipe.quality = 1
    recipe.stats = {
        armor = 0,
        strength = 0,
        agility = 0,
        stamina = 0,
        intellect = 0,
        spirit = 0,
    }
    recipe.greenLines = {}

    if not itemLink then
        -- Enchanting: no item produced, get spell description instead
        local desc = GetCraftDescription(index)
        if desc and desc ~= "" then
            desc = desc:gsub("\r\n", " "):gsub("\n", " "):gsub("%s+", " ")
            table.insert(recipe.greenLines, strtrim(desc))
        end
        return
    end

    local itemID = tonumber(itemLink:match("item:(%d+)"))
    if itemID then
        recipe.itemID = itemID
    end

    local itemName, _, itemQuality, itemLevel, itemMinLevel = GetItemInfo(itemLink)
    recipe.quality = itemQuality or 1
    recipe.itemLevel = itemLevel or 0
    recipe.requiredLevel = itemMinLevel or 0
    if itemName and itemName ~= recipe.name then
        recipe.itemName = itemName
    end

    scanTooltip:ClearLines()
    scanTooltip:SetHyperlink(itemLink)
    ParseTooltipLines(recipe)

    -- Enchanting fallback: if no green lines from item tooltip, try GetCraftDescription
    if #recipe.greenLines == 0 then
        local desc = GetCraftDescription(index)
        if desc and desc ~= "" then
            desc = desc:gsub("\r\n", " "):gsub("\n", " "):gsub("%s+", " ")
            table.insert(recipe.greenLines, strtrim(desc))
        end
    end
end

function SC:ParseStatLine(stats, text)
    -- Armor (locale-aware patterns)
    for _, pattern in ipairs(L.stat_armor_patterns) do
        local armor = text:match(pattern)
        if armor then
            stats.armor = tonumber(armor) or 0
            return
        end
    end

    -- Primary stats: "+12 Stamina", "+8 Agility", etc.
    local value, statName = text:match("^%+(%d+) (.+)$")
    if not value then
        -- Try without + prefix: "12 Stamina"
        value, statName = text:match("^(%d+) (.+)$")
    end

    if value and statName then
        statName = statName:lower()
        for _, entry in ipairs(L.stat_names) do
            if statName:find(entry.pattern) then
                stats[entry.key] = tonumber(value) or 0
                return
            end
        end
    end
end
