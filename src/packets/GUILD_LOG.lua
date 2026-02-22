local addonName, ns = ...

local GUILD_LOG = {}
ns.packets = ns.packets or {}
ns.packets.GUILD_LOG = GUILD_LOG

function GUILD_LOG.handle(sender, payload)
    if not payload or not payload.message then return end
    if not ns.guildLog or not ns.guildLog.receive then return end

    ns.guildLog.receive({
        time = payload.time,
        sender = payload.sender or sender,
        message = payload.message
    })
end