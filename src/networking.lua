local addonName, ns = ...
local MAX_SAFE_MSG = 240
local networking = {
    PREFIX = "SGLK02"
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
    ns.db.chars = ns.db.chars or {}
    ns.db.guildLog = ns.db.guildLog or {}

    -- normalize persisted addonstatus
    for k, v in pairs(ns.db.addonStatus or {}) do
        if type(v) == "table" then
            -- If we have a version stored, this user has been "seen" running the adon at least once
            if (v.seen == nil) and v.version and v.version ~= "" and v.version ~= "-" then
                v.seen = true
            end
        end
    end

    -------------------------------------------------
    -- 2. Restore persisted addon status
    -------------------------------------------------

    local now = GetTime()

    for name, data in pairs(ns.db.addonStatus or {}) do
        if type(name) == "string" and name:find("-", 1, true) and type(data) == "table" then
            networking.activeUsers[name] = networking.activeUsers[name] or {}

            networking.activeUsers[name].version = data.version
            networking.activeUsers[name].enabled = (data.enabled == true) or (data.seen == true and data.enable ~= false)
            networking.activeUsers[name].active = false
            networking.activeUsers[name].lastSeen = tonumber(data.lastSeen) or now

            networking.activeUsers[name].prof1 = data.prof1 or "-"
            networking.activeUsers[name].prof1Skill = data.prof1Skill or "-"
            networking.activeUsers[name].prof2 = data.prof2 or "-"
            networking.activeUsers[name].prof2Skill = data.prof2Skill or "-"
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

        networking.ReceivedMessage(msg, distribution, fullSender)
    end)

    -------------------------------------------------
    -- 4. Register own ONLINE presence
    -------------------------------------------------

    C_Timer.After(2, function()
        local key = ns.globals.CHARACTERNAME
        local now = GetTime()

        local prof = { prof1="-", prof1Skill="-", prof2="-", prof2Skill="-" }
        if ns.profReady and ns.helpers.getPlayerProfessionColumns then
            prof = ns.helpers.getPlayerProfessionColumns()
        end

        networking.activeUsers[key] = {
            version = ns.globals.ADDONVERSION,
            active = true,
            lastSeen = now,
            prof1 = prof.prof1,
            prof1Skill = prof.prof1Skill,
            prof2 = prof.prof2,
            prof2Skill = prof.prof2Skill
        }

        if ns.db and ns.db.addonStatus then
            ns.db.addonStatus[key] = ns.db.addonStatus[key] or {}
            ns.db.addonStatus[key].version = ns.globals.ADDONVERSION
            ns.db.addonStatus[key].lastSeen = now
            ns.db.addonStatus[key].seen = true
            ns.db.addonStatus[key].enabled = true

            ns.db.addonStatus[key].prof1 = prof.prof1
            ns.db.addonStatus[key].prof1Skill = prof.prof1Skill
            ns.db.addonStatus[key].prof2 = prof.prof2
            ns.db.addonStatus[key].prof2Skill = prof.prof2Skill
        end

        networking.SendToGuild("ADDON_STATUS", {
            state = "ONLINE",
            version = ns.globals.ADDONVERSION,
            prof1 = prof.prof1,
            prof1Skill = prof.prof1Skill,
            prof2 = prof.prof2,
            prof2Skill = prof.prof2Skill
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
        local key = ns.globals and ns.globals.CHARACTERNAME
        if not key then return end

        local prof = { prof1="-", prof1Skill="-", prof2="-", prof2Skill="-" }
        if ns.profReady and ns.helpers and ns.helpers.getPlayerProfessionColumns then
            prof = ns.helpers.getPlayerProfessionColumns()
        end

        -- Update Live Cache
        networking.activeUsers[key] = networking.activeUsers[key] or {}
        local u = networking.activeUsers[key]
        u.version = ns.globals.ADDONVERSION
        u.active = true
        u.lastSeen = now
        u.prof1 = prof.prof1
        u.prof1Skill = prof.prof1Skill
        u.prof2 = prof.prof2
        u.prof2Skill = prof.prof2Skill

        -- Update DB snapshot
        if ns.db and ns.db.addonStatus then
            ns.db.addonStatus[key] = ns.db.addonStatus[key] or {}
            local s = ns.db.addonStatus[key]
            s.version = ns.globals.ADDONVERSION
            s.lastSeen = now
            s.seen = true
            s.enabled = true
            s.prof1 = prof.prof1
            s.prof1Skill = prof.prof1Skill
            s.prof2 = prof.prof2
            s.prof2Skill = prof.prof2Skill
        end

        networking.SendToGuild("ADDON_STATUS", {
            state = "ONLINE",
            version = ns.globals.ADDONVERSION,
            prof1 = prof.prof1,
            prof1Skill = prof.prof1Skill,
            prof2 = prof.prof2,
            prof2Skill = prof.prof2Skill
        })
    end)

    -------------------------------------------------
    -- 7. Detect "online but no addon heartbeat"
    -------------------------------------------------
    C_Timer.NewTicker(15, function()
        if not ns.db then return end
        ns.db.addonStatus = ns.db.addonStatus or {}

        local now = GetTime()
        local GRACE = 45 -- Seconds (Give time after login/reload)

        for key, _ in pairs(onlineSet) do
            if key ~= me then
                local u = networking.activeUsers and networking.activeUsers[key]
                local lastSeen = u and u.lastSeen or (ns.db.addonStatus[key] and ns.db.addonStatus[key].lastSeen) or 0

                if lastSeen == 0 or (now - lastSeen) > GRACE then
                    -- online in guild, but no heartbear recently => addon not running
                    ns.db.addonStatus[key] = ns.db.addonStatus[key] or {}
                    local s = ns.db.addonStatus[key]

                    if s.enabled ~= false then
                        s.enabled = false

                        --
                        if not s._missingLogged then
                            s._missingLogged = true
                            if ns.guildLog and ns.guildLog.send then
                                ns.guildLog.send(ns.helpers.getShort(key) .. " is online without SGLK enabled", { broadcast = true })
                            end
                        end

                        if ns.ui and ns.ui.refresh then ns.ui.refresh() end
                    end
                end
            end
        end
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
    if ns.options and ns.options.debug then ns.log.debug("TX "..tostring(type)) end

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
