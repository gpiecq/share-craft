local addonName, SC = ...

-- ============================================================
-- Communication Layer - Guild Sync Protocol
-- ============================================================

SC.chunkBuffers = {}
SC.syncCooldowns = {}

-- ============================================================
-- Recipe Serialization
-- ============================================================

-- Fields separated by ~, recipes separated by \n
-- Reagents: name:count+name:count  |  GreenLines: line^line

function SC:SerializeRecipe(recipe)
    local stats = recipe.stats or {}
    local reagentParts = {}
    if recipe.reagents then
        for _, r in ipairs(recipe.reagents) do
            table.insert(reagentParts, r.name .. ":" .. (r.count or 1))
        end
    end
    local greenParts = {}
    if recipe.greenLines then
        for _, line in ipairs(recipe.greenLines) do
            table.insert(greenParts, line)
        end
    end
    return table.concat({
        recipe.name or "",
        tostring(recipe.quality or 0),
        recipe.category or "",
        tostring(recipe.itemLevel or 0),
        tostring(recipe.requiredLevel or 0),
        recipe.difficulty or "",
        tostring(recipe.spellID or 0),
        tostring(stats.armor or 0),
        tostring(stats.strength or 0),
        tostring(stats.agility or 0),
        tostring(stats.stamina or 0),
        tostring(stats.intellect or 0),
        tostring(stats.spirit or 0),
        table.concat(reagentParts, "+"),
        table.concat(greenParts, "^"),
        recipe.itemName or "",
        tostring(recipe.itemID or 0),
    }, "~")
end

function SC:DeserializeRecipe(str)
    local parts = {}
    for part in (str .. "~"):gmatch("([^~]*)~") do
        table.insert(parts, part)
    end

    if #parts < 2 then
        return { name = str, quality = 0 }
    end

    local recipe = {
        name = parts[1] or "",
        quality = tonumber(parts[2]) or 0,
        category = parts[3] ~= "" and parts[3] or nil,
        itemLevel = tonumber(parts[4]) or 0,
        requiredLevel = tonumber(parts[5]) or 0,
        difficulty = parts[6] ~= "" and parts[6] or nil,
        spellID = tonumber(parts[7]) ~= 0 and tonumber(parts[7]) or nil,
        stats = {
            armor = tonumber(parts[8]) or 0,
            strength = tonumber(parts[9]) or 0,
            agility = tonumber(parts[10]) or 0,
            stamina = tonumber(parts[11]) or 0,
            intellect = tonumber(parts[12]) or 0,
            spirit = tonumber(parts[13]) or 0,
        },
    }

    if parts[14] and parts[14] ~= "" then
        recipe.reagents = {}
        for reagentStr in parts[14]:gmatch("[^+]+") do
            local rName, rCount = reagentStr:match("^(.+):(%d+)$")
            if rName then
                table.insert(recipe.reagents, { name = rName, count = tonumber(rCount) or 1 })
            end
        end
    end

    if parts[15] and parts[15] ~= "" then
        recipe.greenLines = {}
        for line in parts[15]:gmatch("[^^]+") do
            table.insert(recipe.greenLines, line)
        end
    end

    if parts[16] and parts[16] ~= "" then
        recipe.itemName = parts[16]
    end

    if parts[17] and tonumber(parts[17]) and tonumber(parts[17]) ~= 0 then
        recipe.itemID = tonumber(parts[17])
    end

    return recipe
end

-- ============================================================
-- Initialization
-- ============================================================

function SC:InitComm()
    C_ChatInfo.RegisterAddonMessagePrefix(SC.COMM_PREFIX)

    local commFrame = CreateFrame("Frame")
    commFrame:RegisterEvent("CHAT_MSG_ADDON")
    commFrame:SetScript("OnEvent", function(_, event, prefix, msg, channel, sender)
        if event == "CHAT_MSG_ADDON" and prefix == SC.COMM_PREFIX then
            SC:HandleMessage(msg, channel, sender)
        end
    end)

    SC.commFrame = commFrame
    SC.debugPrint("Comm initialized, prefix registered: " .. SC.COMM_PREFIX)
end

-- ============================================================
-- Message Sending
-- ============================================================

function SC:SendHello()
    if not IsInGuild() then
        SC.debugPrint("SendHello: not in a guild, skipping")
        return
    end

    -- Get hashes for ALL known guild members (relay)
    local allHashes = SC:GetAllGuildHashes()
    if not allHashes or not next(allHashes) then
        SC.debugPrint("SendHello: no data to share")
        return
    end

    -- Send one HELLO per member, with delay between each
    local msgIndex = 0
    for memberKey, profHashes in pairs(allHashes) do
        local parts = {}
        for profName, hash in pairs(profHashes) do
            table.insert(parts, profName .. "=" .. hash)
        end

        if #parts > 0 then
            local payload = memberKey .. ":" .. table.concat(parts, ",")
            local msg = SC.COMM_VERSION .. "|HELLO|" .. payload

            if msgIndex == 0 then
                SC:ChunkAndSend(nil, msg, "GUILD")
                SC.debugPrint("SendHello broadcast: " .. msg)
            else
                local delay = msgIndex * SC.CHUNK_INTERVAL
                C_Timer.After(delay, function()
                    SC:ChunkAndSend(nil, msg, "GUILD")
                    SC.debugPrint("SendHello relay broadcast: " .. msg)
                end)
            end
            msgIndex = msgIndex + 1
        end
    end
end

function SC:SendRequest(target, charKey, profName)
    if not IsInGuild() then return end

    local msg = SC.COMM_VERSION .. "|REQUEST|" .. charKey .. ":" .. profName
    C_ChatInfo.SendAddonMessage(SC.COMM_PREFIX, msg, "WHISPER", target)
    SC.debugPrint("SendRequest to " .. target .. ": " .. msg)
end

function SC:SendData(target, charKey, profName)
    local member = SC:GetMemberData(charKey)
    if not member or not member.professions or not member.professions[profName] then return end

    local profData = member.professions[profName]
    local serialized = {}
    for _, recipe in ipairs(profData.recipes) do
        if type(recipe) == "table" then
            table.insert(serialized, SC:SerializeRecipe(recipe))
        else
            table.insert(serialized, recipe)
        end
    end
    local recipeStr = table.concat(serialized, "\n")
    local scanTime = profData.scanTime or time()

    local msg = SC.COMM_VERSION .. "|DATA|" .. charKey .. "|" .. profName .. "|" .. scanTime .. "|" .. recipeStr

    SC:ChunkAndSend(target, msg, "WHISPER")
    SC.debugPrint("SendData to " .. target .. " for " .. charKey .. "/" .. profName)
end

function SC:SendPrivacy(charKey, profName, enabled)
    if not IsInGuild() then return end

    local status = enabled and "ON" or "OFF"
    local msg = SC.COMM_VERSION .. "|PRIVACY|" .. charKey .. "|" .. profName .. "|" .. status

    C_ChatInfo.SendAddonMessage(SC.COMM_PREFIX, msg, "GUILD")
    SC.debugPrint("SendPrivacy broadcast: " .. msg)
end

-- ============================================================
-- Message Receiving / Dispatch
-- ============================================================

function SC:HandleMessage(msg, channel, sender)
    -- Remove realm from sender if present for comparison, but keep full name
    local senderName = sender
    local myName = UnitName("player")
    local myKey = SC:GetMyCharKey()

    -- Ignore our own messages
    if senderName == myName or senderName == myKey then
        return
    end
    -- Also check with realm stripped
    local senderBase = senderName:match("^([^-]+)")
    if senderBase == myName then
        return
    end

    SC.debugPrint("HandleMessage from " .. sender .. " [" .. channel .. "]: " .. msg:sub(1, 80))

    -- Parse version|type|payload
    local version, msgType, payload = msg:match("^(%d+)|(%a+)|(.+)$")
    if not version then
        SC.debugPrint("HandleMessage: invalid format")
        return
    end

    version = tonumber(version)
    if version ~= SC.COMM_VERSION then
        SC.debugPrint("HandleMessage: version mismatch (" .. tostring(version) .. " vs " .. SC.COMM_VERSION .. ")")
        return
    end

    if msgType == "HELLO" then
        SC:HandleHello(sender, payload)
    elseif msgType == "REQUEST" then
        SC:HandleRequest(sender, payload)
    elseif msgType == "DATA" then
        SC:HandleData(sender, payload)
    elseif msgType == "DATACHUNK" then
        SC:HandleDataChunk(sender, payload)
    elseif msgType == "PRIVACY" then
        SC:HandlePrivacy(sender, payload)
    end
end

-- ============================================================
-- HELLO handler
-- ============================================================

function SC:HandleHello(sender, payload)
    -- payload: charKey:prof1=hash1,prof2=hash2
    local charKey, hashStr = payload:match("^(.+):(.+)$")
    if not charKey or not hashStr then
        SC.debugPrint("HandleHello: bad payload")
        return
    end

    -- Throttle check
    if SC:IsThrottled(charKey) then
        SC.debugPrint("HandleHello: throttled for " .. charKey)
        return
    end

    -- Parse hashes
    local remoteHashes = {}
    for entry in hashStr:gmatch("[^,]+") do
        local profName, hash = entry:match("^(.+)=(.+)$")
        if profName and hash then
            remoteHashes[profName] = hash
        end
    end

    -- Compare with local data
    local localMember = SC:GetMemberData(charKey)
    local localHashes = {}
    if localMember and localMember.professions then
        for profName, profData in pairs(localMember.professions) do
            if profData.recipes then
                localHashes[profName] = SC:HashRecipes(profData.recipes)
            end
        end
    end

    -- Request any professions where hash differs or is unknown
    local needsRequest = false
    for profName, remoteHash in pairs(remoteHashes) do
        if localHashes[profName] ~= remoteHash then
            SC.debugPrint("HandleHello: hash mismatch for " .. charKey .. "/" .. profName)
            SC:SendRequest(sender, charKey, profName)
            needsRequest = true
        end
    end

    -- Remove professions that the sender no longer shares
    if localMember and localMember.professions then
        for profName in pairs(localMember.professions) do
            if not remoteHashes[profName] then
                SC.debugPrint("HandleHello: " .. charKey .. " no longer shares " .. profName)
                SC:RemoveMemberProfession(charKey, profName)
            end
        end
    end

    if not needsRequest then
        SC.debugPrint("HandleHello: all up to date for " .. charKey)
    end

    SC:SetThrottle(charKey)
end

-- ============================================================
-- REQUEST handler
-- ============================================================

function SC:HandleRequest(sender, payload)
    -- payload: charKey:profName
    local charKey, profName = payload:match("^(.+):(.+)$")
    if not charKey or not profName then
        SC.debugPrint("HandleRequest: bad payload")
        return
    end

    -- Check if we have data for this member (own data or relayed)
    local member = SC:GetMemberData(charKey)
    if not member or not member.professions or not member.professions[profName] then
        SC.debugPrint("HandleRequest: no data for " .. charKey .. "/" .. profName)
        return
    end

    -- For our own data, check privacy
    local myKey = SC:GetMyCharKey()
    if charKey == myKey and not SC:IsProfessionShared(charKey, profName) then
        SC.debugPrint("HandleRequest: profession " .. profName .. " is private")
        return
    end

    SC:SendData(sender, charKey, profName)
    SC.debugPrint("HandleRequest: relaying data for " .. charKey .. "/" .. profName .. " to " .. sender)
end

-- ============================================================
-- DATA handler (single message or reassembled)
-- ============================================================

function SC:HandleData(sender, payload)
    -- payload: charKey|profName|scanTime|recipeStr (recipes separated by \n, fields by ~)
    local charKey, profName, scanTimeStr, recipeStr = payload:match("^([^|]+)|([^|]+)|(%d+)|(.*)$")
    if not charKey then
        SC.debugPrint("HandleData: bad payload")
        return
    end

    local scanTime = tonumber(scanTimeStr) or time()

    local recipes = {}
    if recipeStr and recipeStr ~= "" then
        for recipeEntry in recipeStr:gmatch("[^\n]+") do
            local trimmed = recipeEntry:match("^%s*(.-)%s*$")
            if trimmed and trimmed ~= "" then
                table.insert(recipes, SC:DeserializeRecipe(trimmed))
            end
        end
    end

    table.sort(recipes, function(a, b)
        local nameA = type(a) == "table" and a.name or a
        local nameB = type(b) == "table" and b.name or b
        return nameA < nameB
    end)
    SC:SetMemberData(charKey, profName, recipes, scanTime)
    SC.debugPrint("HandleData: stored " .. #recipes .. " recipes for " .. charKey .. "/" .. profName)
end

-- ============================================================
-- DATACHUNK handler (chunked messages)
-- ============================================================

function SC:HandleDataChunk(sender, payload)
    -- payload: charKey|profName|scanTime|chunkIdx/totalChunks|chunkData
    local charKey, profName, scanTimeStr, chunkInfo, chunkData = payload:match("^([^|]+)|([^|]+)|(%d+)|(%d+/%d+)|(.*)$")
    if not charKey then
        SC.debugPrint("HandleDataChunk: bad payload")
        return
    end

    local chunkIdx, totalChunks = chunkInfo:match("^(%d+)/(%d+)$")
    chunkIdx = tonumber(chunkIdx)
    totalChunks = tonumber(totalChunks)

    local bufferKey = charKey .. "|" .. profName
    SC.chunkBuffers[bufferKey] = SC.chunkBuffers[bufferKey] or {
        total = totalChunks,
        received = {},
        timestamp = time(),
        scanTime = scanTimeStr,
        charKey = charKey,
        profName = profName,
    }

    local buffer = SC.chunkBuffers[bufferKey]
    buffer.received[chunkIdx] = chunkData

    SC.debugPrint("HandleDataChunk: received chunk " .. chunkIdx .. "/" .. totalChunks .. " for " .. bufferKey)

    -- Check if all chunks received
    local complete = true
    for i = 1, totalChunks do
        if not buffer.received[i] then
            complete = false
            break
        end
    end

    if complete then
        -- Reassemble
        local parts = {}
        for i = 1, totalChunks do
            table.insert(parts, buffer.received[i])
        end
        local fullRecipeStr = table.concat(parts)

        -- Clean up buffer
        SC.chunkBuffers[bufferKey] = nil

        -- Process as DATA
        local fullPayload = charKey .. "|" .. profName .. "|" .. buffer.scanTime .. "|" .. fullRecipeStr
        SC:HandleData(sender, fullPayload)
    end
end

-- ============================================================
-- PRIVACY handler
-- ============================================================

function SC:HandlePrivacy(sender, payload)
    -- payload: charKey|profName|ON/OFF
    local charKey, profName, status = payload:match("^([^|]+)|([^|]+)|(%a+)$")
    if not charKey or not profName then
        SC.debugPrint("HandlePrivacy: bad payload")
        return
    end

    if status == "OFF" then
        SC:RemoveMemberProfession(charKey, profName)
        SC.debugPrint("HandlePrivacy: removed " .. charKey .. "/" .. profName)
    end
end

-- ============================================================
-- Chunking & Sending
-- ============================================================

function SC:ChunkAndSend(target, fullMsg, channelType)
    local maxLen = SC.MAX_PAYLOAD

    if #fullMsg <= maxLen then
        if channelType == "GUILD" then
            C_ChatInfo.SendAddonMessage(SC.COMM_PREFIX, fullMsg, "GUILD")
        else
            C_ChatInfo.SendAddonMessage(SC.COMM_PREFIX, fullMsg, "WHISPER", target)
        end
        return
    end

    -- Need to chunk: extract header and recipe data separately
    -- For DATA messages, convert to DATACHUNK format
    local version, msgType, rest = fullMsg:match("^(%d+)|(%a+)|(.+)$")
    if msgType == "DATA" then
        local charKey, profName, scanTime, recipeStr = rest:match("^([^|]+)|([^|]+)|(%d+)|(.*)$")
        if not charKey then return end

        -- Calculate overhead for chunk header
        local headerTemplate = version .. "|DATACHUNK|" .. charKey .. "|" .. profName .. "|" .. scanTime .. "|"
        -- Reserve space for chunkInfo (e.g., "99/99|")
        local chunkOverhead = #headerTemplate + 6
        local chunkSize = maxLen - chunkOverhead

        if chunkSize < 10 then chunkSize = 10 end

        local chunks = {}
        local pos = 1
        while pos <= #recipeStr do
            table.insert(chunks, recipeStr:sub(pos, pos + chunkSize - 1))
            pos = pos + chunkSize
        end

        local totalChunks = #chunks
        for i, chunk in ipairs(chunks) do
            local chunkMsg = version .. "|DATACHUNK|" .. charKey .. "|" .. profName .. "|" .. scanTime .. "|" .. i .. "/" .. totalChunks .. "|" .. chunk

            C_Timer.After((i - 1) * SC.CHUNK_INTERVAL, function()
                if channelType == "GUILD" then
                    C_ChatInfo.SendAddonMessage(SC.COMM_PREFIX, chunkMsg, "GUILD")
                else
                    C_ChatInfo.SendAddonMessage(SC.COMM_PREFIX, chunkMsg, "WHISPER", target)
                end
                SC.debugPrint("Sent chunk " .. i .. "/" .. totalChunks)
            end)
        end
    else
        -- Non-DATA messages that are too long: just send as-is (shouldn't happen normally)
        if channelType == "GUILD" then
            C_ChatInfo.SendAddonMessage(SC.COMM_PREFIX, fullMsg, "GUILD")
        else
            C_ChatInfo.SendAddonMessage(SC.COMM_PREFIX, fullMsg, "WHISPER", target)
        end
    end
end

-- ============================================================
-- Throttle
-- ============================================================

function SC:IsThrottled(charKey)
    local last = SC.syncCooldowns[charKey]
    if last and (time() - last) < SC.SYNC_COOLDOWN then
        return true
    end
    return false
end

function SC:SetThrottle(charKey)
    SC.syncCooldowns[charKey] = time()
end

-- ============================================================
-- Buffer Cleanup
-- ============================================================

function SC:CleanChunkBuffers()
    local now = time()
    for key, buffer in pairs(SC.chunkBuffers) do
        if (now - buffer.timestamp) > SC.BUFFER_TIMEOUT then
            SC.debugPrint("CleanChunkBuffers: removing stale buffer " .. key)
            SC.chunkBuffers[key] = nil
        end
    end
end

-- Start periodic buffer cleanup
C_Timer.NewTicker(30, function()
    SC:CleanChunkBuffers()
end)
