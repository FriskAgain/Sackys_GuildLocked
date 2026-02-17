local addonName, ns = ...
local INFO_LOGIN = {}
if not ns.packets then ns.packets = {} end
ns.packets.INFO_LOGIN = INFO_LOGIN

function INFO_LOGIN.handle(sender, payload)
    ns.networking.SendWhisper("REQ_VERSION", {}, sender)
end
