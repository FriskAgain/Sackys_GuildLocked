local addonName, ns = ...
local log = {}
ns.log = log

local LOG_PREFIX = "[GuildFound] "

local function getOrCreateGuildFoundChatFrame()
    local frameName = "GuildFound"
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
    local frame = getOrCreateGuildFoundChatFrame()
    frame:AddMessage("|cff3399ff" .. LOG_PREFIX .. "|r" .. "|cff00ff00[INFO]|r " .. "|cffffffff" .. tostring(msg) .. "|r")
end

function log.error(msg)
    local frame = getOrCreateGuildFoundChatFrame()
    frame:AddMessage("|cff3399ff" .. LOG_PREFIX .. "|r" .. "|cffCC0000[ERROR]|r " .. "|cffffffff" .. tostring(msg) .. "|r")
end

function log.debug(msg)
    if (ns.options.debug or false) then
        local frame = getOrCreateGuildFoundChatFrame()
        frame:AddMessage("|cff3399ff" .. LOG_PREFIX .. "|r" .. "|cffffff00[DEBUG]|r " .. "|cffffffff" .. tostring(msg) .. "|r")
    end
end
