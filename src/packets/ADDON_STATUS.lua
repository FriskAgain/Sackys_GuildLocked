local addonName, ns = ...

local ADDON_STATUS = {}
ns.packets = ns.packets or {}
ns.packets.ADDON_STATUS = ADDON_STATUS

local function safeVal(v, fallback)
    if v == nil or v == "" then return fallback end
    return v
end

function ADDON_STATUS.handle(sender, payload)
    if ns.options and ns.options.debug then
        ns.log.info("ADDON_STATUS.handle fired from: " .. tostring(sender) .. " state=" .. tostring(payload and payload.state))
    end
    if not payload or not payload.state then return end
    if not ns.db then return end

    local key = ns.helpers.getKey(sender)
    if not key then return end

    ns.db.chars = ns.db.chars or {}
    ns.db.addonStatus = ns.db.addonStatus or {}
    ns.networking.activeUsers = ns.networking.activeUsers or {}

    local short   = ns.helpers.getShort(sender) or key
    local state   = payload.state
    local version = safeVal(payload.version, "?")
    local now     = GetTime()

    local prof1      = safeVal(payload.prof1, nil)
    local prof1Skill = safeVal(payload.prof1Skill, nil)
    local prof2      = safeVal(payload.prof2, nil)
    local prof2Skill = safeVal(payload.prof2Skill, nil)

    ns.db.chars[key] = ns.db.chars[key] or {}
    ns.db.addonStatus[key] = ns.db.addonStatus[key] or {}
    local s = ns.db.addonStatus[key]

    local wasActive = (ns.networking.activeUsers[key] and ns.networking.activeUsers[key].active) == true

    if prof1 ~= nil then ns.db.chars[key].prof1 = prof1 end
    if prof1Skill ~= nil then ns.db.chars[key].prof1Skill = prof1Skill end
    if prof2 ~= nil then ns.db.chars[key].prof2 = prof2 end
    if prof2Skill ~= nil then ns.db.chars[key].prof2Skill = prof2Skill end

    s.version = version
    s.lastSeen = now
    s.seen = true
    if prof1 ~= nil then ns.db.addonStatus[key].prof1 = prof1 end
    if prof1Skill ~= nil then ns.db.addonStatus[key].prof1Skill = prof1Skill end
    if prof2 ~= nil then ns.db.addonStatus[key].prof2 = prof2 end
    if prof2Skill ~= nil then ns.db.addonStatus[key].prof2Skill = prof2Skill end

    if state == "ONLINE" then
        ns.networking.activeUsers[key] = {
            version = version,
            active = true,
            lastSeen = now,
            prof1 = safeVal(prof1, "-"),
            prof1Skill = safeVal(prof1Skill, "-"),
            prof2 = safeVal(prof2, "-"),
            prof2Skill = safeVal(prof2Skill, "-"),
        }
        s.enabled = true
        s._missingLogged = nil

        if not wasActive and ns.guildLog and ns.guildLog.send then
            ns.guildLog.send(short .. " enabled the addon (v" .. version .. ")", { broadcast = true })
        end

        if ns.ui and ns.ui.refresh then ns.ui.refresh() end
        return
    end

    if state == "OFFLINE" then
        ns.networking.activeUsers[key] = ns.networking.activeUsers[key] or {}
        ns.networking.activeUsers[key].version = version
        ns.networking.activeUsers[key].active = false
        ns.networking.activeUsers[key].lastSeen = now

        if wasActive and ns.guildLog and ns.guildLog.send then
            ns.guildLog.send(short .. " disabled the addon", { broadcast = true })
        end

        if ns.ui and ns.ui.refresh then ns.ui.refresh() end
        return
    end
end