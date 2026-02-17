local addonName, ns = ...
local PROV_MAIL_EXCEPTIONS = {}
if not ns.packets then ns.packets = {} end
ns.packets.PROV_MAIL_EXCEPTIONS = PROV_MAIL_EXCEPTIONS

function PROV_MAIL_EXCEPTIONS.handle(sender, transactions)
    if ns.sync.mailexception then
        ns.sync.mailexception.enqueueTransactions(transactions)
    end
end
