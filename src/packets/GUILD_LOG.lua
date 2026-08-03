local addonName, ns = ...

local GUILD_LOG = {}
ns.packets = ns.packets or {}
ns.packets.GUILD_LOG = GUILD_LOG

function GUILD_LOG.handle(sender, payload)
    if not payload or not payload.message then return end
    if not ns.guildLog or not ns.guildLog.receive then return end
    if not sender or sender == "" then return end

    local rosterReady = IsInGuild() and (GetNumGuildMembers() or 0) > 0
    if rosterReady and ns.helpers and ns.helpers.isGuildMember and not ns.helpers.isGuildMember(sender) then
        if ns.log and ns.log.debug then
            ns.log.debug("Rejected GUILD_LOG from non-guild member: " .. tostring(sender))
        end
        return
    end

    local now = (ns.helpers and ns.helpers.nowStamp and ns.helpers.nowStamp()) or time()
    local stamp = tonumber(payload.time) or now
    if stamp <= 0 or stamp > (now + 300) then
        stamp = now
    end

    ns.guildLog.receive({
        time = stamp,
        sender = sender,
        message = payload.message,
        kind = payload.kind or "info",
        eventId = payload.eventId or nil,
    })
end
