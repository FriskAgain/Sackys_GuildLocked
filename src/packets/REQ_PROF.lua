local addonName, ns = ...
local REQ_PROF = {}
ns.packets = ns.packets or {}
ns.packets.REQ_PROF = REQ_PROF

function REQ_PROF.handle(sender, payload)
    if not sender then return end
    if not ns.networking or not ns.networking.SendWhisper then return end
    if not ns.helpers or not ns.helpers.getPlayerProfessionColumns then return end

    local target = Ambiguate(sender, "none")
    local tries = 0
    local MAX_TRIES = 6
    local DELAY = 1.0

    local function attempt()
        tries = tries + 1
        if ns.helpers.professionsReady then
            ns.profReady = ns.helpers.professionsReady()
        end
        if (not ns.profReady) and ns.helpers.scanPlayerProfessions then
            ns.helpers.scanPlayerProfessions()
        end

        if ns.profReady then
            local prof = ns.helpers.getPlayerProfessionColumns()
            local name, realm = UnitFullName("player")

            ns.networking.SendWhisper("SGLK_PROF_DATA", {
                name = name,
                realm = realm,
                prof1Id = prof.prof1Id,
                prof2Id = prof.prof2Id,
                prof1 = prof.prof1, prof1Skill = prof.prof1Skill,
                prof2 = prof.prof2, prof2Skill = prof.prof2Skill,
            }, target)
            return
        end

        if tries < MAX_TRIES then
            C_Timer.After(DELAY, attempt)
        else
            local prof = ns.helpers.getPlayerProfessionColumns()
            local name, realm = UnitFullName("player")
            ns.networking.SendWhisper("SGLK_PROF_DATA", {
                name = name,
                realm = realm,
                prof1Id = prof.prof1Id,
                prof2Id = prof.prof2Id,
                prof1 = prof.prof1, prof1Skill = prof.prof1Skill,
                prof2 = prof.prof2, prof2Skill = prof.prof2Skill,
            }, target)
        end
    end
    attempt()
end