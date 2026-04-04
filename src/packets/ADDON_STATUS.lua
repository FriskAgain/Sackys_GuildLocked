local addonName, ns = ...

local ADDON_STATUS = {}
ns.packets = ns.packets or {}
ns.packets.ADDON_STATUS = ADDON_STATUS

local function safeVal(v, fallback)
    if v == nil or v == "" then return fallback end
    return v
end

local function maybeLogReenabled(key, s, nowStamp)
    if not key or not s then return end
    if not s._missing then return end
    if not s.disabledAt then return end
    if not ns.guildLog or not ns.guildLog.send then return end

    local delta = nowStamp - s.disabledAt
    if delta < 0 then
        return
    end

    local cycleId = tostring(s.disabledAt or nowStamp)
    local missingEventId = s._missingEventId or ("missing:" .. tostring(key) .. ":" .. cycleId)
    local reenabledEventId = "reenabled:" .. tostring(key) .. ":" .. cycleId

    local moneyDeltaText = nil
    if s.missingMoneyBaseline ~= nil and s.money ~= nil and ns.helpers and ns.helpers.formatMoneyDelta then
        local moneyDelta = tonumber(s.money) - tonumber(s.missingMoneyBaseline)
        moneyDeltaText = ns.helpers.formatMoneyDelta(moneyDelta)
    end

    local msg = (ns.helpers.getShort(key) or key) .. " re-enabled SGLK after " .. (ns.formatDuration and ns.formatDuration(delta) or (tostring(delta) .. "s"))
    if moneyDeltaText then
        msg = msg .. " (money change: " .. moneyDeltaText .. ")"
    end

    local suppress = false
    if ns.guildLog.hasRecentStatusLock then
        suppress = ns.guildLog.hasRecentStatusLock("reenabled", key, 60)
    end
    if not suppress then
        if ns.guildLog.setStatusLock then
            ns.guildLog.setStatusLock("reenabled", key, 60)
        end
        ns.guildLog.send(msg, {
            kind = "sync",
            broadcast = true,
            eventId = reenabledEventId
        })
    end
end

local function markMissingState(key, s, u, nowStamp, intentional)
    s._missing = true
    s._missingSince = nowStamp
    s.disabledAt = nowStamp

    local cycleId = tostring(s.disabledAt or nowStamp)
    local missingEventId = "missing:" .. tostring(key) .. ":" .. cycleId
    local reenabledEventId = "reenabled:" .. tostring(key) .. ":" .. cycleId

    s._missingEventId = missingEventId

    s.active = false
    s.enabled = false

    s.missingMoneyBaseline = tonumber(s.money) or 0
    s.missingMoneyAt = nowStamp

    s.online = true
    s.onlineAt = s.onlineAt or nowStamp

    u.active = false
    u.enabled = false

    if ns.guildLog and ns.guildLog.send then
        local msg
        if intentional then
            msg = (ns.helpers.getShort(key) or key) .. " disabled SGLK while online"
        else
            msg = (ns.helpers.getShort(key) or key) .. " is online without SGLK enabled"
        end

        ns.guildLog.send(msg, {
            kind = "warn",
            broadcast = true,
            eventId = missingEventId
        })
    end
end

function ADDON_STATUS.handle(sender, payload)
    if not payload or not payload.state then return end
    if not ns.db then return end
    if not ns.helpers or not ns.helpers.getKey or not ns.helpers.nowStamp then return end

    local key = ns.helpers.getKey(sender)
    if not key then return end

    ns.db.addonStatus = ns.db.addonStatus or {}
    ns.networking = ns.networking or {}
    ns.networking.activeUsers = ns.networking.activeUsers or {}

    local state = payload.state
    local version = safeVal(payload.version, "")
    local nowSession = GetTime()
    local nowStamp = ns.helpers.nowStamp()

    local s = ns.db.addonStatus[key] or {}
    local wasEnabled = (s.enabled == true)
    local wasOnline = (s.online == true)
    local wasMissing = (s._missing == true)

    local u = ns.networking.activeUsers[key] or {}

    s.seen = true
    s.version = version
    s.lastSeen = nowStamp

    if payload.prof1 ~= nil then s.prof1 = payload.prof1 end
    if payload.prof1Skill ~= nil then s.prof1Skill = payload.prof1Skill end
    if payload.prof2 ~= nil then s.prof2 = payload.prof2 end
    if payload.prof2Skill ~= nil then s.prof2Skill = payload.prof2Skill end
    if payload.money ~= nil then
        local newMoney = tonumber(payload.money) or 0
        local oldMoney = tonumber(s.money) or newMoney
        s.prevMoney = tonumber(s.money) or newMoney
        s.money = newMoney
        s.moneyDelta = newMoney - oldMoney
        s.moneyUpdatedAt = nowStamp
        u.money = newMoney
    end

    u.version = version
    u.lastSeen = nowSession

    if state == "ONLINE" then
        s.online = true
        if not wasOnline then
            s.onlineAt = nowStamp
        end
        s.enabled = true
        if not wasEnabled then
            s.enabledAt = nowStamp
        end
        s.active = true
        u.active = true
        u.enabled = true
        s._onlineSince = nil

        if wasMissing then
            maybeLogReenabled(key, s, nowStamp)
        end

        s._missing = nil
        s._missingSince = nil
        s._missStrikes = nil
        s._missingEventId = nil
        s.missingMoneyBaseline = nil
        s.missingMoneyAt = nil

    elseif state == "DISABLED" then
        s.online = true
        if not wasOnline then
            s.onlineAt = nowStamp
        end

        if not wasMissing then
            markMissingState(key, s, u, nowStamp, true)
        else
            s.active = false
            s.enabled = false
            u.active = false
            u.enabled = false
        end

    elseif state == "OFFLINE" then
        s.online = false
        s.offlineAt = nowStamp
        s.active = false
        s._lastOfflineAt = nowStamp
        u.active = false
        u.enabled = false
    end

    ns.db.addonStatus[key] = s
    ns.networking.activeUsers[key] = u

    if ns.ui and ns.ui.requestRefresh then
        ns.ui.requestRefresh(0.3)
    end
end