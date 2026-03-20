local addonName, SC = ...
local L = SC.L

-- Escape a value for CSV (semicolon-separated)
local function csvEscape(value)
    if not value then
        return ""
    end
    value = tostring(value)
    if value:find('[;"\n\r]') then
        value = '"' .. value:gsub('"', '""') .. '"'
    end
    return value
end

function SC:GenerateCSV(professionName, categoryFilter)
    local data = self.db and self.db[professionName]
    if not data or not data.recipes then
        return nil
    end

    local playerName = data.playerName or UnitName("player")
    local lines = {}

    -- Header row
    table.insert(lines, table.concat({
        L.csv_player,
        L.csv_profession,
        L.csv_category,
        L.csv_recipe_name,
        L.csv_difficulty,
        L.csv_item_level,
        L.csv_required_level,
        L.csv_armor,
        L.csv_strength,
        L.csv_agility,
        L.csv_stamina,
        L.csv_intellect,
        L.csv_spirit,
        L.csv_reagent,
        L.csv_quantity,
        L.csv_wowhead,
    }, ";"))

    local recipeCount = 0

    for _, recipe in ipairs(data.recipes) do
        if categoryFilter == "All" or recipe.category == categoryFilter then
            recipeCount = recipeCount + 1

            local wowheadURL = ""
            if recipe.spellID then
                wowheadURL = SC.WOWHEAD_BASE .. recipe.spellID
            end

            local stats = recipe.stats or {}

            -- One row per reagent
            local reagents = recipe.reagents
            if not reagents or #reagents == 0 then
                -- Recipe with no reagents (rare), still output one line
                local line = table.concat({
                    csvEscape(playerName),
                    csvEscape(professionName),
                    csvEscape(recipe.category),
                    csvEscape(recipe.name),
                    csvEscape(recipe.difficulty or ""),
                    csvEscape(recipe.itemLevel or 0),
                    csvEscape(recipe.requiredLevel or 0),
                    csvEscape(stats.armor or 0),
                    csvEscape(stats.strength or 0),
                    csvEscape(stats.agility or 0),
                    csvEscape(stats.stamina or 0),
                    csvEscape(stats.intellect or 0),
                    csvEscape(stats.spirit or 0),
                    csvEscape(""),
                    csvEscape(""),
                    csvEscape(wowheadURL),
                }, ";")
                table.insert(lines, line)
            else
                for _, reagent in ipairs(reagents) do
                    local line = table.concat({
                        csvEscape(playerName),
                        csvEscape(professionName),
                        csvEscape(recipe.category),
                        csvEscape(recipe.name),
                        csvEscape(recipe.difficulty or ""),
                        csvEscape(recipe.itemLevel or 0),
                        csvEscape(recipe.requiredLevel or 0),
                        csvEscape(stats.armor or 0),
                        csvEscape(stats.strength or 0),
                        csvEscape(stats.agility or 0),
                        csvEscape(stats.stamina or 0),
                        csvEscape(stats.intellect or 0),
                        csvEscape(stats.spirit or 0),
                        csvEscape(reagent.name),
                        csvEscape(reagent.count),
                        csvEscape(wowheadURL),
                    }, ";")
                    table.insert(lines, line)
                end
            end
        end
    end

    return table.concat(lines, "\n"), recipeCount
end

function SC:CountRecipes(professionName, categoryFilter)
    local data = self.db and self.db[professionName]
    if not data or not data.recipes then
        return 0
    end

    if categoryFilter == "All" then
        return #data.recipes
    end

    local count = 0
    for _, recipe in ipairs(data.recipes) do
        if recipe.category == categoryFilter then
            count = count + 1
        end
    end
    return count
end

-- ============================================================
-- Guild CSV Export
-- ============================================================

-- Find recipe details from local ShareCraftDB (cross-locale aware)
local function FindLocalRecipe(recipeName, professionName)
    if not SC.db then return nil end
    -- Search in matching profession first (cross-locale)
    if professionName then
        for profName, profData in pairs(SC.db) do
            if type(profData) == "table" and profData.recipes
                and SC:SameProfession(profName, professionName) then
                for _, recipe in ipairs(profData.recipes) do
                    if recipe.name == recipeName then
                        return recipe
                    end
                end
            end
        end
    end
    -- Fallback: search all professions
    for profName, profData in pairs(SC.db) do
        if type(profData) == "table" and profData.recipes then
            for _, recipe in ipairs(profData.recipes) do
                if recipe.name == recipeName then
                    return recipe
                end
            end
        end
    end
    return nil
end

function SC:GenerateGuildCSV(playerFilter, profFilter, recipeFilter)
    local results, totalRecipes, playerCount = SC:SearchGuild(playerFilter, profFilter, recipeFilter)

    if totalRecipes == 0 then
        return nil, 0
    end

    local lines = {}

    -- Header row (same as personal export + last scan)
    table.insert(lines, table.concat({
        L.csv_player,
        L.csv_profession,
        L.csv_category,
        L.csv_recipe_name,
        L.csv_difficulty,
        L.csv_item_level,
        L.csv_required_level,
        L.csv_armor,
        L.csv_strength,
        L.csv_agility,
        L.csv_stamina,
        L.csv_intellect,
        L.csv_spirit,
        L.csv_reagent,
        L.csv_quantity,
        L.csv_wowhead,
        L.csv_last_scan,
    }, ";"))

    local recipeCount = 0

    for _, entry in ipairs(results) do
        local scanDate = ""
        if entry.scanTime then
            scanDate = date("%d/%m/%Y", entry.scanTime)
        end
        local localProfName = SC:GetLocalProfName(entry.profession)

        for _, recipeEntry in ipairs(entry.recipes) do
            local recipeName = type(recipeEntry) == "table" and recipeEntry.name or recipeEntry
            recipeCount = recipeCount + 1

            -- Use local data if available (richer), fall back to synced data
            local localRecipe = FindLocalRecipe(recipeName, entry.profession)
            local recipe = localRecipe or (type(recipeEntry) == "table" and recipeEntry or nil)
            local stats = recipe and recipe.stats or {}
            local wowheadURL = ""
            if recipe and recipe.spellID then
                wowheadURL = SC.WOWHEAD_BASE .. recipe.spellID
            end

            local reagents = recipe and recipe.reagents
            if not reagents or #reagents == 0 then
                local line = table.concat({
                    csvEscape(entry.charKey),
                    csvEscape(localProfName),
                    csvEscape(recipe and recipe.category or ""),
                    csvEscape(recipeName),
                    csvEscape(recipe and recipe.difficulty or ""),
                    csvEscape(recipe and recipe.itemLevel or 0),
                    csvEscape(recipe and recipe.requiredLevel or 0),
                    csvEscape(stats.armor or 0),
                    csvEscape(stats.strength or 0),
                    csvEscape(stats.agility or 0),
                    csvEscape(stats.stamina or 0),
                    csvEscape(stats.intellect or 0),
                    csvEscape(stats.spirit or 0),
                    csvEscape(""),
                    csvEscape(""),
                    csvEscape(wowheadURL),
                    csvEscape(scanDate),
                }, ";")
                table.insert(lines, line)
            else
                for _, reagent in ipairs(reagents) do
                    local line = table.concat({
                        csvEscape(entry.charKey),
                        csvEscape(localProfName),
                        csvEscape(recipe.category or ""),
                        csvEscape(recipeName),
                        csvEscape(recipe.difficulty or ""),
                        csvEscape(recipe.itemLevel or 0),
                        csvEscape(recipe.requiredLevel or 0),
                        csvEscape(stats.armor or 0),
                        csvEscape(stats.strength or 0),
                        csvEscape(stats.agility or 0),
                        csvEscape(stats.stamina or 0),
                        csvEscape(stats.intellect or 0),
                        csvEscape(stats.spirit or 0),
                        csvEscape(reagent.name),
                        csvEscape(reagent.count),
                        csvEscape(wowheadURL),
                        csvEscape(scanDate),
                    }, ";")
                    table.insert(lines, line)
                end
            end
        end
    end

    return table.concat(lines, "\n"), recipeCount
end
