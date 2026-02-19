local addonName, ns = ...
local helpers = {}
ns.helpers = helpers

function helpers.isGuildMember(target)
    if not target or not IsInGuild() then return false end
    local targetShort = Ambiguate(target, "none")
    for i = 1, GetNumGuildMembers() do
        local name = GetGuildRosterInfo(i)
        if name and Ambiguate(name, "none") == targetShort then
            return true
        end
    end
    return false
end

function helpers.getGuildMemberData(onlineOnly)

    local members = {}

    if not ns.db or not ns.db.chars then
        return members
    end

    local realm = GetRealmName()

    -- lookup online status from guild roster
    local onlineMap = {}

    if IsInGuild() then

        local numMembers = GetNumGuildMembers()

        for i = 1, numMembers do

            local name, _, _, _, _, _, _, _, online =
                GetGuildRosterInfo(i)

            if name then

                local shortName = Ambiguate(name, "none")
                local key = shortName .. "-" .. realm

                onlineMap[key] = online

            end

        end

    end

    -- Use database as primary source
    for key, data in pairs(ns.db.chars) do

        local isOnline = onlineMap[key] or false

        if not onlineOnly or isOnline then

            table.insert(members, {

                name = data.name or key,
                rank = "",
                rank_index = 0,
                online = isOnline and "Yes" or "No",

                prof1 = data.prof1 or "-",
                prof1Skill = data.prof1Skill or "-",

                prof2 = data.prof2 or "-",
                prof2Skill = data.prof2Skill or "-",

            })

        end

    end

    -- sort by name
    table.sort(members, function(a,b)
        return a.name < b.name
    end)

    return members
end

function helpers.getGuildMemberRank(name)
    if not name or not IsInGuild() then return nil end
    local wantShort = Ambiguate(name, "none") -- strips realm from name if present.
    for i = 1, GetNumGuildMembers() do
        local memberName, _, rankIndex = GetGuildRosterInfo(i)
        if memberName then
            local memberShort = Ambiguate(memberName, "none")
            if memberShort == wantShort then
                return rankIndex
            end
        end
    end
    return nil
end

local AceSerializer = LibStub("AceSerializer-3.0")
local key = 42

function helpers.encrypt(data)
    local serialized = AceSerializer:Serialize(data)
    local result = {}
    for i = 1, #serialized do
        local byte = string.byte(serialized, i)
        result[i] = string.char(bit.bxor(byte, key))
    end
    return table.concat(result)
end

function helpers.decrypt(data)
    if type(data) ~= "string" or #data == 0 then return {} end

    local result = {}
    for i = 1, #data do
        local byte = string.byte(data, i)
        result[i] = string.char(bit.bxor(byte, key))
    end
    local decrypted = table.concat(result)
    local success, tbl = AceSerializer:Deserialize(decrypted)
    if success and type(tbl) == "table" then
        return tbl
    else
        return {}
    end
end

function helpers.getPlayerProfessionsClassic()

    local profs = {}

    -- whitelist based on skillName
    local PRIMARY_NAMES = {

        ["Blacksmithing"] = true,
        ["Leatherworking"] = true,
        ["Alchemy"] = true,
        ["Herbalism"] = true,
        ["Mining"] = true,
        ["Tailoring"] = true,
        ["Engineering"] = true,
        ["Enchanting"] = true,
        ["Skinning"] = true,

    }

    local num = GetNumSkillLines()

    for i = 1, num do

        local skillName, isHeader, _, skillRank =
            GetSkillLineInfo(i)

        if not isHeader
        and skillName
        and PRIMARY_NAMES[skillName] then

            table.insert(profs, {

                name = skillName,
                rank = skillRank or 0

            })

        end

    end

    return profs

end


function helpers.getPlayerProfessionColumns()

    local profList = helpers.getPlayerProfessionsClassic()

    local prof1 = "-"
    local prof1Skill = "-"

    local prof2 = "-"
    local prof2Skill = "-"

    if profList[1] then
        prof1 = profList[1].name
        prof1Skill = profList[1].rank
    end

    if profList[2] then
        prof2 = profList[2].name
        prof2Skill = profList[2].rank
    end

    return prof1, prof1Skill, prof2, prof2Skill

end

local scanRunning = false

function helpers.scanPlayerProfessions()

    if not ns.db then return end

    local name = UnitName("player")
    local realm = GetRealmName()

    -- STANDARD KEY FORMAT
    local key = name .. "-" .. realm

    ns.db.chars[key] = ns.db.chars[key] or {}

    local prof1, prof1Skill, prof2, prof2Skill =
        helpers.getPlayerProfessionColumns()

    ns.db.chars[key].name = name
    ns.db.chars[key].realm = realm
    ns.db.chars[key].prof1 = prof1
    ns.db.chars[key].prof1Skill = prof1Skill
    ns.db.chars[key].prof2 = prof2
    ns.db.chars[key].prof2Skill = prof2Skill
    ns.db.chars[key].lastSeen = time()

end


