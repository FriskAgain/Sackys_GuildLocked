local addonName, ns = ...
local BROADCAST_MAIL_EXCEPTIONS = {}
if not ns.packets then ns.packets = {} end
ns.packets.BROADCAST_MAIL_EXCEPTIONS = BROADCAST_MAIL_EXCEPTIONS

function BROADCAST_MAIL_EXCEPTIONS.handle(sender, tx)
    if ns.sync.mailexception then
        ns.sync.mailexception._RecordTransaction(tx)
    end
end
