local addonName, ns = ...
local REQ_VERSION = {}
if not ns.packets then ns.packets = {} end
ns.packets.REQ_VERSION = REQ_VERSION

function REQ_VERSION.handle(sender, payload)
    -- local rankIndex = ns.helpers.getGuildMemberRank(sender)
    -- if type(rankIndex) ~= "number" or rankIndex >= 5 then return end
    ns.networking.SendWhisper("RSP_VERSION", {version = ns.globals.ADDONVERSION}, sender)
end
