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
    if not ns.helpers or not ns.helpers.getKey then return end

    local key = ns.helpers.getKey(sender)
    if not key then return end

    ns.db.addonStatus = ns.db.addonStatus or {}
    ns.networking = ns.networking or {}
    ns.networking.activeUsers = ns.networking.activeUsers or {}

    local state   = payload.state
    local version = safeVal(payload.version, "?")
    local now     = GetTime()

    local s = ns.db.addonStatus[key] or {}
    s.seen = true
    s.version = version
    s.lastSeen = now

    if payload.prof1 ~= nil then s.prof1 = payload.prof1 end
    if payload.prof1Skill ~= nil then s.prof1Skill = payload.prof1Skill end
    if payload.prof2 ~= nil then s.prof2 = payload.prof2 end
    if payload.prof2Skill ~= nil then s.prof2Skill = payload.prof2Skill end

    local u = ns.networking.activeUsers[key] or {}
    u.version = version
    u.lastSeen = now

    if state == "ONLINE" then
        s.enabled = true
        s._missing = nil
        s._missingSince = nil
        u.active = true
    elseif state == "OFFLINE" then
        s.enabled = false
        s._lastOfflineAt = now
        u.active = false
    end
    ns.db.addonStatus[key] = s
    ns.networking.activeUsers[key] = u
    if ns.ui and ns.ui.refresh then ns.ui.refresh() end    
end