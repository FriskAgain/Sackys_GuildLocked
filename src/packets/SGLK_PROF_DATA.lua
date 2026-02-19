local addonName, ns = ...

local SGLK_PROF_DATA = {}

if not ns.packets then ns.packets = {} end
ns.packets.SGLK_PROF_DATA = SGLK_PROF_DATA

function SGLK_PROF_DATA.handle(sender, payload)

    if sender == ns.globals.CHARACTERNAME then return end
    if not payload then return end

    ns.db.chars = ns.db.chars or {}


    local key = string.lower(Ambiguate(sender, "none"))


    ns.db.chars[key] = ns.db.chars[key] or {}

    ns.db.chars[key].name = payload.name
    ns.db.chars[key].realm = payload.realm
    ns.db.chars[key].prof1 = payload.prof1
    ns.db.chars[key].prof1Skill = payload.prof1Skill
    ns.db.chars[key].prof2 = payload.prof2
    ns.db.chars[key].prof2Skill = payload.prof2Skill
    ns.db.chars[key].lastSeen = time()

    --Data for your own character:
    local key = string.lower(Ambiguate(ns.globals.CHARACTERNAME, "none"))

    ns.db.chars[key] = {
        name = payload.name,
        realm = payload.realm,
        prof1 = payload.prof1,
        prof1Skill = payload.prof1Skill,
        prof2 = payload.prof2,
        prof2Skill = payload.prof2Skill,
        lastSeen = time()
}

end
