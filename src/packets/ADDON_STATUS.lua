local addonName, ns = ...

local ADDON_STATUS = {}
ns.packets = ns.packets or {}
ns.packets.ADDON_STATUS = ADDON_STATUS

function ADDON_STATUS.handle(sender, payload)
    if not payload or not payload.state then return end
    local key = ns.helpers.getKey(sender)
    local short = ns.helpers.getShort(sender)
    local state = payload.state
    local version = payload.version or "?"
    local now = GetTime()

    ns.db.chars = ns.db.chars or {}
    ns.db.chars[key] = ns.db.chars[key] or {}

    ns.db.chars[key].prof1 = payload.prof1
    ns.db.chars[key].prof1Skill = payload.prof1Skill

    ns.db.chars[key].prof2 = payload.prof2
    ns.db.chars[key].prof2Skill = payload.prof2Skill

    ns.networking.activeUsers = ns.networking.activeUsers or {}
    if not ns.db then return end
    ns.db.addonStatus = ns.db.addonStatus or {}

    local user = ns.networking.activeUsers[key]

    if state == "ONLINE" then
        local newlyActive = (not user) or (not user.active)
        ns.networking.activeUsers[key] = {
            version = version,
            active = true,
            lastSeen = now,
            prof1 = prof1,
            prof1Skill = prof1Skill,
            prof2 = prof2,
            prof2Skill = prof2Skill
        }
        ns.db.addonStatus[key] = {
            version = version,
            active = true,
            lastSeen = now,
            prof1 = prof1,
            prof1Skill = prof1Skill,
            prof2 = prof2,
            prof2Skill = prof2Skill
        }

        if newlyActive and ns.db.profile and ns.db.profile.announceStatus then
            SendChatMessage(short .. " enabled the addon (v" .. version .. ")", "GUILD")
        end
        if ns.ui and ns.ui.refresh then ns.ui.refresh() end

    elseif state == "OFFLINE" then

        if user and user.active and ns.db.profile and ns.db.profile.announceStatus then
            SendChatMessage(short .. " disabled the addon", "GUILD")
        end
        ns.networking.activeUsers[key] = {
            version = version,
            active = false,
            lastSeen = now
        }
        ns.db.addonStatus[key] = {
            version = version,
            active = false,
            lastSeen = now
        }
    end
end