local addonName, ns = ...
local RSP_USERS = {}
if not ns.packets then ns.packets = {} end
ns.packets.RSP_USERS = RSP_USERS

function RSP_USERS.handle(sender, payload)
    if not ns.sync.base.acceptUsers then return end
    ns.sync.base:registerActiveUser(sender)
end
