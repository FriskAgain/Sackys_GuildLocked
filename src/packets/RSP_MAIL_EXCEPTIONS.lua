local addonName, ns = ...
local RSP_MAIL_EXCEPTIONS = {}
if not ns.packets then ns.packets = {} end
ns.packets.RSP_MAIL_EXCEPTIONS = RSP_MAIL_EXCEPTIONS

function RSP_MAIL_EXCEPTIONS.handle(sender, exceptions)
    if ns.sync.mailexception then
        ns.sync.mailexception.enqueueTransactions(exceptions)
    end
    -- if SyncManager then
    --     SyncManager:registerReceivedFromUsers(sender)
    --     SyncManager:enqueueMailExceptions(exceptions)
    -- end
end
