local addonName, SC = ...

-- Hidden tooltip for scanning
local scanTooltip = CreateFrame("GameTooltip", "ShareCraftScanTooltip", nil, "GameTooltipTemplate")
scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

function SC:ScanTradeSkill()
    local debugPrint = SC.debugPrint or function() end

    local skillName = GetTradeSkillLine()
    debugPrint("GetTradeSkillLine() =", tostring(skillName))

    if not skillName or skillName == "" or skillName == "UNKNOWN" then
        debugPrint("Abandon: skillName invalide")
        return
    end

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
    local currentCategory = "Autre"

    for i = 1, numSkills do
        local name, skillType = GetTradeSkillInfo(i)

        if skillType == "header" then
            currentCategory = name or "Autre"
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

    print(string.format("|cff00ccff[ShareCraft]|r %s : %d recettes scannees.", skillName, #recipes))
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

function SC:FillItemInfo(recipe, index)
    local itemLink = GetTradeSkillItemLink(index)

    recipe.itemLevel = 0
    recipe.requiredLevel = 0
    recipe.stats = {
        armor = 0,
        strength = 0,
        agility = 0,
        stamina = 0,
        intellect = 0,
        spirit = 0,
    }

    if not itemLink then
        return
    end

    -- Get ilvl and required level from GetItemInfo
    local _, _, _, itemLevel, itemMinLevel = GetItemInfo(itemLink)
    recipe.itemLevel = itemLevel or 0
    recipe.requiredLevel = itemMinLevel or 0

    -- Parse stats from tooltip
    scanTooltip:ClearLines()
    scanTooltip:SetHyperlink(itemLink)

    local numLines = scanTooltip:NumLines()
    for i = 2, numLines do
        local textLeft = _G["ShareCraftScanTooltipTextLeft" .. i]
        if textLeft then
            local text = textLeft:GetText()
            if text then
                SC:ParseStatLine(recipe.stats, text)
            end
        end
    end
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
    local currentCategory = "Autre"

    for i = 1, numCrafts do
        local name, _, skillType = GetCraftInfo(i)

        if skillType == "header" then
            currentCategory = name or "Autre"
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

    print(string.format("|cff00ccff[ShareCraft]|r %s : %d recettes scannees.", skillName, #recipes))
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
    recipe.stats = {
        armor = 0,
        strength = 0,
        agility = 0,
        stamina = 0,
        intellect = 0,
        spirit = 0,
    }

    if not itemLink then
        return
    end

    local _, _, _, itemLevel, itemMinLevel = GetItemInfo(itemLink)
    recipe.itemLevel = itemLevel or 0
    recipe.requiredLevel = itemMinLevel or 0

    scanTooltip:ClearLines()
    scanTooltip:SetHyperlink(itemLink)

    local numLines = scanTooltip:NumLines()
    for i = 2, numLines do
        local textLeft = _G["ShareCraftScanTooltipTextLeft" .. i]
        if textLeft then
            local text = textLeft:GetText()
            if text then
                SC:ParseStatLine(recipe.stats, text)
            end
        end
    end
end

function SC:ParseStatLine(stats, text)
    -- Armor: "250 Armure" or "250 points d'armure"
    local armor = text:match("^(%d+) [Aa]rmure")
    if not armor then
        armor = text:match("^(%d+) points d'armure")
    end
    if armor then
        stats.armor = tonumber(armor) or 0
        return
    end

    -- Primary stats: "+12 Endurance", "+8 Agilité", etc.
    local value, statName = text:match("^%+(%d+) (.+)$")
    if not value then
        -- Try without + prefix: "12 Endurance"
        value, statName = text:match("^(%d+) (.+)$")
    end

    if value and statName then
        statName = statName:lower()

        if statName:find("force") then
            stats.strength = tonumber(value) or 0
        elseif statName:find("agilit") then
            stats.agility = tonumber(value) or 0
        elseif statName:find("endurance") then
            stats.stamina = tonumber(value) or 0
        elseif statName:find("intelligence") or statName:find("intellect") then
            stats.intellect = tonumber(value) or 0
        elseif statName:find("esprit") or statName:find("spirit") then
            stats.spirit = tonumber(value) or 0
        end
    end
end
