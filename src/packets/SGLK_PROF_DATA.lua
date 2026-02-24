local addonName, ns = ...

local SGLK_PROF_DATA = {}
ns.packets = ns.packets or {}
ns.packets.SGLK_PROF_DATA = SGLK_PROF_DATA

local function myKey()
    return ns.globals and ns.globals.CHARACTERNAME
end

function SGLK_PROF_DATA.handle(sender, payload)
    if type(payload) ~= "table" then return end
    if not ns.db or not ns.helpers or not ns.helpers.getKey then return end

    ns.db.chars = ns.db.chars or {}
    ns.db.addonStatus = ns.db.addonStatus or {}
    ns.networking.activeUsers = ns.networking.activeUsers or {}

    local fullFromPayload = nil
    if payload.name and payload.name ~= "" then
        if payload.realm and payload.realm ~= "" then
            fullFromPayload = payload.name .. "-" .. payload.realm
        else
            fullFromPayload = payload.name
        end
    end

    local key = ns.helpers.getKey(fullFromPayload or sender)
    if not key then return end

    -- Ignore self
    local me = ns.globals and ns.globals.CHARACTERNAME
    if me and ns.helpers.getKey(me) == key then return end

    local p1id = tonumber(payload.prof1Id)
    local p2id = tonumber(payload.prof2Id)

    local p1 = "-"
    local p2 = "-"
    if p1id then
        p1 = (ns.helpers.profNameEN and ns.helpers.profNameEN(p1id)) or "-"
    else
        p1 = payload.prof1 or "-"
    end
    if p2id then
        p2 = (ns.helpers.profNameEN and ns.helpers.profNameEN(p2id)) or "-"
    else
        p2 = payload.prof2 or "-"
    end

    local c = ns.db.chars[key] or {}
    c.name       = payload.name or c.name
    c.realm      = payload.realm or c.realm

    c.prof1Id    = p1id or c.prof1Id
    c.prof2Id    = p2id or c.prof2Id

    c.prof1      = p1
    c.prof1Skill = payload.prof1Skill or c.prof1Skill or "-"
    c.prof2      = p2
    c.prof2Skill = payload.prof2Skill or c.prof2Skill or "-"
    c.lastSeen   = time()
    ns.db.chars[key] = c

    local s = ns.db.addonStatus[key] or {}
    s.prof1Id    = p1id or s.prof1Id
    s.prof2Id    = p2id or s.prof2Id
    s.prof1      = p1
    s.prof1Skill = payload.prof1Skill or s.prof1Skill
    s.prof2      = p2
    s.prof2Skill = payload.prof2Skill or s.prof2Skill
    s.seen       = true
    ns.db.addonStatus[key] = s

    local u = ns.networking.activeUsers[key]
    if u then
        u.prof1Id    = p1id or u.prof1Id
        u.prof2Id    = p2id or u.prof2Id
        u.prof1      = p1
        u.prof1Skill = payload.prof1Skill or u.prof1Skill
        u.prof2      = p2
        u.prof2Skill = payload.prof2Skill or u.prof2Skill
    end

    if ns.ui and ns.ui.refresh then ns.ui.refresh() end
end