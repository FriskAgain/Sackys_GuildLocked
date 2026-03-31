local addonName, ns = ...

local REQ_GUILD_LOG = {}
ns.packets = ns.packets or {}
ns.packets.REQ_GUILD_LOG = REQ_GUILD_LOG

REQ_GUILD_LOG._answered = REQ_GUILD_LOG._answered or {}

local function pruneAnswered(now)
    for id, expiresAt in pairs(REQ_GUILD_LOG._answered) do
        if type(expiresAt) ~= "number" or expiresAt <= now then
            REQ_GUILD_LOG._answered[id] = nil
        end
    end
end

local function markAnswered(requestId)
    if not requestId or requestId == "" then return end
    local now = time()
    pruneAnswered(now)
    REQ_GUILD_LOG._answered[requestId] = now + 10
end

function REQ_GUILD_LOG.markAnswered(requestId)
    markAnswered(requestId)
end

local function estimateEncodedSize(packetType, payload)
    if not ns.networking or not ns.networking.Serializer or not ns.networking.CompressLib or not ns.networking.EncodeTable then
        return nil
    end

    local serialized = ns.networking.Serializer:Serialize({
        type = packetType,
        payload = payload
    })
    if not serialized then return nil end

    local compressed = ns.networking.CompressLib:Compress(serialized)
    if not compressed then return nil end

    local encoded = ns.networking.EncodeTable:Encode(compressed)
    if not encoded then return nil end

    return #encoded
end

local function splitEntriesBySize(requestId, entries)
    local chunks = {}
    local current = {}

    -- stay comfortably below 3500
    local SAFE_TARGET = 2800

    local function flush()
        chunks[#chunks + 1] = current
        current = {}
    end

    for _, entry in ipairs(entries or {}) do
        local test = {}
        for i = 1, #current do
            test[i] = current[i]
        end
        test[#test + 1] = entry

        local payload = {
            requestId = requestId,
            part = 1,
            total = 1,
            entries = test,
            sentAt = (ns.helpers and ns.helpers.nowStamp and ns.helpers.nowStamp()) or time(),
        }

        local size = estimateEncodedSize("RSP_GUILD_LOG", payload)

        if size and size > SAFE_TARGET and #current > 0 then
            flush()
            current[#current + 1] = entry
        else
            current[#current + 1] = entry
        end
    end

    if #current > 0 then
        flush()
    end

    if #chunks == 0 then
        chunks[1] = {}
    end

    return chunks
end

function REQ_GUILD_LOG.handle(sender, payload)
    if not ns or not ns.guildLog then return end
    if not ns.helpers or not ns.helpers.playerCanViewGuildLog then return end
    if not ns.helpers.isGuildMember or not ns.helpers.isGuildMember(sender) then return end
    if not ns.helpers.playerCanViewGuildLog() then
        return
    end

    local limit = tonumber(payload and payload.limit) or 25
    if limit < 1 then limit = 1 end
    if limit > 100 then limit = 100 end

    local requestId = tostring(payload and payload.requestId or "")
    if requestId == "" then
        requestId = tostring(sender) .. ":" .. tostring(time())
    end

    if not ns.guildLog.exportRecent then
        return
    end

    local delay = 0.20 + (math.random() * 0.80)

    C_Timer.After(delay, function()
        local now = time()
        pruneAnswered(now)

        if REQ_GUILD_LOG._answered[requestId] then
            return
        end

        local entries = ns.guildLog.exportRecent(limit)
        local chunks = splitEntriesBySize(requestId, entries)
        local total = #chunks

        if ns.log and ns.log.debug then
            ns.log.debug("REQ_GUILD_LOG responding to " .. tostring(sender) .. " with " .. tostring(total) .. " chunk(s)")
        end

        if ns.networking and ns.networking.SendWhisper then
            for part = 1, total do
                if ns.log and ns.log.debug then
                    ns.log.debug("Sending RSP_GUILD_LOG part " .. tostring(part) .. "/" .. tostring(total) .. " to " .. tostring(sender))
                end

                ns.networking.SendWhisper("RSP_GUILD_LOG", {
                    requestId = requestId,
                    part = part,
                    total = total,
                    entries = chunks[part],
                    sentAt = (ns.helpers and ns.helpers.nowStamp and ns.helpers.nowStamp()) or now,
                }, sender)
            end

            markAnswered(requestId)
        end
    end)
end