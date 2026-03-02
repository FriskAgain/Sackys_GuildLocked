local addonName, ns = ...
local trade = {}
if not ns.restrictions then ns.restrictions = {} end
ns.restrictions.trade = trade

function trade.handle(name)
    local target = name or (TradeFrameRecipientNameText and TradeFrameRecipientNameText:GetText()) or UnitName("target")
    ns.log.debug("trade.handle: target=" .. tostring(target))
    if not target or target == "" then return end
    if not IsInGuild() then return end

    local tries = 0
    local MAX_TRIES = 8
    local DELAY = 0.25

    local function refreshRoster()
        if GuildRoster then
            GuildRoster()
        elseif C_GuildInfo and C_GuildInfo.GuildRoster then
            C_GuildInfo.GuildRoster()
        end
    end
    local function check()
        tries = tries + 1
        refreshRoster()

        if ns.helpers and ns.helpers.isGuildMember and ns.helpers.isGuildMember(target) then
            return
        end
        if tries < MAX_TRIES then
            C_Timer.After(DELAY, check)
            return
        end

        ns.log.error("Trade is only allowed with Guild Members.")
        if TradeFrame and TradeFrame:IsShown() then
            C_Timer.After(0.1, function()
                if CloseTrade then CloseTrade() end
            end)
        end
    end
    check()
end
