local addonName, ns = ...
local base = {
    userSyncFailed = false,
    userTimeout = 15,
    acceptUsers = true,
    activeUsers = {},
    selectedUsers = {},
}
local function whisperTarget(key)
    if ns.helpers and ns.helpers.getShort then
        return ns.helpers.getShort(key)
    end
    -- fallback
    return (type(key) == "string" and key:match("^([^%-]+)")) or key
end
if not ns.sync then ns.sync = {} end
ns.sync.base = base

function base.initialize()
    -- Reset state for a clean run
    base.userSyncFailed = false
    base.acceptUsers = true
    wipe(base.activeUsers)
    wipe(base.selectedUsers)

    C_Timer.After(5, function()
        ns.networking.SendToGuild("REQ_USERS", {})
        C_Timer.After(base.userTimeout, function()
            base.randomSelectUsers()
        end)
    end)
end

function base.randomSelectUsers()
    base.acceptUsers = false
    wipe(base.selectedUsers)
    -- SOLO MODE
    if #base.activeUsers == 0 then
        base.userSyncFailed = false
        ns.log.info("Sync: No other active users found; running in solo mode (no-op).")
        return
    end

    local shuffled = { unpack(base.activeUsers) }
    for i = #shuffled, 2, -1 do
        local j = math.random(i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end
    for i = 1, math.min(3, #shuffled) do
        base.selectedUsers[#base.selectedUsers + 1] = shuffled[i]
    end

    ns.log.info("Synchronization started")
    for _, userKey in ipairs(base.selectedUsers) do
        ns.networking.SendWhisper("REQ_MAIL_EXCEPTIONS", {}, whisperTarget(userKey))
    end
end

function base:registerActiveUser(name)
    local key = (ns.helpers and ns.helpers.getKey) and ns.helpers.getKey(name) or name
    if not key then return end
    if not tContains(base.activeUsers, key) then
        table.insert(base.activeUsers, key)
        ns.log.debug("SyncBase: Active user registered: " .. tostring(key))
    end
end