local addonName, ns = ...

ns.guildLog = ns.guildLog or {}

local MAX_ENTRIES = 200
local MAX_SEEN = 400

local function realmKey()
    return GetRealmName() or "UnknownRealm"
end

local function ensureDB()
    if not ns.db then return false end

    ns.db.guildLogsByRealm = ns.db.guildLogsByRealm or {}
    ns.db.guildLogMetaByRealm = ns.db.guildLogMetaByRealm or {}

    local rk = realmKey()

    ns.db.guildLogsByRealm[rk] = ns.db.guildLogsByRealm[rk] or {}
    ns.db.guildLogMetaByRealm[rk] = ns.db.guildLogMetaByRealm[rk] or {}

    ns.db.guildLog = ns.db.guildLogsByRealm[rk]
    ns.db.guildLogMeta = ns.db.guildLogMetaByRealm[rk]

    ns.db.guildLogMeta._seen = ns.db.guildLogMeta._seen or {}
    ns.db.guildLogMeta._seenOrder = ns.db.guildLogMeta._seenOrder or {}

    return true
end

local function makeId(entry)
    if entry.eventId and entry.eventId ~= "" then
        return "event:" .. tostring(entry.eventId)
    end
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
        if old then
            seen[old] = nil
        end
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
        message = tostring(message),
        sender = (ns.globals and ns.globals.CHARACTERNAME) or UnitName("player") or "?",
        time = (ns.helpers and ns.helpers.nowStamp and ns.helpers.nowStamp()) or time,
        kind = opts.kind or "info",
        eventId = opts.eventId or nil,
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
        time = entry.time or ((ns.helpers and ns.helpers.nowStamp and ns.helpers.nowStamp()) or time()),
        sender = entry.sender or "?",
        message = tostring(entry.message or ""),
        kind = entry.kind or "info",
        eventId = entry.eventId or nil,
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

function ns.guildLog.clearSeenEvent(eventId)
    if not eventId or eventId == "" then return end
    if not ensureDB() then return end

    local id = "event:" .. tostring(eventId)
    local meta = ns.db.guildLogMeta
    local seen = meta and meta._seen
    local order = meta and meta._seenOrder
    
    if seen then
        seen[id] = nil
    end
    if order then
        for i = #order, 1, -1 do
            if order[i] == id then
                table.remove(order, i)
            end
        end
    end
end

ns.guildLog.events = {}

function ns.guildLog.events.info(msg)
    ns.guildLog.send(msg, {kind="info", broadcast=true})
end

function ns.guildLog.events.warn(msg)
    ns.guildLog.send(msg, {kind="warn", broadcast=true})
end

function ns.guildLog.events.blocked(msg)
    ns.guildLog.send(msg, {kind="blocked", broadcast=true})
end

function ns.guildLog.events.sync(msg)
    ns.guildLog.send(msg, {kind="sync", broadcast=false})
end

function ns.guildLog.events.system(msg)
    ns.guildLog.send(msg, {kind="system", broadcast=false})
end