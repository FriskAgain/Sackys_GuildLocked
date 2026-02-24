local addonName, ns = ...
local REQ_PROF = {}
ns.packets = ns.packets or {}
ns.packets.REQ_PROF = REQ_PROF

function REQ_PROF.handle(sender, payload)
    if not sender then return end
    if not ns.networking or not ns.networking.SendWhisper then return end
    if not ns.helpers or not ns.helpers.getPlayerProfessionColumns then return end

    local prof = ns.helpers.getPlayerProfessionColumns()
    local name, realm = UnitFullName("player")

    ns.networking.SendWhisper("SGLK_PROF_DATA", {
        name = name,
        realm = realm,
        prof1 = prof.prof1, prof1Skill = prof.prof1Skill,
        prof2 = prof.prof2, prof2Skill = prof.prof2Skill,
    }, sender)
end