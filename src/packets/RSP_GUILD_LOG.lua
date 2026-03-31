local addonName, ns = ...

local RSP_GUILD_LOG = {}
ns.packets = ns.packets or {}
ns.packets.RSP_GUILD_LOG = RSP_GUILD_LOG
RSP_GUILD_LOG._pending = RSP_GUILD_LOG._pending or {}

local function getPending(requestId, sender, total)
    local key = tostring(sender or "?") .. "|" .. tostring(requestId or "?")
    RSP_GUILD_LOG._pending[key] = RSP_GUILD_LOG._pending[key] or {
        total = total or 1,
        parts = {},
        received = 0,
        startedAt = time(),
    }
    return key, RSP_GUILD_LOG._pending[key]
end

local function prunePending()
    local now = time()
    for key, data in pairs(RSP_GUILD_LOG._pending) do
        if not data.startedAt or (now - data.startedAt) > 30 then
            RSP_GUILD_LOG._pending[key] = nil
        end
    end
end

function RSP_GUILD_LOG.handle(sender, payload)
    if not payload or type(payload.entries) ~= "table" then return end

    local requestId = tostring(payload.requestId or "")
    local part = tonumber(payload.part) or 1
    local total = tonumber(payload.total) or 1

    if ns.log and ns.log.debug then
        ns.log.debug("Received RSP_GUILD_LOG from " .. tostring(sender) .. " part " .. tostring(part) .. "/" .. tostring(total))
    end

    if requestId == "" or total <= 1 then
        if ns.packets and ns.packets.REQ_GUILD_LOG and ns.packets.REQ_GUILD_LOG.markAnswered then
            ns.packets.REQ_GUILD_LOG.markAnswered(requestId)
        end
        if ns.guildLog and ns.guildLog.importEntries then
            ns.guildLog.importEntries(payload.entries)
        end
        if ns.ui and ns.ui.updateGuildLog then
            ns.ui.updateGuildLog()
        end
        return
    end

    prunePending()

    local key, pending = getPending(requestId, sender, total)
    pending.total = total

    if not pending.parts[part] then
        pending.parts[part] = payload.entries
        pending.received = pending.received + 1
    end

    if pending.received < pending.total then
        return
    end

    local merged = {}
    for i = 1, pending.total do
        local chunk = pending.parts[i]
        if type(chunk) == "table" then
            for _, entry in ipairs(chunk) do
                merged[#merged + 1] = entry
            end
        end
    end

    if ns.packets and ns.packets.REQ_GUILD_LOG and ns.packets.REQ_GUILD_LOG.markAnswered then
        ns.packets.REQ_GUILD_LOG.markAnswered(requestId)
    end
    if ns.guildLog and ns.guildLog.importEntries then
        ns.guildLog.importEntries(merged)
    end
    if ns.ui and ns.ui.updateGuildLog then
        ns.ui.updateGuildLog()
    end

    if ns.log and ns.log.debug then
        ns.log.debug("Completed RSP_GUILD_LOG import from " .. tostring(sender) .. " with " .. tostring(#merged) .. " entries")
    end

    RSP_GUILD_LOG._pending[key] = nil
end