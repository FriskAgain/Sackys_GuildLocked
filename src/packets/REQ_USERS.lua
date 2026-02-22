local addonName, ns = ...
local REQ_USERS = {}
ns.packets = ns.packets or {}
ns.packets.REQ_USERS = REQ_USERS

function REQ_USERS.handle(sender, payload)
    if not sender then return end
    if not ns.networking or not ns.networking.SendWhisper then return end

    ns.networking.SendWhisper("RSP_USERS", {
        version = ns.globals and ns.globals.ADDONVERSION or "?"
    }, sender)
end