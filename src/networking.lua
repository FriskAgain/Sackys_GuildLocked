local addonName, ns = ...
local MAX_SAFE_MSG = 3500
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

    -- Guild online cache
    networking.onlineSet = networking.onlineSet or {}

    local function refreshOnlineSet()
        wipe(networking.onlineSet)
        if not IsInGuild() then return end

        local n = GetNumGuildMembers()
        if not n or n <= 0 then return end

        for i = 1, n do
            local name, _, _, _, _, _, _, _, online = GetGuildRosterInfo(i)
            if name and online then
                local key = ns.helpers.getKey(name)
                if key then
                    networking.onlineSet[key] = true
                end
            end
        end
    end
    refreshOnlineSet()
    C_Timer.NewTicker(15, refreshOnlineSet)

    -------------------------------------------------
    -- 2. Restore persisted addon status
    -------------------------------------------------

    local now = GetTime()

    for name, data in pairs(ns.db.addonStatus or {}) do
        if type(name) == "string" and name:find("-", 1, true) and type(data) == "table" then
            networking.activeUsers[name] = networking.activeUsers[name] or {}

            networking.activeUsers[name].version = data.version
            networking.activeUsers[name].enabled = (data.enabled == true) or (data.seen == true and data.enabled ~= false)
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
        if ns.guildLog and ns.guildLog.send and ns.db then
            ns.db.profile = ns.db.profile or {}
            local nowT = time()
            local last = tonumber(ns.db.profile._lastEnableBroadcastAt or 0) or 0
            local ENABLE_COOLDOWN = 60

            if (nowT - last) >= ENABLE_COOLDOWN then
                ns.db.profile._lastEnableBroadcastAt = nowT
                local meKey = ns.helpers.getKey(ns.globals.CHARACTERNAME)
                local short = (ns.helpers.getShort(meKey) or meKey or ns.globals.CHARACTERNAME)
                ns.guildLog.send(short .. " enabled the addon (v" .. (ns.globals.ADDONVERSION or "?") .. ")", { broadcast = true })
            end
        end
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
        if not IsInGuild() then return end
        if not ns.db then return end

        ns.db.addonStatus = ns.db.addonStatus or {}
        networking.activeUsers = networking.activeUsers or {}

        local onlineSet = networking.onlineSet
        if not onlineSet then return end

        local me = ns.helpers.getKey(ns.globals and ns.globals.CHARACTERNAME)
        local now = GetTime()
        local HEARTBEAT = 30
        local GRACE = 120 -- Must be > HEARTBEAT (30s) | Give room for lag + login + reload
        local MISS_STRIKES = 2

        for key,_ in pairs (onlineSet) do
            if key ~= me then
                local s = ns.db.addonStatus[key]
                if s and s.seen == true then
                    if not s._onlineSince then
                        s._onlineSince = now
                        s._missStrikes = 0
                        ns.db.addonStatus[key] = s
                    else
                        local u = networking.activeUsers[key]
                        local lastSeen = (u and u.lastSeen) or s.lastSeen or 0
                        local sessionAge = now - (s._onlineSince or now)
                        local missing = (lastSeen == 0) or ((now - lastSeen) > GRACE)

                        if sessionAge < GRACE then
                            s._missStrikes = 0
                        else
                            if missing then
                                s._missStrikes = (s._missStrikes or 0) +1
                                if s._missStrikes >= MISS_STRIKES then
                                    if not s._missing then
                                        s._missing = true
                                        s._missingSince = now
                                        if s.enabled ~= false then
                                            s.enabled = false
                                        end
                                        if ns.guildLog and ns.guildLog.send then
                                            ns.guildLog.send((ns.helpers.getShort(key) or key) .. " is online without SGLK enabled", { broadcast = true })
                                        end
                                    end
                                end
                            else
                                s._missStrikes = 0
                                if s._missing then
                                    s._missing = nil
                                    s._missingSince = nil
                                end
                                if s.enabled ~= true then
                                    s.enabled = true
                                end
                            end
                        end
                        ns.db.addonStatus[key] = s
                    end
                end
            end
        end
        -- Clean up if someone goes offline. clears session flags so next login is clean
        for key, s in pairs(ns.db.addonStatus) do
            if type(s) == "table" and s._onlineSince and not onlineSet[key] then
                s._onlineSince = nil
                s._missing = nil
                s._missingSince = nil
                s._missStrikes = nil
                ns.db.addonStatus[key] = s
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

    if distribution == "WHISPER" then
        local sShort = Ambiguate(sender, "none")
        local sKey = (ns.helpers.getKey and ns.helpers.getKey and ns.helpers.getKey(sShort)) or sShort

        if distribution == "WHISPER" and not (ns.helpers.isGuildMember(sShort) or ns.helpers.isGuildMember(sKey)) then
            ns.log.debug("Ignored whisper from non-guild membert: " .. tostring(sender))
            return
        end
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
        local ok, err3 = pcall(packet.handle, sender, data.payload)
        if not ok then
            ns.log.error("Packet "..tostring(data.type).." failed: "..tostring(err3))
        end
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

function networking._SendMessage(packetType, payload, distribution, target)
    if not networking.Serializer or not networking.CompressLib or not networking.EncodeTable or not networking.CommHandler then
        if not networking._initWarned then
            networking._initWarned = true
            ns.log.error("Networking is not initialized.")
        end
        return
    end

    local serialized = networking.Serializer:Serialize({ type = packetType, payload = payload})
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
        local msg = "Packet too large ("..size.." bytes) - blocked:"..tostring(packetType)
        if ns.log and ns.log.warn then
            ns.log.warn(msg)
        elseif ns.log.error then
            ns.log.error(msg)
        end
        return
    end

    if distribution == "WHISPER" and type(target) == "string" then
        target = Ambiguate(target, "none")
    end
    networking.CommHandler:SendCommMessage(networking.PREFIX, encoded, distribution, target, "NORMAL")
end