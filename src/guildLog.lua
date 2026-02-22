local addonName, ns = ...

ns.guildLog = ns.guildLog or {}

local MAX_ENTRIES = 200

local function ensureDB()
    if not ns.db then return false end
    ns.db.guildLog = ns.db.guildLog or {}
    return true
end

local function pushEntry(entry)
    table.insert(ns.db.guildLog, 1, entry)
    while #ns.db.guildLog > MAX_ENTRIES do
        table.remove(ns.db.guildLog)
    end
end

function ns.guildLog.send(message, opts)
    if not message or message == "" then return end
    if not ensureDB() then
        if ns.log and ns.log.error then
            ns.log.error("guildLog.send: ns.db not ready")
        end
        return
    end

    opts = opts or {}
    local entry = {
        message = message,
        sender = ns.globals and ns.globals.CHARACTERNAME or UnitName("player") or "?",
        time = time()
    }

    pushEntry(entry)
    if ns.ui and ns.ui.updateGuildLog then
        local ok, err = pcall(ns.ui.updateGuildLog)
        if not ok and ns.log and ns.log.error then
            ns.log.error("updateGuildLog failed: " .. tostring(err))
        end
    end
    if opts.broadcast and ns.networking and ns.networking.SendToGuild then
        ns.networking.SendToGuild("GUILD_LOG", entry)
    end
end

function ns.guildLog.receive(entry)
    if not entry or not entry.message then return end
    if not ensureDB() then return end

    pushEntry({
        time = entry.time or time(),
        sender = entry.sender or "?",
        message = entry.message
    })

    if ns.ui and ns.ui.updateGuildLog then
        local ok, err = pcall(ns.ui.updateGuildLog)
        if not ok and ns.log and ns.log.error then
            ns.log.error("updateGuildLog failed: " .. tostring(err))
        end
    end
end