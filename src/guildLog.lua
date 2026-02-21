local addonName, ns = ...

ns.guildLog = ns.guildLog or {}

function ns.guildLog.send(message)

    if not ns.db then
        ns.log.error("guildLog.send: ns.db not ready")
        return
    end

    ns.db.guildLog = ns.db.guildLog or {}

    local entry = {
        message = message,
        sender = ns.globals.CHARACTERNAME,
        time = time()
    }

    table.insert(ns.db.guildLog, 1, entry)

    if ns.networking and ns.networking.SendToGuild then
        ns.networking.SendToGuild("GUILD_LOG", entry)
    end

end