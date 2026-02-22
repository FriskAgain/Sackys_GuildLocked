local addonName, ns = ...

local GUILD_LOG = {}
ns.packets = ns.packets or {}
ns.packets.GUILD_LOG = GUILD_LOG

function GUILD_LOG.handle(sender, payload)
    if not payload or not payload.message then return end
    if not ns.guildLog or not ns.guildLog.receive then return end

    ns.guildLog.receive({
        message = payload.message,
        sender  = payload.sender or sender,
        time    = payload.time
    })
end