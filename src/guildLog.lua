local addonName, ns = ...

ns.guildLog = ns.guildLog or {}

local MAX_ENTRIES = 200

local function nowEpoch()
    if GetServerTime then return GetServerTime() end
    return time()
end

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
    if not ensureDB() then return end

    opts = opts or {}

    local entry = {
        message = message,
        sender  = ns.globals and ns.globals.CHARACTERNAME or UnitName("player") or "?",
        sendTime = nowEpoch(),
        recvTime = nowEpoch(),
    }

    pushEntry(entry)

    if ns.ui and ns.ui.updateGuildLog then
        ns.ui.updateGuildLog()
    end

    if opts.broadcast and ns.networking and ns.networking.SendToGuild then
        ns.networking.SendToGuild("GUILD_LOG", {
            message = entry.message,
            sender  = entry.sender,
            time    = entry.sendTime
        })
    end
end

function ns.guildLog.receive(entry)
    if not entry or not entry.message then return end
    if not ensureDB() then return end

    pushEntry({
        message = entry.message,
        sender  = entry.sender or "?",
        sendTime = entry.time or entry.sendTime or 0,
        recvTime = nowEpoch(),
    })

    if ns.ui and ns.ui.updateGuildLog then
        ns.ui.updateGuildLog()
    end
end