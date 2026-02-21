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
frame:RegisterEvent("PARTY_INVITE_REQUEST")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")

local didGuildInit = false

local function RequestGuildRoster()
    if GuildRoster then
        GuildRoster()
    elseif C_GuildInfo and C_GuildInfo.GuildRoster then
        C_GuildInfo.GuildRoster()
    end
end

local function SafeUIRefresh()
    if ns.ui and ns.ui.frame and ns.ui.frame.frame and ns.ui.frame.frame.IsShown and ns.ui.frame.frame:IsShown() then
        ns.ui.refresh()
    end
end

local function DelayedProfScan()
    if ns.helpers and ns.helpers.scanPlayerProfessions then
        ns.helpers.scanPlayerProfessions()
    end
end

local function ProfScanBurst()
    -- A small burst of retries to catch the moment profs become available.
    -- Safe even if scan already worked (Scan can throttle its own SendToGuild)
    C_Timer.After(1.0, DelayedProfScan)
    C_Timer.After(3.0, DelayedProfScan)
    C_Timer.After(6.0, DelayedProfScan)
end

frame:SetScript("OnEvent", function(self, event, arg1, arg2)
    if event == "ADDON_LOADED" then
        self:UnregisterEvent("ADDON_LOADED")
        return

    elseif event == "PLAYER_LOGIN" then
        ns.option_defaults.initialize()
        ns.globals.update()
        ns.networking.initialize()
        ns.helpers.scanPlayerProfessions()
        ProfScanBurst()
        ns.ui.initialize()
        ns.components.minimapbutton.create()
        C_Timer.After(2, RequestGuildRoster)
        self:UnregisterEvent("PLAYER_LOGIN")
        return

    elseif event == "PLAYER_LOGOUT" then
        if ns.sync and ns.sync.mailexception and ns.sync.mailexception.writeTransactions then
            ns.sync.mailexception.writeTransactions()
        end
        return

    elseif event == "GUILD_ROSTER_UPDATE" then
        ns.globals.update()

        if not IsInGuild() then
            return
        end

        if not didGuildInit then
            local rank = ns.helpers.getGuildMemberRank(ns.globals.CHARACTERNAME)
            if type(rank) == "number" then
                didGuildInit = true
                ns.log.debug("Guild roster ready. Initializing guild systems.")

                ns.option_defaults.initialize()
                ns.sglk.initialize()
                ns.restrictions.sendmail.initialize()
                ns.sync.base.initialize()
                ns.sync.mailexception.initialize()
                ns.networking.SendToGuild("ADDON_STATUS", {
                    state = "ONLINE",
                    version = ns.globals.ADDONVERSION
                })
                C_Timer.After(1.0, DelayedProfScan)
                SafeUIRefresh()
            end
        else
            SafeUIRefresh()
        end

        return

    elseif event == "GROUP_ROSTER_UPDATE" then
        if ns.restrictions and ns.restrictions.group and ns.restrictions.group.handle then
            ns.restrictions.group.handle()
        end

        return

    elseif event == "PARTY_INVITE_REQUEST" then
        local inviteName = arg1 and Ambiguate(arg1, "none") or nil
        if not inviteName then return end

        if didGuildInit and ns.helpers and ns.helpers.isGuildMember and not ns.helpers.isGuildMember(inviteName) then
            if DeclineGroup then DeclineGroup() end
            if StaticPopup_Hide then StaticPopup_Hide("PARTY_INVITE") end

            if SendChatMessage then
                SendChatMessage(
                    "This character only groups with guild members.",
                    "WHISPER",
                    nil,
                    inviteName
                )
            end
        end
        return

    elseif event == "SKILL_LINES_CHANGED" then
        events._lastSkillScan = events._lastSkillScan or 0
        local now = GetTime()
        if (now - events._lastSkillScan) >= 2 then
            events._lastSkillScan = now
            ns.helpers.scanPlayerProfessions()
            SafeUIRefresh()
        end
        return

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
        local name = (arg1 and Ambiguate(arg1, "none")) or (TradeFrameRecipientNameText and TradeFrameRecipientNameText:GetText()) or nil
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

    elseif event == "PLAYER_DEAD" then
        local tx = {
            u = Ambiguate(ns.globals.CHARACTERNAME, "none"),
            t = time(),
            d = 0
        }
        ns.sync.mailexception._RecordTransaction(tx)
        ns.networking.SendToGuild("BROADCAST_MAIL_EXCEPTIONS", tx)
        return
    end

end)