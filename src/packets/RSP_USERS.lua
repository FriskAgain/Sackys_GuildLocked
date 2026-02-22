local addonName, ns = ...

local RSP_USERS = {}
ns.packets = ns.packets or {}
ns.packets.RSP_USERS = RSP_USERS

function RSP_USERS.handle(sender, payload)
    if not sender then return end
    if not ns.sync or not ns.sync.base or not ns.sync.base.acceptUsers then return end

    local key = (ns.helpers and ns.helpers.getKey) and ns.helpers.getKey(sender) or sender
    if not key then return end

    -- ignore self
    local me = ns.globals and ns.globals.CHARACTERNAME
    if me and ns.helpers and ns.helpers.getKey and ns.helpers.getKey(me) == key then
        return
    end

    -- store both forms (key and short) if you want
    ns.sync.base:registerActiveUser(key)
end