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

    ns.networking.activeUsers = ns.networking.activeUsers or {}
    if not ns.db then return end
    ns.db.addonStatus = ns.db.addonStatus or {}

    local user = ns.networking.activeUsers[key]

    if state == "ONLINE" then
        local newlyActive = (not user) or (not user.active)
        ns.networking.activeUsers[key] = {
            version = version,
            active = true,
            lastSeen = now
        }
        ns.db.addonStatus[key] = {
            version = version,
            active = true,
            lastSeen = now
        }

        if newlyActive and ns.db.profile and ns.db.profile.announceStatus then
            SendChatMessage(short .. " enabled the addon (v" .. version .. ")", "GUILD")
        end
        if ns.ui and ns.ui.refresh then ns.ui.refresh() end

    elseif state == "OFFLINE" then

        if user and user.active and ns.db.profile and ns.db.profile.announceStatus then
            SendChatMessage(short .. " disabled the addon", "GUILD")
        end
        ns.networking.activeUsers[full] = {
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