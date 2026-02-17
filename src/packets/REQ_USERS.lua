local addonName, ns = ...
local REQ_USERS = {}
if not ns.packets then ns.packets = {} end
ns.packets.REQ_USERS = REQ_USERS

function REQ_USERS.handle(sender, payload)
    ns.networking.SendWhisper("RSP_USERS", {}, sender)
end
