local addonName, ns = ...
local MAX_SAFE_MSG = 240
local networking = {
    PREFIX = "SGLK01"
}
ns.networking = networking

function networking.initialize()
    ns.log.debug("Networking:Initialize() called")

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
        local fullSender = sender:find("-") and sender or (sender .. "-" .. GetRealmName())
        networking.ReceivedMessage(msg, distribution, fullSender)
    end)
end

function networking.ReceivedMessage(msg, distribution, sender)
    -- ns.log.debug("Networking:ReceivedMessage() called with distribution: " .. tostring(distribution) .. ", sender: " .. tostring(sender))
    if sender == ns.globals.CHARACTERNAME then return end -- Ignore messages from self

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
