local addonName, ns = ...

ns.guildLog = ns.guildLog or {}

local MAX_ENTRIES = 200
local MAX_SEEN = 400

local function ensureDB()
    if not ns.db then return false end
    ns.db.guildLog = ns.db.guildLog or {}

    ns.db.guildLogMeta = ns.db.guildLogMeta or {}
    ns.db.guildLogMeta._seen = ns.db.guildLogMeta._seen or {}
    ns.db.guildLogMeta._seenOrder = ns.db.guildLogMeta._seenOrder or {}

    return true
end

local function makeId(entry)
    local sender = tostring(entry.sender or "?")
    local t = tonumber(entry.time) or 0
    local msg = tostring(entry.message or "")
    return sender .. "|" .. t .. "|" .. msg
end

local function seenCheckAndRemember(id)
    local meta = ns.db.guildLogMeta
    local seen = meta._seen
    local order = meta._seenOrder

    if seen[id] then
        return true
    end

    seen[id] = true
    order[#order + 1] = id

    while #order > MAX_SEEN do
        local old = table.remove(order, 1)
        if old then seen[old] = nil end
    end
    return false
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
        sender = (ns.globals and ns.globals.CHARACTERNAME) or UnitName("player") or "?",
        time = time()
    }

    local id = makeId(entry)
    if seenCheckAndRemember(id) then
        return
    end

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

    local clean = {
        time = entry.time or time(),
        sender = entry.sender or "?",
        message = entry.message
    }
    local id = makeId(clean)
    if seenCheckAndRemember(id) then
        return
    end

    pushEntry(clean)
    if ns.ui and ns.ui.updateGuildLog then
        local ok, err = pcall(ns.ui.updateGuildLog)
        if not ok and ns.log and ns.log.error then
            ns.log.error("updateGuildLog failed: " .. tostring(err))
        end
    end
end