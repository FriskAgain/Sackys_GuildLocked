local addonName, ns = ...

local SGLK_PROF_DATA = {}
ns.packets = ns.packets or {}
ns.packets.SGLK_PROF_DATA = SGLK_PROF_DATA

local function myKey()
    return ns.globals and ns.globals.CHARACTERNAME
end

function SGLK_PROF_DATA.handle(sender, payload)
    if not payload then return end
    if not ns.db then return end
    ns.db.chars = ns.db.chars or {}

    local key = ns.helpers.getKey(sender)
    if not key then return end

    -- Ignore self
    local me = myKey()
    if me and ns.helpers.getKey(me) == key then
        return
    end

    ns.db.chars[key] = ns.db.chars[key] or {}

    ns.db.chars[key].name = payload.name
    ns.db.chars[key].realm = payload.realm
    ns.db.chars[key].prof1 = payload.prof1
    ns.db.chars[key].prof1Skill = payload.prof1Skill
    ns.db.chars[key].prof2 = payload.prof2
    ns.db.chars[key].prof2Skill = payload.prof2Skill
    ns.db.chars[key].lastSeen = time()

    if ns.ui and ns.ui.refresh then
        ns.ui.refresh()
    end
end
