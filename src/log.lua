local addonName, ns = ...
local log = {}
ns.log = log
ns.guildLog = ns.guildLog or {}

local LOG_PREFIX = "[SGLK] "

local function getOrCreateSGLKChatFrame()
    local frameName = "SGLK"
    for i = 1, NUM_CHAT_WINDOWS do
        local name = GetChatWindowInfo(i)
        local frame = _G["ChatFrame" .. i]

        if name == frameName and frame and (frame:IsVisible() or frame.isDocked) then
            return frame
        end

    end
    return DEFAULT_CHAT_FRAME
end

function log.info(msg)
    local frame = getOrCreateSGLKChatFrame()
    frame:AddMessage("|cff3399ff" .. LOG_PREFIX .. "|r" .. "|cff00ff00[INFO]|r " .. "|cffffffff" .. tostring(msg) .. "|r")
end

function log.error(msg)
    local frame = getOrCreateSGLKChatFrame()
    frame:AddMessage("|cff3399ff" .. LOG_PREFIX .. "|r" .. "|cffCC0000[ERROR]|r " .. "|cffffffff" .. tostring(msg) .. "|r")
end

function log.debug(msg)
    if (ns.options.debug or false) then
        local frame = getOrCreateSGLKChatFrame()
        frame:AddMessage("|cff3399ff" .. LOG_PREFIX .. "|r" .. "|cffffff00[DEBUG]|r " .. "|cffffffff" .. tostring(msg) .. "|r")
    end
end



function ns.guildLog.send(message)

    if not ns.db then
        ns.log.error("guildLog.send: ns.db not ready")
        return
    end

    ns.db.guildLog = ns.db.guildLog or {}

    local entry = {
        message = message,
        sender = ns.globals.CHARACTERNAME,
        time = time()
    }

    table.insert(ns.db.guildLog, 1, entry)

    if ns.networking and ns.networking.SendToGuild then
        ns.networking.SendToGuild("GUILD_LOG", entry)
    end

end