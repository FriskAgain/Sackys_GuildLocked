local addonName, ns = ...
local RSP_VERSION = {
    updateNoticeDisplayed = false
}
if not ns.packets then ns.packets = {} end
ns.packets.RSP_VERSION = RSP_VERSION

local function isNewVersionAvailable(remoteVersion, localVersion)
    local function split(v)
        local t = {}
        for num in string.gmatch(v, "(%d+)") do
            table.insert(t, tonumber(num))
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
    if ns.ui.dataBuffer then
        ns.ui.updateFieldValue(sender, "version", payload.version)
        ns.ui.updateFieldValue(sender, "addon_active", true)
    end

    if not RSP_VERSION.updateNoticeDisplayed and isNewVersionAvailable(payload.version, ns.globals.ADDONVERSION) then
        RSP_VERSION.updateNoticeDisplayed = true
        ns.log.info("A new version is available. Please update on curseforge.")
        C_Timer.After(1800, function()
            RSP_VERSION.updateNoticeDisplayed = false
        end)
    end
end
