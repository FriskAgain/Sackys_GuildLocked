local addonName, ns = ...
local REQ_MAIL_EXCEPTIONS = {}
if not ns.packets then ns.packets = {} end
ns.packets.REQ_MAIL_EXCEPTIONS = REQ_MAIL_EXCEPTIONS

function REQ_MAIL_EXCEPTIONS.handle(sender, payload)
    if not ns.sync or not ns.sync.mailexception then return end
    ns.networking.SendWhisper("RSP_MAIL_EXCEPTIONS", ns.sync.mailexception.transactions or {}, sender)
end
