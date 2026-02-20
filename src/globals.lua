local addonName, ns = ...
local globals = {
    CHARACTERNAME = nil,
    GUILDNAME = nil,
    SERVERNAME = nil,
    GUILDRANK = nil,
    ADDONVERSION = nil,
    PROFESSION = nil,
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
    globals.GUILDRANK = (ns.helpers and ns.helpers.getGuildMemberRank) and ns.helpers.getGuildMemberRank(UnitName("player")) or nil
    globals.ADDONVERSION = GetAddonVersion()
    globals.PROFESSION = (ns.helpers and ns.helpers.scanPlayerProfessions) and ns.helpers.scanPlayerProfessions(UnitName("player")) or nil
end