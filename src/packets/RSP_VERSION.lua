local addonName, ns = ...
local RSP_VERSION = {
    updateNoticeDisplayed = false
    lastNotififiedVersion = nil,
}
ns.packets = ns.packets or {}
ns.packets.RSP_VERSION = RSP_VERSION

local function isNewVersionAvailable(remoteVersion, localVersion)
    local function split(v)
        local t = {}
        v = tostring(v or "")
        for num in string.gmatch(v, "(%d+)") do
            t[#t+1] = tonumber(num)
        end
        return t
    end
    local r, l = split(remoteVersion), split(localVersion)
    for i = 1, math.max(#r, #l) do
        local rv, lv = r[i] or 0, l[i] or 0
        if rv > lv then return true end
        if rv < lv then return false end
    end
    return false
end

function RSP_VERSION.handle(sender, payload)
    local remote = tostring(payload and payload.version or "")
    local me = tostring(ns.globals and ns.globals.ADDONVERSION or "")

    local who = Ambiguate(sender, "none")
    if ns.ui and ns.ui.dataBuffer then
        ns.ui.updateFieldValue(who, "version", remote ~= "" and remote or "?")
        ns.ui.updateFieldValue(who, "addon_active", true)
    end

    if remote ~= ""
        and me ~= ""
        and isNewVersionAvailable(remote, me)
        and (RSP_VERSION.lastNotififiedVersion ~= remote)
    then
        RSP_VERSION.lastNotififiedVersion = remote
        ns.log.info("A new version is available. Please update on Curseforge.")
    end
end
