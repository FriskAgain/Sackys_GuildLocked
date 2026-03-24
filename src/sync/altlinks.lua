local addonName, ns = ...

ns.sync = ns.sync or {}
local altlinks = {}
ns.sync.altlinks = altlinks

local PACKET_FULL = "ALT_LINKS_FULL"
local PACKET_REQ = "REQ_ALT_LINKS"
local THROTTLE_SECONDS = 3

altlinks._lastBroadcastAt = 0
altlinks._lastRequestAt = 0

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

function altlinks.requestFull(force)
    if not ns.networking or not ns.networking.SendToGuild then
        return false, "Networking not ready."
    end

    local now = GetTime()
    if not force and (now - (altlinks._lastRequestAt or 0)) < THROTTLE_SECONDS then
        return false, "Alt links request throttled."
    end
    altlinks._lastRequestAt = now

    ns.networking.SendToGuild(PACKET_REQ, {
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

    ns.db.altLinks = normalizeAltLinks(payload.links)

    if ns.ui and ns.ui.altLinksFrame and ns.ui.altLinksFrame.frame and ns.ui.altLinksFrame.frame:IsShown() then
        if ns.ui.updateAltLinksUI then
            ns.ui.updateAltLinksUI()
        end
    end

    if ns.log and ns.log.info then
        ns.log.info("Applied alt links sync from " .. tostring(sender))
    end

    return true
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

    return altlinks.broadcastFull(true)
end