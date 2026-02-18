local addonName, ns = ...
local events = {}
ns.events = events

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("AUCTION_HOUSE_SHOW")
frame:RegisterEvent("TRADE_SHOW")
frame:RegisterEvent("TRADE_ACCEPT_UPDATE")
frame:RegisterEvent("TRADE_PLAYER_ITEM_CHANGED")
frame:RegisterEvent("TRADE_TARGET_ITEM_CHANGED")
frame:RegisterEvent("TRADE_REQUEST")
frame:RegisterEvent("MAIL_SHOW")
frame:RegisterEvent("MAIL_INBOX_UPDATE")
frame:RegisterEvent("MAIL_SEND_INFO_UPDATE")
frame:RegisterEvent("GUILD_ROSTER_UPDATE")
frame:RegisterEvent("PLAYER_DEAD")
frame:RegisterEvent("SKILL_LINES_CHANGED")

frame:SetScript("OnEvent", function(self, event, arg1, arg2)

    if event == "ADDON_LOADED" then
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then

    ns.option_defaults.initialize()

    ns.globals.update()

    ns.networking.initialize()

    ns.helpers.scanPlayerProfessions()

    ns.ui.initialize()

    ns.components.minimapbutton.create()

    C_Timer.After(2, function()

        if GuildRoster then
            GuildRoster()
        elseif C_GuildInfo and C_GuildInfo.GuildRoster then
            C_GuildInfo.GuildRoster()
        end

    end)

    self:UnregisterEvent("PLAYER_LOGIN")

    elseif event == "PLAYER_LOGOUT" then
        ns.sync.mailexception.writeTransactions()
        self:UnregisterEvent("PLAYER_LOGOUT")

    elseif event == "GUILD_ROSTER_UPDATE" then
        ns.globals.update()

        local rank = ns.helpers.getGuildMemberRank(ns.globals.CHARACTERNAME)
        if type(rank) == "number" then -- only valid in a guild
            ns.option_defaults.initialize()
            ns.sglk.initialize()
            
            ns.networking.SendToGuild("RSP_VERSION", {version = ns.globals.ADDONVERSION}, sender)
            
            ns.restrictions.sendmail.initialize()
            
            ns.sync.base.initialize()
            ns.sync.mailexception.initialize()

            self:UnregisterEvent("GUILD_ROSTER_UPDATE") -- Unregister after first valid update
        end
    elseif event == "AUCTION_HOUSE_SHOW" then
        ns.restrictions.auctionhouse.handle()
    elseif event == "TRADE_SHOW" then
        local name = TradeFrameRecipientNameText and TradeFrameRecipientNameText:GetText() or nil
        ns.log.debug("TRADE_SHOW with " .. tostring(name))
        ns.restrictions.trade.handle(name)
    elseif event == "TRADE_ACCEPT_UPDATE" or event == "TRADE_PLAYER_ITEM_CHANGED" or event == "TRADE_TARGET_ITEM_CHANGED" then
        local name = TradeFrameRecipientNameText and TradeFrameRecipientNameText:GetText() or nil
        ns.log.debug("TRADE_CHANGE with " .. tostring(name))
        ns.restrictions.trade.handle(name)
    elseif event == "TRADE_REQUEST" then
        local name = TradeFrameRecipientNameText and TradeFrameRecipientNameText:GetText() or nil
        ns.log.debug("TRADE_REQUEST with " .. tostring(name))
        ns.restrictions.trade.handle(name)
    elseif event == "MAIL_SHOW" then
        C_Timer.After(0.5, function()
            ns.restrictions.receivemail.handle()
        end)
    elseif event == "MAIL_INBOX_UPDATE" then
        C_Timer.After(0.5, function()
            ns.restrictions.receivemail.handle()
        end)
    elseif event == "MAIL_SEND_INFO_UPDATE" then
        ns.restrictions.sendmail.validateRecipient()
    elseif event == "GUILD_ROSTER_UPDATE" then

    if ns.ui and ns.ui.frame then
        ns.ui.refresh()
    end

    elseif event == "SKILL_LINES_CHANGED" then

        ns.helpers.scanPlayerProfessions()

    if ns.ui and ns.ui.frame then
        ns.ui.refresh()
    end

    elseif event == "PLAYER_DEAD" then
        local tx = {
            u = Ambiguate(ns.globals.CHARACTERNAME, 'none'),
            t = time(),
            d = 0
        }
        ns.sync.mailexception._RecordTransaction(tx)
        ns.networking.SendToGuild("BROADCAST_MAIL_EXCEPTION", tx)
    end

end)
