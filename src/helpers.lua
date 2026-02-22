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
    if not IsInGuild() then
        return members
    end

    if not ns.db then return members end
    ns.db.chars = ns.db.chars or {}

    local numMembers = GetNumGuildMembers()
    for i = 1, numMembers do
        local name, _, _, _, _, _, _, _, online = GetGuildRosterInfo(i)
        if name then
            local key = helpers.getKey(name)
            if key and (not onlineOnly or online) then
                local charData = ns.db.chars[key]
                table.insert(members, {
                    key = key,
                    name = helpers.getShort(key) or key,
                    online = online and "Yes" or "No",

                    prof1 = charData and charData.prof1 or "-",
                    prof1Skill = charData and charData.prof1Skill or "-",
                    prof2 = charData and charData.prof2 or "-",
                    prof2Skill = charData and charData.prof2Skill or "-",
                })
            end
        end
    end

    table.sort(members, function(a, b)
        return (a.name or "") < (b.name or "")
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

function helpers.getGuildRosterOnlineSet()
    local online = {}
    if not IsInGuild() then return online end

    local n = GetNumGuildMembers()
    for i = 1, n do
        local name, _, _, _, _, _, _, _, isOnline = GetGuildRosterInfo(i)
        if name and isOnline then
            local key = helpers.getKey(name)
            if key then online[key] = true end
        end
    end
    return online
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

function helpers.professionsReady()
    local n = GetNumSkillLines and GetNumSkillLines() or 0
    if not n or n <= 0 then return false end

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

    for i = 1, n do
        local skillName, isHeader = GetSkillLineInfo(i)
        if not isHeader and skillName and PRIMARY_NAMES[skillName] then
            return true
        end
    end
    return false
end

local scanRunning = false

function helpers.scanPlayerProfessions()
    if not ns.db then return end

    ns.profReady = helpers.professionsReady()
    if not ns.profReady then
        return
    end

    local name, realm = UnitFullName("player")
    if not name then return end
    realm = realm or GetRealmName() or ""
    local full = (realm ~= "") and (name .. "-" .. realm) or name

    local key = helpers.getKey(full)
    if not key then return end

    ns.db.chars = ns.db.chars or {}
    ns.db.chars[key] = ns.db.chars[key] or {}

    local prof = helpers.getPlayerProfessionColumns() or { prof1="-", prof1Skill="-", prof2="-", prof2Skill="-" }

    ns.db.chars[key].prof1 = prof.prof1
    ns.db.chars[key].prof1Skill = prof.prof1Skill
    ns.db.chars[key].prof2 = prof.prof2
    ns.db.chars[key].prof2Skill = prof.prof2Skill
    ns.db.chars[key].name = name
    ns.db.chars[key].realm = realm
    ns.db.chars[key].lastSeen = time()

    local sig = table.concat({
        tostring(prof.prof1), tostring(prof.prof1Skill),
        tostring(prof.prof2), tostring(prof.prof2Skill),
    }, "|")

    local now = GetTime()

    --------------------------------------------------------------------
    -- 1) Broadcast ADDON_STATUS with profs (updates activeUsers/addonStatus/UI paths)
    --------------------------------------------------------------------
    if ns.networking and ns.networking.SendToGuild and ns.globals and ns.globals.ADDONVERSION then
        helpers._lastStatusBroadcast = helpers._lastStatusBroadcast or 0
        helpers._lastStatusSig = helpers._lastStatusSig or ""
        if sig ~= helpers._lastStatusSig or (now - helpers._lastStatusBroadcast) >= 30 then
            helpers._lastStatusBroadcast = now
            helpers._lastStatusSig = sig

            ns.networking.SendToGuild("ADDON_STATUS", {
                state = "ONLINE",
                version = ns.globals.ADDONVERSION,
                prof1 = prof.prof1,
                prof1Skill = prof.prof1Skill,
                prof2 = prof.prof2,
                prof2Skill = prof.prof2Skill
            })
        end
    end

    --------------------------------------------------------------------
    -- 2) Broadcast SGLK_PROF_DATA
    --------------------------------------------------------------------
    if ns.networking and ns.networking.SendToGuild then
        helpers._lastProfBroadcast = helpers._lastProfBroadcast or 0
        helpers._lastProfSig = helpers._lastProfSig or ""

        if sig ~= helpers._lastProfSig or (now - helpers._lastProfBroadcast) >= 30 then
            helpers._lastProfBroadcast = now
            helpers._lastProfSig = sig

            ns.networking.SendToGuild("SGLK_PROF_DATA", {
                name = name,
                realm = realm,
                prof1 = prof.prof1,
                prof1Skill = prof.prof1Skill,
                prof2 = prof.prof2,
                prof2Skill = prof.prof2Skill
            })
        end
    end
end

function helpers.playerCanViewGuildLog()
    if not ns or not ns.db then return false end
    if not IsInGuild() then return false end

    local me = ns.globals and ns.globals.CHARACTERNAME
    if not me then return false end

    local rankIndex = ns.helpers.getGuildMemberRank(me)
    if type(rankIndex) ~= "number" then return false end

    local requiredRank = (ns.db.profile and ns.db.profile.logMinRank)
    if type(requiredRank) ~= "number" then requiredRank = 2 end

    return rankIndex <= requiredRank
end