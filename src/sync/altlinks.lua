local addonName, ns = ...

ns.sync = ns.sync or {}
local altlinks = {}
ns.sync.altlinks = altlinks

local PACKET_FULL = "ALT_LINKS_FULL"
local PACKET_REQ = "REQ_ALT_LINKS"
local THROTTLE_SECONDS = 3

altlinks._lastBroadcastAt = 0
altlinks._lastRequestAt = 0
altlinks._answered = altlinks._answered or {}

local function pruneAnswered(now)
    for id, expiresAt in pairs(altlinks._answered) do
        if type(expiresAt) ~= "number" or expiresAt <= now then
            altlinks._answered[id] = nil
        end
    end
end

local function markAnswered(requestId)
    if not requestId or requestId == "" then return end
    local now = time()
    pruneAnswered(now)
    altlinks._answered[requestId] = now + 10
end

local function deepCopyAltLinks(src)
    local out = {}
    if type(src) ~= "table" then
        return out
    end

    for mainKey, group in pairs(src) do
        if type(mainKey) == "string" and type(group) == "table" then
            out[mainKey] = {
                main = group.main or mainKey,
                alts = {}
            }

            if type(group.alts) == "table" then
                for altKey, enabled in pairs(group.alts) do
                    if enabled then
                        out[mainKey].alts[altKey] = true
                    end
                end
            end
        end
    end

    return out
end

local function normalizeAltLinks(tbl)
    local out = {}
    if type(tbl) ~= "table" then
        return out
    end

    for mainKey, group in pairs(tbl) do
        local normalizedMain = ns.helpers and ns.helpers.normalizeCharacterKey and ns.helpers.normalizeCharacterKey(mainKey) or mainKey
        if normalizedMain and normalizedMain ~= "" then
            out[normalizedMain] = out[normalizedMain] or {
                main = normalizedMain,
                alts = {}
            }

            local alts = group and group.alts
            if type(alts) == "table" then
                for altKey, enabled in pairs(alts) do
                    if enabled then
                        local normalizedAlt = ns.helpers and ns.helpers.normalizeCharacterKey and ns.helpers.normalizeCharacterKey(altKey) or altKey
                        if normalizedAlt and normalizedAlt ~= "" and normalizedAlt ~= normalizedMain then
                            out[normalizedMain].alts[normalizedAlt] = true
                        end
                    end
                end
            end
        end
    end

    return out
end

function altlinks.initialize()
    if not ns.db then return end
    ns.db.altLinks = ns.db.altLinks or {}
end

function altlinks.broadcastFull(force)
    if not ns.networking or not ns.networking.SendToGuild then
        return false, "Networking not ready."
    end
    if not ns.db then
        return false, "DB not ready."
    end

    local now = GetTime()
    if not force and (now - (altlinks._lastBroadcastAt or 0)) < THROTTLE_SECONDS then
        return false, "Alt links broadcast throttled."
    end
    altlinks._lastBroadcastAt = now

    ns.db.altLinks = ns.db.altLinks or {}

    ns.networking.SendToGuild(PACKET_FULL, {
        links = deepCopyAltLinks(ns.db.altLinks),
        updatedAt = (ns.helpers and ns.helpers.nowStamp and ns.helpers.nowStamp()) or time(),
        updatedBy = (ns.globals and ns.globals.CHARACTERNAME) or UnitName("player") or "?",
    })

    return true
end

function altlinks.sendFullTo(target, requestId, force)
    if not ns.networking or not ns.networking.SendWhisper then
        return false, "Networking not ready."
    end
    if not ns.db then
        return false, "DB not ready."
    end
    if type(target) ~= "string" or target == "" then
        return false, "Invalid target."
    end

    local now = GetTime()
    if not force and (now - (altlinks._lastBroadcastAt or 0)) < THROTTLE_SECONDS then
        return false, "Alt links send throttled."
    end
    altlinks._lastBroadcastAt = now

    ns.db.altLinks = ns.db.altLinks or {}

    ns.networking.SendWhisper(PACKET_FULL, {
        requestId = requestId,
        links = deepCopyAltLinks(ns.db.altLinks),
        updatedAt = (ns.helpers and ns.helpers.nowStamp and ns.helpers.nowStamp()) or time(),
        updatedBy = (ns.globals and ns.globals.CHARACTERNAME) or UnitName("player") or "?",
    }, target)

    return true
end

function altlinks.requestFull(force)
    if not ns.networking or not ns.networking.SendToGuild then
        return false, "Networking not ready."
    end

    local now = GetTime()
    if not force and (now - (altlinks._lastRequestAt or 0)) < THROTTLE_SECONDS then
        return false, "Alt links request throttled."
    end
    altlinks._lastRequestAt = now

    local requestId = (ns.helpers and ns.helpers.makeRequestId and ns.helpers.makeRequestId("ALTLINKS"))
        or (tostring(time()) .. "-" .. tostring(math.random(1000, 9999)))

    ns.networking.SendToGuild(PACKET_REQ, {
        requestId = requestId,
        requestedAt = (ns.helpers and ns.helpers.nowStamp and ns.helpers.nowStamp()) or time(),
        requestedBy = (ns.globals and ns.globals.CHARACTERNAME) or UnitName("player") or "?",
    })

    return true
end

function altlinks.applyFull(payload, sender)
    if not ns.db then return false, "DB not ready." end
    if type(payload) ~= "table" then return false, "Invalid payload." end
    if not ns.helpers or not ns.helpers.canCharacterManageOfficerTools or not ns.helpers.canCharacterManageOfficerTools(sender) then
        return false, "Sender not allowed to sync alt links."
    end

    local requestId = tostring(payload.requestId or "")
    if requestId ~= "" then
        markAnswered(requestId)
    end

    local incoming = normalizeAltLinks(payload.links)
    local incomingUpdatedAt = tonumber(payload.updatedAt) or 0
    local localUpdatedAt = tonumber(ns.db.altLinksUpdatedAt) or 0

    if incomingUpdatedAt >= localUpdatedAt then
        ns.db.altLinks = incoming
        ns.db.altLinksUpdatedAt = incomingUpdatedAt
    end


    if ns.ui and ns.ui.altLinksFrame and ns.ui.altLinksFrame.frame and ns.ui.altLinksFrame.frame:IsShown() then
        if ns.ui.updateAltLinksUI then
            ns.ui.updateAltLinksUI()
        end
    end

    if ns.helpers and ns.helpers.playerCanViewGuildLog and ns.helpers.playerCanViewGuildLog() then
        if ns.log and ns.log.debug then
            ns.log.debug("Applied alt links sync from " .. tostring(sender))
        end
    end

    return true
end

local function getDesignatedAltLinksResponder()
    if not IsInGuild() then return nil end
    if not ns.helpers or not ns.helpers.normalizeCharacterKey or not ns.helpers.canCharacterManageOfficerTools then
        return nil
    end

    local bestKey = nil
    local bestRank = nil
    local count = GetNumGuildMembers() or 0

    for i = 1, count do
        local fullName, _, rankIndex, _, _, _, _, _, online = GetGuildRosterInfo(i)
        if fullName and online then
            local key = ns.helpers.normalizeCharacterKey(fullName) or fullName
            if key and ns.helpers.canCharacterManageOfficerTools(key) then
                rankIndex = tonumber(rankIndex) or 999

                if not bestKey
                    or rankIndex < bestRank
                    or (rankIndex == bestRank and tostring(key) < tostring(bestKey)) then
                    bestKey = key
                    bestRank = rankIndex
                end
            end
        end
    end

    return bestKey
end

local function isLocalDesignatedResponder()
    if not ns.helpers or not ns.helpers.getPlayerKey or not ns.helpers.normalizeCharacterKey then
        return false, nil
    end

    local me = ns.helpers.getPlayerKey()
    me = ns.helpers.normalizeCharacterKey(me) or me
    if not me or me == "" then
        return false, nil
    end

    local designated = getDesignatedAltLinksResponder()
    if not designated or designated == "" then
        return false, nil
    end

    return designated == me, designated
end

function altlinks.handleRequest(sender, payload)
    if not sender or sender == "" then
        return false, "Invalid sender."
    end
    if not ns.helpers or not ns.helpers.canCharacterManageOfficerTools or not ns.helpers.canCharacterManageOfficerTools((ns.globals and ns.globals.CHARACTERNAME) or UnitName("player")) then
        return false, "Local player not allowed to answer alt links requests."
    end
    if not ns.helpers or not ns.helpers.isGuildMember or not ns.helpers.isGuildMember(sender) then
        return false, "Requester is not a guild member."
    end

    local shouldAnswer, designated = isLocalDesignatedResponder()

    if not shouldAnswer then
        if ns.log and ns.log.debug then
            ns.log.debug("Skipping ALT_LINKS_FULL response. Designated responder is: " .. tostring(designated or "?"))
        end
        return false, "Another officer is designated responder: " .. tostring(designated or "?")
    end

    if ns.log and ns.log.debug then
        ns.log.debug("This client is designated alt links responder.")
    end

    local requestId = tostring(payload and payload.requestId or "")
    if requestId == "" then
        requestId = tostring(sender) .. ":" .. tostring(time())
    end

    local delay = 0.15

    C_Timer.After(delay, function()
        local ok = altlinks.sendFullTo(sender, requestId, true)
        if ok then
            markAnswered(requestId)
            if ns.log and ns.log.debug then
                ns.log.debug("Sent ALT_LINKS_FULL to " .. tostring(sender))
            end
        end
    end)

    return true
end