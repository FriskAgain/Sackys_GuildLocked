local addonName, ns = ...

local ADDON_STATUS = {}
ns.packets = ns.packets or {}
ns.packets.ADDON_STATUS = ADDON_STATUS

function ADDON_STATUS.handle(sender, payload)
    if not payload or not payload.state then return end
    if not ns.db then return end

    local key = ns.helpers.getKey(sender)
    if not key then return end

    ns.db.chars = ns.db.chars or {}
    ns.db.addonStatus = ns.db.addonStatus or {}
    ns.db.guildLog = ns.db.guildLog or {}
    ns.networking.activeUsers = ns.networking.activeUsers or {}

    local short  = ns.helpers.getShort(sender)
    local state  = payload.state
    local version = payload.version or "?"
    local now    = GetTime()
    local prof1      = payload.prof1
    local prof1Skill = payload.prof1Skill
    local prof2      = payload.prof2
    local prof2Skill = payload.prof2Skill

    ns.db.chars[key] = ns.db.chars[key] or {}
    ns.db.chars[key].prof1 = prof1
    ns.db.chars[key].prof1Skill = prof1Skill
    ns.db.chars[key].prof2 = prof2
    ns.db.chars[key].prof2Skill = prof2Skill
    ns.db.addonStatus[key] = ns.db.addonStatus[key] or {}
    local newlyActive = not ns.db.addonStatus[key].seen

    if state == "ONLINE" then

        ns.networking.activeUsers[key] = {
            version = version,
            active = true,
            lastSeen = now,
            prof1 = prof1, prof1Skill = prof1Skill,
            prof2 = prof2, prof2Skill = prof2Skill
        }

        ns.db.addonStatus[key].version = version
        ns.db.addonStatus[key].lastSeen = now
        ns.db.addonStatus[key].seen = true
        ns.db.addonStatus[key].prof1 = prof1
        ns.db.addonStatus[key].prof1Skill = prof1Skill
        ns.db.addonStatus[key].prof2 = prof2
        ns.db.addonStatus[key].prof2Skill = prof2Skill

        if newlyActive and ns.db.profile and ns.db.profile.announceStatus then
            ns.guildLog.send(short .. " enabled the addon (v" .. version .. ")")
        end
        if ns.ui and ns.ui.refresh then ns.ui.refresh() end
        return
    end

    if state == "OFFLINE" then
        ns.networking.activeUsers[key] = ns.networking.activeUsers[key] or {}
        ns.networking.activeUsers[key].version = version
        ns.networking.activeUsers[key].active = false
        ns.db.addonStatus[key].prof1 = prof1
        ns.db.addonStatus[key].prof1Skill = prof1Skill
        ns.db.addonStatus[key].prof2 = prof2
        ns.db.addonStatus[key].prof2Skill = prof2Skill

        if newlyActive and ns.db.profile and ns.db.profile.announceStatus then
            ns.guildLog.send(short .. " enabled the addon (v" .. version .. ")")
        end
        if ns.ui and ns.ui.refresh then ns.ui.refresh() end
        return
    end
end