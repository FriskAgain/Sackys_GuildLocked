local addonName, ns = ...

local ADDON_STATUS = {}
ns.packets = ns.packets or {}
ns.packets.ADDON_STATUS = ADDON_STATUS

local function safeVal(v, fallback)
    if v == nil or v == "" then return fallback end
    return v
end

local function nowSec()
    return GetTime()
end

function ADDON_STATUS.handle(sender, payload)
    if not payload or not payload.state then return end
    if not ns.db then return end

    local key = ns.helpers.getKey(sender)
    if not key then return end

    ns.db.addonStatus = ns.db.addonStatus or {}
    ns.networking.activeUsers = ns.networking.activeUsers or {}

    local short   = ns.helpers.getShort(sender) or key
    local state   = payload.state
    local version = safeVal(payload.version, "?")
    local now     = nowSec()

    local s = ns.db.addonStatus[key] or {}
    local wasSeen       = (s.seen == true)
    local wasEnabled    = (s.enabled == true)
    local wasDisabled   = (s.enabled == false)

    s.seen = true
    s.version = version
    s.lastSeen = now

    if payload.prof1 ~= nil then s.prof1 = payload.prof1 end
    if payload.prof1Skill ~= nil then s.prof1Skill = payload.prof1Skill end
    if payload.prof2 ~= nil then s.prof2 = payload.prof2 end
    if payload.prof2Skill ~= nil then s.prof2Skill = payload.prof2Skill end

    local function isReloadRejoin()
        return s._lastOfflineAt and (now - s._lastOfflineAt) <= 10
    end

    if state == "ONLINE" then
        -- ONLINE implies enabled
        s.seen = true
        s.enabled = true
        s.version = version
        s.lastSeen = now
        s._missingLogged = nil

        ns.networking.activeUsers[key] = ns.networking.activeUsers[key] or {}
        ns.networking.activeUsers[key].active = true
        ns.networking.activeUsers[key].version = version
        ns.networking.activeUsers[key].lastSeen = now

        if wasSeen and wasDisabled and (not isReloadRejoin()) then
            if ns.guildLog and ns.guildLog.send then
                ns.guildLog.send(short .. " enabled the addon (v" .. version .. ")", { broadcast = true })
            end
        end

        s._lastOfflineAt = nil
        ns.db.addonStatus[key] = s
        if ns.ui and ns.ui.refresh then ns.ui.refresh() end
        return
    end

    if state == "OFFLINE" then
        -- OFFLINE implies disabled (Suppress logging if it's likely /reload)
        s._lastOfflineAt = now
        s.enabled = false
        s.version = version
        s.lastSeen = now
        s.seen = true

        ns.networking.activeUsers[key] = ns.networking.activeUsers[key] or {}
        ns.networking.activeUsers[key].active = false
        ns.networking.activeUsers[key].version = version
        ns.networking.activeUsers[key].lastSeen = now

        if wasEnabled and (not isReloadRejoin()) then
            if ns.guildLog and ns.guildLog.send then
                ns.guildLog.send(short .. " disabled the addon", { broadcast = true })
            end
        end

        ns.db.addonStatus[key] = s
        if ns.ui and ns.ui.refresh then ns.ui.refresh() end
        return
    end
end