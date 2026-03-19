local addonName, ns = ...

local RSP_VERSION = {
    lastNotifiedVersion = nil,
    highestSeenVersion = nil,
    minVersionNoticeDisplayed = false,
}
ns.packets = ns.packets or {}
ns.packets.RSP_VERSION = RSP_VERSION

local function splitVersion(v)
    local t = {}
    v = tostring(v or "")
    for num in string.gmatch(v, "(%d+)") do
        t[#t + 1] = tonumber(num)
    end
    return t
end

local function compareVersions(a, b)
    local av = splitVersion(a)
    local bv = splitVersion(b)

    for i = 1, math.max(#av, #bv) do
        local x = av[i] or 0
        local y = bv[i] or 0

        if x > y then return 1 end
        if x < y then return -1 end
    end

    return 0
end

local function isNewerVersion(remoteVersion, localVersion)
    return compareVersions(remoteVersion, localVersion) > 0
end

local function isBelowMinVersion(localVersion, minVersion)
    return compareVersions(localVersion, minVersion) < 0
end

function RSP_VERSION.handle(sender, payload)
    local remote = tostring(payload and payload.version or "")
    local remoteMin = tostring(payload and payload.minVersion or "")
    local me = tostring(ns.globals and ns.globals.ADDONVERSION or "")

    local short = (ns.helpers and ns.helpers.getShort and ns.helpers.getShort(sender)) or sender
    local key = (ns.helpers and ns.helpers.getKey and sender and ns.helpers.getKey(sender)) or sender

    if ns.ui and ns.ui.dataBuffer then
        ns.ui.updateFieldValue(short, "version", remote ~= "" and remote or "?")
    end

    if ns.db then
        ns.db.addonStatus = ns.db.addonStatus or {}
        ns.db.addonStatus[key] = ns.db.addonStatus[key] or {}

        local s = ns.db.addonStatus[key]
        s.seen = true
        if remote ~= "" then
            s.version = remote
        end
        if remoteMin ~= "" then
            s.minVersion = remoteMin
        end
    end

    if remote ~= "" and me ~= "" and isNewerVersion(remote, me) then
        if not RSP_VERSION.highestSeenVersion or isNewerVersion(remote, RSP_VERSION.highestSeenVersion) then
            RSP_VERSION.highestSeenVersion = remote
            RSP_VERSION.lastNotifiedVersion = remote
            ns.log.info("A newer version of Sacky's Guild Locked is available (" .. remote .. "). Please update.")
        end
    end
    if remoteMin ~= ""
        and me ~= ""
        and isBelowMinVersion(me, remoteMin)
        and not RSP_VERSION.minVersionNoticeDisplayed
    then
        RSP_VERSION.minVersionNoticeDisplayed = true
        ns.log.error("Your addon version (" .. me .. ") is below the minimum supported version (" .. remoteMin .. "). Please update.")
    end
end