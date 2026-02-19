local addonName, ns = ...

local ADDON_STATUS = {}
ns.packets = ns.packets or {}
ns.packets.ADDON_STATUS = ADDON_STATUS

function ADDON_STATUS.handle(sender, payload)
    print("ADDON_STATUS handler fired for", sender)

    local name = Ambiguate(sender, "none")
    local state = payload.state
    local version = payload.version or "?"
    local now = GetTime()

    ns.networking.activeUsers = ns.networking.activeUsers or {}
    ns.db.addonStatus = ns.db.addonStatus or {}

    local user = ns.networking.activeUsers[name]

    if state == "ONLINE" then

        -- announce only if newly active
        if not user or not user.active then

            SendChatMessage(
                name .. " enabled the addon (v" .. version .. ")",
                "GUILD"
            )

        end

        -- update live memory
        ns.networking.activeUsers[name] = {
            version = version,
            active = true,
            lastSeen = now
        }

        -- ALWAYS save persistent
        print("Saved to DB:", name, ns.db.addonStatus[name])
        ns.db.addonStatus[name] = {
            version = version,
            active = true,
            lastSeen = now
        }

        if ns.ui and ns.ui.refresh then
            ns.ui.refresh()
        end



    elseif state == "OFFLINE" then

        if user and user.active then

            SendChatMessage(
                name .. " disabled the addon",
                "GUILD"
            )

        end

        -- update live memory only
        ns.networking.activeUsers[name] = {
            version = version,
            active = false,
            lastSeen = now
        }

    end

end

