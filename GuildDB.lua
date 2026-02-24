local addonName, SC = ...

-- ============================================================
-- Guild Database Management
-- ============================================================

function SC:InitGuildDB()
    ShareCraftGuildDB = ShareCraftGuildDB or {}
    -- Migration: clear old format data (v2 stored recipe names as strings)
    if (ShareCraftGuildDB.dataVersion or 0) < 3 then
        ShareCraftGuildDB.members = {}
        ShareCraftGuildDB.dataVersion = 3
    end
    ShareCraftGuildDB.privacy = ShareCraftGuildDB.privacy or {}
    ShareCraftGuildDB.members = ShareCraftGuildDB.members or {}
    SC.guildDB = ShareCraftGuildDB
end

function SC:GetMyCharKey()
    local name = UnitName("player")
    local realm = GetRealmName()
    if name and realm then
        return name .. "-" .. realm
    end
    return nil
end

-- Returns the current guild name, or nil if not in a guild
function SC:GetMyGuildName()
    if not IsInGuild() then return nil end
    local guildName = GetGuildInfo("player")
    return guildName
end

-- Returns the members table for the current guild (creates it if needed)
-- All member access goes through this to scope data per guild
function SC:GetGuildMembers()
    if not SC.guildDB then return nil end
    local guildName = SC:GetMyGuildName()
    if not guildName then return nil end
    SC.guildDB.members[guildName] = SC.guildDB.members[guildName] or {}
    return SC.guildDB.members[guildName]
end

function SC:UpdateMyCharacterData()
    if not SC.guildDB or not SC.db then return end

    local charKey = SC:GetMyCharKey()
    if not charKey then return end

    local guildMembers = SC:GetGuildMembers()
    if not guildMembers then return end

    local memberData = { professions = {}, lastSync = time() }

    for profName, profData in pairs(SC.db) do
        if type(profData) == "table" and profData.recipes then
            if SC:IsProfessionShared(charKey, profName) then
                local recipeList = {}
                for _, recipe in ipairs(profData.recipes) do
                    if recipe.name then
                        table.insert(recipeList, {
                            name = recipe.name,
                            itemName = recipe.itemName,
                            itemID = recipe.itemID,
                            quality = recipe.quality,
                            category = recipe.category,
                            itemLevel = recipe.itemLevel,
                            requiredLevel = recipe.requiredLevel,
                            difficulty = recipe.difficulty,
                            spellID = recipe.spellID,
                            stats = recipe.stats,
                            reagents = recipe.reagents,
                            greenLines = recipe.greenLines,
                        })
                    end
                end
                table.sort(recipeList, function(a, b) return a.name < b.name end)

                memberData.professions[profName] = {
                    recipes = recipeList,
                    scanTime = profData.scanTime or time(),
                }
            end
        end
    end

    guildMembers[charKey] = memberData
end

-- ============================================================
-- Privacy
-- ============================================================

function SC:IsProfessionShared(charKey, profName)
    if not SC.guildDB or not SC.guildDB.privacy then return true end
    local charPrivacy = SC.guildDB.privacy[charKey]
    if not charPrivacy then return true end
    if charPrivacy[profName] == false then return false end
    return true
end

function SC:SetProfessionPrivacy(charKey, profName, shared)
    if not SC.guildDB then return end
    SC.guildDB.privacy[charKey] = SC.guildDB.privacy[charKey] or {}
    if shared then
        SC.guildDB.privacy[charKey][profName] = nil  -- default is shared
    else
        SC.guildDB.privacy[charKey][profName] = false
    end
end

function SC:GetMySharedProfessions()
    local charKey = SC:GetMyCharKey()
    if not charKey or not SC.db then return {} end

    local professions = {}
    for profName, profData in pairs(SC.db) do
        if type(profData) == "table" and profData.recipes then
            table.insert(professions, {
                name = profName,
                shared = SC:IsProfessionShared(charKey, profName),
                recipeCount = #profData.recipes,
            })
        end
    end
    table.sort(professions, function(a, b) return a.name < b.name end)
    return professions
end

-- ============================================================
-- Member Data Access
-- ============================================================

function SC:GetMemberData(charKey)
    local guildMembers = SC:GetGuildMembers()
    if not guildMembers then return nil end
    return guildMembers[charKey]
end

function SC:SetMemberData(charKey, profName, recipes, scanTime)
    local guildMembers = SC:GetGuildMembers()
    if not guildMembers then return end
    guildMembers[charKey] = guildMembers[charKey] or { professions = {}, lastSync = time() }
    guildMembers[charKey].professions[profName] = {
        recipes = recipes,
        scanTime = scanTime or time(),
    }
    guildMembers[charKey].lastSync = time()
end

function SC:RemoveMemberProfession(charKey, profName)
    local guildMembers = SC:GetGuildMembers()
    if not guildMembers then return end
    local member = guildMembers[charKey]
    if member and member.professions then
        member.professions[profName] = nil
    end
end

function SC:GetAllMembers()
    local guildMembers = SC:GetGuildMembers()
    if not guildMembers then return {} end
    local members = {}
    for charKey, data in pairs(guildMembers) do
        table.insert(members, { charKey = charKey, data = data })
    end
    table.sort(members, function(a, b) return a.charKey < b.charKey end)
    return members
end

-- ============================================================
-- Hashing (DJB2)
-- ============================================================

function SC:HashRecipes(recipes)
    local sorted = {}
    for i, entry in ipairs(recipes) do
        if type(entry) == "table" then
            sorted[i] = entry.name
        else
            sorted[i] = entry
        end
    end
    table.sort(sorted)

    local hash = 5381
    local str = table.concat(sorted, ",")
    for i = 1, #str do
        hash = ((hash * 33) + string.byte(str, i)) % 2147483647
    end
    return tostring(hash)
end

function SC:GetMyHashes()
    local charKey = SC:GetMyCharKey()
    if not charKey then return {} end

    local guildMembers = SC:GetGuildMembers()
    if not guildMembers then return {} end

    local member = guildMembers[charKey]
    if not member or not member.professions then return {} end

    local hashes = {}
    for profName, profData in pairs(member.professions) do
        if SC:IsProfessionShared(charKey, profName) and profData.recipes then
            hashes[profName] = SC:HashRecipes(profData.recipes)
        end
    end
    return hashes
end

-- Returns hashes for ALL known guild members (for relay)
-- Result: { ["CharKey"] = { ["ProfName"] = "hash", ... }, ... }
function SC:GetAllGuildHashes()
    local guildMembers = SC:GetGuildMembers()
    if not guildMembers then return {} end

    local myKey = SC:GetMyCharKey()
    local allHashes = {}

    for charKey, member in pairs(guildMembers) do
        if member.professions then
            local hashes = {}
            for profName, profData in pairs(member.professions) do
                if profData.recipes then
                    -- For our own data, respect privacy settings
                    if charKey == myKey then
                        if SC:IsProfessionShared(charKey, profName) then
                            hashes[profName] = SC:HashRecipes(profData.recipes)
                        end
                    else
                        hashes[profName] = SC:HashRecipes(profData.recipes)
                    end
                end
            end
            if next(hashes) then
                allHashes[charKey] = hashes
            end
        end
    end

    return allHashes
end

-- ============================================================
-- Tooltip: find crafters for an item
-- ============================================================

-- Strip common prepositions that vary between recipe/item names (multi-locale)
local function NormalizeName(name)
    local s = name:lower()
    -- French
    s = s:gsub(" en ", " "):gsub(" de ", " "):gsub(" du ", " "):gsub(" des ", " "):gsub(" d'", " ")
    -- English
    s = s:gsub(" of ", " "):gsub(" the ", " "):gsub(" a ", " ")
    -- German
    s = s:gsub(" der ", " "):gsub(" die ", " "):gsub(" das ", " "):gsub(" des ", " "):gsub(" dem ", " ")
    -- Spanish
    s = s:gsub(" de ", " "):gsub(" del ", " "):gsub(" la ", " "):gsub(" el ", " ")
    return s
end

function SC:FindCrafters(itemName)
    local guildMembers = SC:GetGuildMembers()
    if not guildMembers or not itemName or itemName == "" then return nil end

    -- Extract itemID from tooltip link if available (for cross-locale matching)
    local tooltipItemID = nil
    local _, itemLink = GameTooltip:GetItem()
    if itemLink then
        tooltipItemID = tonumber(itemLink:match("item:(%d+)"))
    end

    local itemLower = itemName:lower()
    local itemNorm = NormalizeName(itemName)
    local result = {}

    for charKey, member in pairs(guildMembers) do
        if member.professions then
            for profName, profData in pairs(member.professions) do
                if profData.recipes then
                    for _, recipe in ipairs(profData.recipes) do
                        local matched = false
                        local recipeData = type(recipe) == "table" and recipe or nil

                        -- 1. Match by itemID (cross-locale safe)
                        if tooltipItemID and recipeData and recipeData.itemID == tooltipItemID then
                            matched = true
                        else
                            local recipeName = recipeData and recipeData.name or recipe
                            local recipeItemName = recipeData and recipeData.itemName or nil

                            -- 2. Exact match on recipe name or item name
                            if (recipeName and recipeName:lower() == itemLower)
                                or (recipeItemName and recipeItemName:lower() == itemLower) then
                                matched = true
                            -- 3. Normalized match (handles preposition differences)
                            elseif recipeName then
                                if NormalizeName(recipeName) == itemNorm then
                                    matched = true
                                end
                            end
                        end

                        if matched then
                            if not result[profName] then
                                result[profName] = {}
                            end
                            table.insert(result[profName], charKey)
                            break
                        end
                    end
                end
            end
        end
    end

    -- Sort player names alphabetically within each profession
    for _, players in pairs(result) do
        table.sort(players)
    end

    if not next(result) then return nil end
    return result
end

-- ============================================================
-- Search
-- ============================================================

function SC:SearchByRecipe(query)
    local results = {}
    local guildMembers = SC:GetGuildMembers()
    if not guildMembers or not query or query == "" then
        return results
    end

    query = query:lower()

    for charKey, member in pairs(guildMembers) do
        if member.professions then
            for profName, profData in pairs(member.professions) do
                if profData.recipes then
                    for _, recipe in ipairs(profData.recipes) do
                        local recipeName = type(recipe) == "table" and recipe.name or recipe
                        if recipeName:lower():find(query, 1, true) then
                            table.insert(results, {
                                charKey = charKey,
                                profession = profName,
                                recipe = recipeName,
                                scanTime = profData.scanTime,
                            })
                        end
                    end
                end
            end
        end
    end

    table.sort(results, function(a, b)
        if a.charKey ~= b.charKey then return a.charKey < b.charKey end
        if a.profession ~= b.profession then return a.profession < b.profession end
        return a.recipe < b.recipe
    end)

    return results
end

function SC:SearchByPlayer(charKey)
    local results = {}
    local member = SC:GetMemberData(charKey)
    if not member or not member.professions then return results end

    for profName, profData in pairs(member.professions) do
        if profData.recipes then
            table.insert(results, {
                profession = profName,
                recipes = profData.recipes,
                scanTime = profData.scanTime,
            })
        end
    end

    table.sort(results, function(a, b) return a.profession < b.profession end)
    return results
end

-- ============================================================
-- Filtered search for guild tab
-- ============================================================

function SC:SearchGuild(playerFilter, profFilter, recipeFilter)
    local results = {}
    local guildMembers = SC:GetGuildMembers()
    if not guildMembers then return results, 0, 0 end

    local totalRecipes = 0
    local playersFound = {}

    for charKey, member in pairs(guildMembers) do
        if playerFilter == "All" or charKey == playerFilter then
            if member.professions then
                for profName, profData in pairs(member.professions) do
                    if profFilter == "All" or profName == profFilter then
                        if profData.recipes then
                            local matchingRecipes = {}
                            for _, recipe in ipairs(profData.recipes) do
                                local recipeName = type(recipe) == "table" and recipe.name or recipe
                                if not recipeFilter or recipeFilter == "" or recipeName:lower():find(recipeFilter:lower(), 1, true) then
                                    table.insert(matchingRecipes, recipe)
                                    totalRecipes = totalRecipes + 1
                                end
                            end

                            if #matchingRecipes > 0 then
                                playersFound[charKey] = true
                                table.insert(results, {
                                    charKey = charKey,
                                    profession = profName,
                                    recipes = matchingRecipes,
                                    scanTime = profData.scanTime,
                                })
                            end
                        end
                    end
                end
            end
        end
    end

    table.sort(results, function(a, b)
        if a.charKey ~= b.charKey then return a.charKey < b.charKey end
        return a.profession < b.profession
    end)

    local playerCount = 0
    for _ in pairs(playersFound) do
        playerCount = playerCount + 1
    end

    return results, totalRecipes, playerCount
end

-- ============================================================
-- Helpers for UI dropdowns
-- ============================================================

function SC:GetGuildPlayers()
    local players = {}
    local guildMembers = SC:GetGuildMembers()
    if not guildMembers then return players end
    for charKey in pairs(guildMembers) do
        table.insert(players, charKey)
    end
    table.sort(players)
    return players
end

function SC:GetGuildProfessions()
    local profSet = {}
    local guildMembers = SC:GetGuildMembers()
    if not guildMembers then return {} end
    for _, member in pairs(guildMembers) do
        if member.professions then
            for profName in pairs(member.professions) do
                profSet[profName] = true
            end
        end
    end
    local profList = {}
    for profName in pairs(profSet) do
        table.insert(profList, profName)
    end
    table.sort(profList)
    return profList
end

-- ============================================================
-- Cleanup
-- ============================================================

function SC:CleanOldMembers(maxAge)
    if not SC.guildDB or not SC.guildDB.members then return end
    maxAge = maxAge or SC.MEMBER_MAX_AGE
    local now = time()
    local myKey = SC:GetMyCharKey()

    -- Clean across all guilds
    for guildName, guildMembers in pairs(SC.guildDB.members) do
        for charKey, member in pairs(guildMembers) do
            if charKey ~= myKey and member.lastSync then
                if (now - member.lastSync) > maxAge then
                    guildMembers[charKey] = nil
                end
            end
        end
        -- Remove empty guild tables
        if not next(guildMembers) then
            SC.guildDB.members[guildName] = nil
        end
    end
end
