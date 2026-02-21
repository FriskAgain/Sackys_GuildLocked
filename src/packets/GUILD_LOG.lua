local addonName, ns = ...

local GUILD_LOG = {}
ns.packets = ns.packets or {}
ns.packets.GUIILD_LOG = GUILD_LOG

function GUILD_LOG.handle(sender, payload)

    if not payload or not payload.message then return end

    ns.guildLog = ns.guildLog or {}
    ns.db.guildLog = ns.db.guildLog or {}

    table.insert(ns.db.guildLog, 1, {
        time = payload.time or time(),
        sender = sender,
        message = payload.message
    })

    -- refresh UI if open
    if ns.ui and ns.ui.updateGuildLog then
        ns.ui.updateGuildLog()
    end

end