local addonName, ns = ...
local BROADCAST_MAIL_EXCEPTION = {}
if not ns.packets then ns.packets = {} end
ns.packets.BROADCAST_MAIL_EXCEPTION = BROADCAST_MAIL_EXCEPTION

function BROADCAST_MAIL_EXCEPTION.handle(sender, tx)
    if ns.sync.mailexception then
        ns.sync.mailexception._RecordTransaction(tx)
    end
end
