local addonName, ns = ...
local helpers = {}
ns.helpers = helpers
local PROF_SPELLIDS = {
    Blacksmithing   = 2018,
    Leatherworking  = 2108,
    Alchemy         = 2259,
    Herbalism       = 2366,
    Mining          = 2575,
    Tailoring       = 3908,
    Engineering     = 4036,
    Enchanting      = 7411,
    Skinning        = 8613,
    Jewelcrafting   = 25229,
}

local function buildPrimaryNames()
    local map = {}
    for en, id in pairs(PROF_SPELLIDS) do
        local localized = GetSpellInfo(id)
        if localized and localized ~= "" then
            map[localized] = { en = en, id = id }
        end
        map[en] = { en = en, id = id }
    end
    return map
end

function helpers.nowStamp()
    if GetServerTime then
        return GetServerTime()
    end
    return time()
end

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

function helpers.getPlayerMoney()
    local copper = GetMoney()
    if type(copper) ~= "number" then
        return 0
    end
    return copper
end

function helpers.formatMoneyDelta(copper)
    copper = tonumber(copper) or 0

    local sign = ""
    if copper > 0 then
        sign = "+"
    elseif copper < 0 then
        sign = "-"
        copper = math.abs(copper)
    end

    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local copperOnly = copper % 100

    return string.format("%s%dg %ds %dc", sign, gold, silver, copperOnly)
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

    if not ns.db then
        return members
    end

    ns.db.chars = ns.db.chars or {}
    ns.db.addonStatus = ns.db.addonStatus or {}

    local numMembers = GetNumGuildMembers() or 0

    for i = 1, numMembers do
        local name, _, _, _, _, _, _, _, online = GetGuildRosterInfo(i)
        if name and name ~= "" then
            local key = helpers.getKey(name) or name
            local charData = ns.db.chars[key]
            local statusData = ns.db.addonStatus[key]

            if not onlineOnly or online then
                local money = (statusData and tonumber(statusData.money)) or 0
                local moneyDelta = (statusData and tonumber(statusData.moneyDelta)) or 0

                table.insert(members, {
                    key = key,
                    name = helpers.getShort(key) or name or key,
                    online = online and "Yes" or "No",

                    prof1 = (charData and charData.prof1) or "-",
                    prof1Skill = (charData and charData.prof1Skill) or "-",
                    prof2 = (charData and charData.prof2) or "-",
                    prof2Skill = (charData and charData.prof2Skill) or "-",

                    money = money,
                    moneyText = (helpers.formatMoney and helpers.formatMoney(money)) or "0g 0s 0c",
                    moneyDelta = moneyDelta,
                    moneyDeltaText = (helpers.formatMoneyDelta and helpers.formatMoneyDelta(moneyDelta)) or "0g 0s 0c",
                })
            end
        end
    end

    table.sort(members, function(a, b)
        return tostring(a.name or "") < tostring(b.name or "")
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

function helpers.ensureAltLinks()
    if not ns.db then return nil end
    ns.db.altLinks = ns.db.altLinks or {}
    return ns.db.altLinks
end

function helpers.normalizeCharacterKey(name)
    if not name or name == "" then return nil end
    if helpers.getKey then
        return helpers.getKey(name)
    end
    return name
end

function helpers.getAltLinks()
    if not ns.db then return {} end
    ns.db.altLinks = ns.db.altLinks or {}
    return ns.db.altLinks
end

function helpers.findAltMain(nameOrKey)
    local key = helpers.normalizeCharacterKey(nameOrKey)
    if not key then return nil end

    local altLinks = helpers.getAltLinks()

    for mainKey, group in pairs(altLinks) do
        if mainKey == key then
            return mainKey
        end
        if group and group.alts and group.alts[key] then
            return mainKey
        end
    end

    return nil
end

function helpers.getAltGroup(nameOrKey)
    local mainKey = helpers.findAltMain(nameOrKey)
    if not mainKey then return nil, nil end

    local altLinks = helpers.getAltLinks()
    return altLinks[mainKey], mainKey
end

function helpers.isMainCharacter(nameOrKey)
    local key = helpers.normalizeCharacterKey(nameOrKey)
    if not key then return false end
    return helpers.findAltMain(key) == key
end

function helpers.isAltCharacter(nameOrKey)
    local key = helpers.normalizeCharacterKey(nameOrKey)
    if not key then return false end

    local mainKey = helpers.findAltMain(key)
    return mainKey ~= nil and mainKey ~= key
end

function helpers.areLinkedAlts(a, b)
    local keyA = helpers.normalizeCharacterKey(a)
    local keyB = helpers.normalizeCharacterKey(b)
    if not keyA or not keyB then return false end

    local mainA = helpers.findAltMain(keyA)
    local mainB = helpers.findAltMain(keyB)

    return mainA ~= nil and mainA == mainB
end

function helpers.getPlayerKey()
    if ns.globals and ns.globals.CHARACTERNAME and helpers.getKey then
        return helpers.getKey(ns.globals.CHARACTERNAME)
    end
    local playerName = UnitName("player")
    if playerName and helpers.getKey then
        return helpers.getKey(playerName)
    end
    return playerName
end

function helpers.isOwnAltPair(playerNameOrKey, otherNameOrKey)
    local me = helpers.normalizeCharacterKey(playerNameOrKey)
    local other = helpers.normalizeCharacterKey(otherNameOrKey)
    if not me or not other then return false end
    if me == other then
        return false
    end

    return helpers.areLinkedAlts(me, other)
end

function helpers.isMyLinkedAlt(otherNameOrKey)
    local me = helpers.getPlayerKey()
    if not me then return false end
    return helpers.isOwnAltPair(me, otherNameOrKey)
end

function helpers.removeCharacterFromAltLinks(nameOrKey)
    local key = helpers.normalizeCharacterKey(nameOrKey)
    if not key then return false, "Invalid character." end

    local altLinks = helpers.ensureAltLinks()
    if not altLinks then return false, "DB not ready." end

    for mainKey, group in pairs(altLinks) do
        if mainKey == key then
            altLinks[mainKey] = nil
            return true
        end
        if group and group.alts and group.alts[key] then
            group.alts[key] = nil
            return true
        end
    end

    return false, "Character not found in alt links."
end

function helpers.createAltGroup(mainNameOrKey)
    local mainKey = helpers.normalizeCharacterKey(mainNameOrKey)
    if not mainKey then return false, "Invalid main character." end

    local altLinks = helpers.ensureAltLinks()
    if not altLinks then return false, "DB not ready." end

    local existingMain = helpers.findAltMain(mainKey)
    if existingMain and existingMain ~= mainKey then
        helpers.removeCharacterFromAltLinks(mainKey)
    end

    altLinks[mainKey] = altLinks[mainKey] or {
        main = mainKey,
        alts = {}
    }

    return true
end

function helpers.addAltLink(mainNameOrKey, altNameOrKey)
    local mainKey = helpers.normalizeCharacterKey(mainNameOrKey)
    local altKey = helpers.normalizeCharacterKey(altNameOrKey)

    if not mainKey or not altKey then
        return false, "Invalid character name."
    end
    if mainKey == altKey then
        return false, "Main and alt cannot be the same."
    end

    local altLinks = helpers.ensureAltLinks()
    if not altLinks then return false, "DB not ready." end
    helpers.removeCharacterFromAltLinks(altKey)
    altLinks[mainKey] = altLinks[mainKey] or {
        main = mainKey,
        alts = {}
    }

    altLinks[mainKey].alts = altLinks[mainKey].alts or {}
    altLinks[mainKey].alts[altKey] = true

    return true
end

function helpers.getAltGroupMembers(mainNameOrKey)
    local group, mainKey = helpers.getAltGroup(mainNameOrKey)
    if not group or not mainKey then return nil end

    local out = {}
    out[#out + 1] = mainKey

    if group.alts then
        for altKey in pairs(group.alts) do
            out[#out + 1] = altKey
        end
    end

    table.sort(out)
    return out
end

function helpers.getAllAltGroups()
    local altLinks = helpers.getAltLinks()
    local groups = {}

    for mainKey, group in pairs(altLinks) do
        groups[#groups + 1] = {
            main = mainKey,
            alts = group and group.alts or {}
        }
    end

    table.sort(groups, function(a, b)
        return tostring(a.main) < tostring(b.main)
    end)

    return groups
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
    local PRIMARY = buildPrimaryNames()

    local num = GetNumSkillLines and GetNumSkillLines() or 0
    for i = 1, num do
        local skillName, isHeader, _, skillRank = GetSkillLineInfo(i)
        if not isHeader and skillName then
            local info = PRIMARY[skillName]
            if info then
                table.insert(profs, {
                    name = info.en,
                    id   = info.id,
                    rank = skillRank or 0
                })
            end
        end
    end
    return profs
end


function helpers.getPlayerProfessionColumns()
    local profList = helpers.getPlayerProfessionsClassic()
    local result = {
        prof1Id = nil, prof1 = "-", prof1Skill = "-",
        prof2Id = nil, prof2 = "-", prof2Skill = "-"
    }

    if profList[1] then
        result.prof1Id = profList[1].id
        result.prof1 = profList[1].name
        result.prof1Skill = profList[1].rank
    end
    if profList[2] then
        result.prof2Id = profList[2].id
        result.prof2 = profList[2].name
        result.prof2Skill = profList[2].rank
    end

    return result
end

function helpers.professionsReady()
    local n = GetNumSkillLines and GetNumSkillLines() or 0
    if not n or n <= 0 then return false end

    local PRIMARY = buildPrimaryNames()
    for i = 1, n do
        local skillName, isHeader = GetSkillLineInfo(i)
        if not isHeader and skillName and PRIMARY[skillName] then
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
        helpers._profRetry = helpers._profRetry or 0
        if helpers._profRetry < 10 then
            helpers._profRetry = helpers._profRetry + 1
            C_Timer.After(2, function() helpers.scanPlayerProfessions() end)
        end
        return
    end
    helpers._profRetry = 0

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
    if not me or me == "" then return false end

    local rankIndex = ns.helpers and ns.helpers.getGuildMemberRank and ns.helpers.getGuildMemberRank(me)
    if type(rankIndex) ~= "number" then
        return false
    end

    local profile = ns.db.profile or {}
    local requiredRank = profile.logMinRank
    if type(requiredRank) ~= "number" then requiredRank = 2 end

    return rankIndex <= requiredRank
end

function helpers.canCharacterManageOfficerTools(nameOrKey)
    if not ns or not ns.db then return false end
    if not IsInGuild() then return false end

    local key = helpers.normalizeCharacterKey and helpers.normalizeCharacterKey(nameOrKey) or nameOrKey
    if not key or key == "" then return false end

    local short = helpers.getShort and helpers.getShort(key) or key
    local rankIndex = helpers.getGuildMemberRank and helpers.getGuildMemberRank(short)
    if type(rankIndex) ~= "number" then
        return false
    end

    local profile = ns.db.profile or {}
    local requiredRank = profile.logMinRank
    if type(requiredRank) ~= "number" then
        requiredRank = 2
    end

    return rankIndex <= requiredRank
end