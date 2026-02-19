local addonName, ns = ...
local REQ_VERSION = {}
ns.packets = ns.packets or {}
ns.packets.REQ_VERSION = REQ_VERSION

local lastReply = {} -- key: sender, value: GetTime()

function REQ_VERSION.handle(sender, payload)
    local now = GetTime()
    if lastReply[sender] and (now - lastReply[sender]) < 5 then
        return
    end
    lastReply[sender] = now

    ns.networking.SendWhisper("RSP_VERSION", { version = ns.globals.ADDONVERSION }, sender)
end