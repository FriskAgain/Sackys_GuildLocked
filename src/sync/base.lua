local addonName, ns = ...
local base = {
    userSyncFailed = false,
    userTimeout = 15,
    acceptUsers = true,
    activeUsers = {},
    selectedUsers = {},
}
if not ns.sync then ns.sync = {} end
ns.sync.base = base

function base.initialize()
    C_Timer.After(5, function()
        ns.networking.SendToGuild("REQ_USERS", {})
        C_Timer.After(base.userTimeout, function() base.randomSelectUsers() end)
    end)
end

function base.randomSelectUsers()
    base.acceptUsers = false
    if #base.activeUsers == 0 then
        base.userSyncFailed = true
        ns.log.info("Synchronization failed. No active users found")
        return
    end

    local shuffled = { unpack(base.activeUsers) }
    for i = #shuffled, 2, -1 do
        local j = math.random(i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end
    for i = 1, math.min(3, #shuffled) do
        table.insert(base.selectedUsers, shuffled[i])
    end

    ns.log.info("Synchronization started")
    for _, user in ipairs(base.selectedUsers) do
        ns.networking.SendWhisper("REQ_MAIL_EXCEPTIONS", {}, user)
    end
end

function base:registerActiveUser(name)
    if not tContains(base.activeUsers, name) then
        table.insert(base.activeUsers, name)
        ns.log.debug("SyncBase: Active user registered: " .. tostring(name))
    end
end
