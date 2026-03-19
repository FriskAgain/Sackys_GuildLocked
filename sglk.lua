local addonName, ns = ...
_G[addonName] = ns
local sglk = {}
ns.sglk = sglk

function sglk.initialize()
    local version = (ns.globals and ns.globals.ADDONVERSION) or "?"
    ns.log.info("Addon loaded! (v" .. tostring(version) .. ")")
end
