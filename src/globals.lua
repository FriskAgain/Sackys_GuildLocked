local addonName, ns = ...
local globals = {
    CHARACTERNAME = nil,
    GUILDNAME = nil,
    SERVERNAME = nil,
    GUILDRANK = nil,
    ADDONVERSION = nil,
}
ns.globals = globals

function globals.update()
    globals.CHARACTERNAME = UnitName("player").."-"..GetRealmName()
    globals.GUILDNAME = GetGuildInfo("player")
    globals.SERVERNAME = GetRealmName()
    globals.GUILDRANK = ns.helpers.getGuildMemberRank("player")
    globals.ADDONVERSION = C_AddOns.GetAddOnMetadata(addonName, "Version")
end
globals.update()
