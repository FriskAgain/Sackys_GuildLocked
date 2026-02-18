local addonName, ns = ...
local globals = {
    CHARACTERNAME = nil,
    GUILDNAME = nil,
    SERVERNAME = nil,
    GUILDRANK = nil,
    ADDONVERSION = nil,
}
ns.globals = globals

local function GetAddonVersion()
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        local v = C_AddOns.GetAddOnMetadata(addonName, "Version")
        if v and v ~= "" then return v end
    end
    if GetAddOnMetadata then
        local v = GetAddOnMetadata(addonName, "Version")
        if v and v ~= "" then return v end
    end
    return "dev"
end

function globals.update()
    globals.CHARACTERNAME = UnitName("player").."-"..GetRealmName()
    globals.GUILDNAME = GetGuildInfo("player")
    globals.SERVERNAME = GetRealmName()
    globals.GUILDRANK = ns.helpers.getGuildMemberRank("player")
    globals.ADDONVERSION = GetAddonVersion()
end