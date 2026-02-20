local addonName, ns = ...
local MAX_SAFE_MSG = 240
local networking = {
    PREFIX = "SGLK01"
}
ns.networking = networking

networking.activeUsers = networking.activeUsers or {}


function networking.initialize()

    -- Debug access (for /run testing)
    _G.SGLK_NS = ns

    ns.log.debug("Networking:Initialize() called")

    -------------------------------------------------
    -- 1. Ensure data tables exist
    -------------------------------------------------

    networking.activeUsers = networking.activeUsers or {}
    ns.db = ns.db or SGLKDB
    ns.db.addonStatus = ns.db.addonStatus or {}

    -------------------------------------------------
    -- 2. Restore persisted addon status
    -------------------------------------------------

    for name, data in pairs(ns.db.addonStatus) do
        if type(name) == "string" and name:find("-", 1, true) then
            networking.activeUsers[name] = {
                version = data.version,
                active = data.active,
                lastSeen = data.lastSeen or GetTime()
            }
        end
    end


    -------------------------------------------------
    -- 3. Setup AceComm
    -------------------------------------------------

    local AceAddon = LibStub("AceAddon-3.0")

    if not AceAddon:GetAddon("CommHandler", true) then
        networking.CommHandler = AceAddon:NewAddon("CommHandler", "AceComm-3.0")
    else
        networking.CommHandler = AceAddon:GetAddon("CommHandler")
    end

    networking.Serializer = LibStub("AceSerializer-3.0")
    networking.CompressLib = LibStub:GetLibrary("LibCompress")
    networking.EncodeTable = networking.CompressLib:GetAddonEncodeTable()

   networking.CommHandler:RegisterComm(networking.PREFIX, function(_, msg, distribution, sender)

        if not sender then return end

        local fullSender = sender
        if not sender:find("-", 1, true) then
            local realm = GetRealmName()
            if realm and realm ~= "" then
                fullSender = sender .. "-" .. realm
            end
        end

        networking.ReceivedMessage(msg, distribution, sender)

    end)

    -------------------------------------------------
    -- 4. Register own ONLINE presence
    -------------------------------------------------

    C_Timer.After(2, function()

        local key = ns.globals.CHARACTERNAME
        local now = GetTime()
        local prof1, prof1Skill, prof2, prof2Skill = ns.helpers.getPlayerProfessionsClassic()

        networking.activeUsers[key] = {
            version = ns.globals.ADDONVERSION,
            active = true,
            lastSeen = now,
            prof1 = prof1,
            prof1Skill = prof1Skill,
            prof2 = prof2,
            prof2Skill = prof2Skill
        }

        ns.db.addonStatus[key] = {
            version = ns.globals.ADDONVERSION,
            active = true,
            lastSeen = now,
            prof1 = prof1,
            prof1Skill = prof1Skill,
            prof2 = prof2,
            prof2Skill = prof2Skill
        }

        networking.SendToGuild("ADDON_STATUS", {
            state = "ONLINE",
            version = ns.globals.ADDONVERSION
        })

    end)

    -------------------------------------------------
    -- 5. Timeout checker (live only, no DB overwrite)
    -------------------------------------------------

    C_Timer.NewTicker(15, function()

    local now = GetTime()
    local timeout = 60

    for name, data in pairs(networking.activeUsers) do

        if not data.lastSeen then
            data.lastSeen = now
        end

        if data.active and (now - data.lastSeen) > timeout then

            data.active = false

            if ns.db and ns.db.addonStatus and ns.db.addonStatus[name] then
                ns.db.addonStatus[name].active = false
                ns.db.addonStatus[name].lastSeen = data.lastSeen
            end

            if ns.ui and ns.ui.refresh then
                ns.ui.refresh()
            end

            ns.log.debug(name .. " marked inactive (timeout)")

        end

    end

    end)




    -------------------------------------------------
    -- 6. Heartbeat (keeps others updated)
    -------------------------------------------------

C_Timer.NewTicker(30, function()

    local now = GetTime()

    local key = ns.globals.CHARACTERNAME

    local prof1, prof1Skill, prof2, prof2Skill = ns.helpers.getPlayerProfessionsClassic()

    networking.activeUsers[key] = {
        version = ns.globals.ADDONVERSION,
        active = true,
        lastSeen = now,
        prof1 = prof1,
        prof1Skill = prof1Skill,
        prof2 = prof2,
        prof2Skill = prof2Skill
    }

    if ns.db and ns.db.addonStatus then
        ns.db.addonStatus[key] = {
            version = ns.globals.ADDONVERSION,
            active = true,
            lastSeen = now,
            prof1 = prof1,
            prof1Skill = prof1Skill,
            prof2 = prof2,
            prof2Skill = prof2Skill
        }
    end

    networking.SendToGuild("ADDON_STATUS", {
        state = "ONLINE",
        version = ns.globals.ADDONVERSION
    })

end)


end


function networking.ReceivedMessage(msg, distribution, sender)
    -- Ignored self
    do
        local me = ns.globals and ns.globals.CHARACTERNAME
        if me and sender == me then return end
        if me and not sender:find("-",1,true) and Ambiguate(sender,"none") == Ambiguate(me,"none") then return end
    end

    if distribution == "WHISPER" and not ns.helpers.isGuildMember(sender) then
        ns.log.debug("Ignored whisper from non-guild member: " .. tostring(sender))
        return
    end

    -- Decode
    local ok1, decoded = pcall(networking.EncodeTable.Decode, networking.EncodeTable, msg)
    if not ok1 or not decoded then
        ns.log.error("Decode failed from " .. tostring(sender))
        return
    end

    -- Decompress
    local decompressed, err = networking.CompressLib:Decompress(decoded)
    if not decompressed then
        ns.log.error("Decompress failed: " .. tostring(err))
        return
    end

    -- Deserialize
    local ok2, data = networking.Serializer:Deserialize(decompressed)
    if not ok2 or not data or not data.type then
        ns.log.error("Deserialize failed from " .. tostring(sender))
        return
    end

    local packet = ns.packets[data.type]
    ns.log.debug("Networking: Received: " .. data.type .. " | Distribution: " .. distribution .. " | Sender: " .. sender)
    if packet and packet.handle then
        packet.handle(sender, data.payload)
    else
        ns.log.error("Unhandled packet type: " .. data.type)
    end
end

function networking.SendToGuild(type, payload)

    if not networking._SendMessage then
        return
    end

    networking._SendMessage(type, payload, "GUILD", nil)

end


function networking.SendWhisper(type, payload, target)
    networking._SendMessage(type, payload, "WHISPER", target)
end

function networking._SendMessage(type, payload, distribution, target)
    -- Sicherstellen, dass initialize() ausgeführt wurde
    if not networking.Serializer or not networking.CompressLib or not networking.EncodeTable or not networking.CommHandler then
        ns.log.error("Networking is not initialized.")
        return
    end

    -- Serialize
    local serialized = networking.Serializer:Serialize({ type = type, payload = payload})
    if not serialized then
        ns.log.error("Serialization failed")
        return
    end

    -- Compress
    local compressed, err = networking.CompressLib:Compress(serialized)
    if not compressed then
        ns.log.error("Compression failed: " .. tostring(err))
        return
    end

    -- Encode
    local encoded = networking.EncodeTable:Encode(compressed)
    if not encoded then
        ns.log.error("Encoding failed")
        return
    end

    -- Size Guard
    local size = #encoded
    if size > MAX_SAFE_MSG then
        ns.log.warn("Packet too large ("..size.." bytes) — blocked: "..tostring(type))
        return
    end

    if distribution == "WHISPER" then
        ns.log.debug("Sending "..type.." to "..tostring(target).." ("..size.."b)")
    else
        ns.log.debug("Sending "..type.." to "..distribution.." ("..size.."b)")
    end
    networking.CommHandler:SendCommMessage(networking.PREFIX, encoded, distribution, target, "NORMAL")
end
