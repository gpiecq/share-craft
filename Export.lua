local addonName, SC = ...

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
        "Nom du joueur",
        "Metier",
        "Categorie",
        "Nom de la recette",
        "Difficulte",
        "Niveau objet",
        "Niveau requis",
        "Armure",
        "Force",
        "Agilite",
        "Endurance",
        "Intelligence",
        "Esprit",
        "Reagent",
        "Quantite",
        "Lien Wowhead",
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
