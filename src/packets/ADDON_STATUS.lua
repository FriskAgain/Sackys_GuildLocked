local addonName, ns = ...

local ADDON_STATUS = {}
ns.packets = ns.packets or {}
ns.packets.ADDON_STATUS = ADDON_STATUS

local function safeVal(v, fallback)
    if v == nil or v == "" then return fallback end
    return v
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
    local wasVersion = s.version
    local wasOnline = (s.online == true)
    local wasMissing = (s._missing == true)
    local disabledAt = s.disabledAt
    local u = ns.networking.activeUsers[key] or {}
    if state == "ONLINE" and wasEnabled and wasVersion == version then
        s.seen = true
        s.lastSeen = nowStamp
        s.online = true
        s.active = true
        if wasMissing and disabledAt and ns.guildLog and ns.guildLog.send then
            local delta = nowStamp - disabledAt
            if delta >= 0 then
                if ns.guildLog.clearSeenEvent then
                    ns.guildLog.clearSeenEvent("missing:" .. tostring(key))
                end
                local moneyDeltaText = nil
                if s.missingMoneyBaseline ~= nil and s.money ~= nil and ns.helpers and ns.helpers.formatMoneyDelta then
                    local moneyDelta = tonumber(s.money) - tonumber(s.missingMoneyBaseline)
                    moneyDeltaText = ns.helpers.formatMoneyDelta(moneyDelta)
                end
                local msg = (ns.helpers.getShort(key) or key) .. " re-enabled SGLK after " .. formatDuration(delta)
                if moneyDeltaText then
                    msg = msg .. " (money change: " .. moneyDeltaText .. ")"
                end
                ns.guildLog.send(
                    msg,
                    {
                        kind = "sync",
                        broadcast = true,
                        eventId = "reenabled:" .. tostring(key)
                    }
                )
            end
        end

        s._missing = nil
        s._missingSince = nil
        s._missingEventId = nil
        s.missingMoneyBaseline = nil
        s.missingMoneyAt = nil

        u.version = version
        u.lastSeen = nowSession
        u.active = true

        ns.db.addonStatus[key] = s
        ns.networking.activeUsers[key] = u
        return
    end

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

        if wasMissing and disabledAt and ns.guildLog and ns.guildLog.send then
            local delta = nowStamp - disabledAt
            if delta >= 0 then
                if ns.guildLog.clearSeenEvent then
                    ns.guildLog.clearSeenEvent("missing:" .. tostring(key))
                end
                local moneyDeltaText = nil
                if s.missingMoneyBaseline ~= nil and s.money ~= nil and ns.helpers and ns.helpers.formatMoneyDelta then
                    local moneyDelta = tonumber(s.money) - tonumber(s.missingMoneyBaseline)
                    moneyDeltaText = ns.helpers.formatMoneyDelta(moneyDelta)
                end
                local msg = (ns.helpers.getShort(key) or key) .. " re-enabled SGLK after " .. formatDuration(delta)
                if moneyDeltaText then
                    msg = msg .. " (money change: " .. moneyDeltaText .. ")"
                end
                ns.guildLog.send(
                    msg,
                    {
                        kind = "sync",
                        broadcast = true,
                        eventId = "reenabled:" .. tostring(key)
                    }
                )
            end
        end
        s._missing = nil
        s._missingSince = nil
        s._missingEventId = nil
        s.missingMoneyBaseline = nil
        s.missingMoneyAt = nil
        u.active = true

    elseif state == "OFFLINE" then
        s.online = false
        s.offlineAt = nowStamp
        s.active = false
        s._lastOfflineAt = nowStamp
        u.active = false
    end

    ns.db.addonStatus[key] = s
    ns.networking.activeUsers[key] = u

    if ns.ui and ns.ui.refresh then
        ns.ui.refresh()
    end
end