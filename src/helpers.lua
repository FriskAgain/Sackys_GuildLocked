local addonName, ns = ...
local helpers = {}
ns.helpers = helpers

function helpers.getKey(name)
    if not name or name == "" then return nil end
    if name:find("-", 1, true) then
        return name
    end
    local realm = GetRealmName()
    if realm and realm ~= "" then
        return name .. "-" .. realm
    end
    return name
end

function helpers.getShort(name)
    if not name or name == "" then return nil end
    return Ambiguate(name, "none")
end

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
    --New code here
    if not IsInGuild() then
        return members
    end

 
    local numMembers = GetNumGuildMembers()

        for i = 1, numMembers do

            local name, _, _, _, _, _, _, _, online =
                GetGuildRosterInfo(i)

            if name then

                local key = helpers.getKey(name)

                if not onlineOnly or online then

                    local charData = ns.db.chars and ns.db.chars[key]
        
                    table.insert(members, {
        
                        name = key,
                        rank = rank or "",
                        rank_index = rankIndex or 0,
                        online = online and "Yes" or "No",
        
                        prof1 = charData and charData.prof1 or "-",
                        prof1Skill = charData and charData.prof1Skill or "-",
        
                        prof2 = charData and charData.prof2 or "-",
                        prof2Skill = charData and charData.prof2Skill or "-",
        
                    })
                end
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
        ["Jewelcrafting"] = true,

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

    local result = {
        prof1 = "-",
        prof1Skill = "-",
        prof2 = "-",
        prof2Skill = "-"
    }

    if profList[1] then
        result.prof1 = profList[1].name
        result.prof1Skill = profList[1].rank
    end

    if profList[2] then
        result.prof2 = profList[2].name
        result.prof2Skill = profList[2].rank
    end

    return result

end

local scanRunning = false

function helpers.scanPlayerProfessions()

    if not ns.db then return end

    local name, realm = UnitFullName("player")

    -- STANDARD KEY FORMAT
    local key = helpers.getKey(name)

    ns.db.chars[key] = ns.db.chars[key] or {}

    local prof = helpers.getPlayerProfessionColumns()

    ns.db.chars[key].prof1 = prof.prof1
    ns.db.chars[key].prof1Skill = prof.prof1Skill
    ns.db.chars[key].prof2 = prof.prof2
    ns.db.chars[key].prof2Skill = prof.prof2Skill
    ns.db.chars[key].name = name
    ns.db.chars[key].realm = realm
    ns.db.chars[key].lastSeen = time()

end


