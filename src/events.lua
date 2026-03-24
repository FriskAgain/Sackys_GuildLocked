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
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

local didGuildInit = false
local inviteReplyCooldown = {}
local INVITE_REPLY_COOLDOWN = 300

local function RequestGuildRoster()
    if GuildRoster then
        GuildRoster()
    elseif C_GuildInfo and C_GuildInfo.GuildRoster then
        C_GuildInfo.GuildRoster()
    end
end

local uiRefreshPending = false

local function SafeUIRefresh()
    if uiRefreshPending then return end
    if not (ns.ui and ns.ui.refresh) then return end

    uiRefreshPending = true

    C_Timer.After(0.3, function()
        uiRefreshPending = false
        if ns.ui and ns.ui.refresh then
            ns.ui.refresh()
        end
    end)
end

local guildRosterRefreshPending = false
local function QueueGuildUIRefresh()
    if guildRosterRefreshPending then return end
    guildRosterRefreshPending = true
    C_Timer.After(0.5, function()
        guildRosterRefreshPending = false
        if ns.ui and ns.ui.refresh then
            ns.ui.refresh()
        end
    end)
end

local function DelayedProfScan()
    if ns.helpers and ns.helpers.scanPlayerProfessions then
        ns.helpers.scanPlayerProfessions()
    end
end

local function ProfScanBurst()
    C_Timer.After(1.0, DelayedProfScan)
    C_Timer.After(3.0, DelayedProfScan)
    C_Timer.After(6.0, DelayedProfScan)
end

local function TryGuildInit()
    if didGuildInit then
        return true
    end
    if not IsInGuild() then
        return false
    end
    if not ns.globals or not ns.globals.CHARACTERNAME then
        return false
    end
    local rank = ns.helpers.getGuildMemberRank(ns.globals.CHARACTERNAME)
    if type(rank) ~= "number" then
        return false
    end

    didGuildInit = true
    ns.log.debug("Guild roster ready. Initializing guild systems.")
    ns.option_defaults.initialize()
    ns.sglk.initialize()
    ns.restrictions.sendmail.initialize()
    ns.sync.base.initialize()
    ns.sync.mailexception.initialize()
    ns.sync.altlinks.initialize()

    ProfScanBurst()
    C_Timer.After(12, DelayedProfScan)
    C_Timer.After(25, DelayedProfScan)
    local ver = ns.globals.ADDONVERSION or "?"
    ns.networking.SendToGuild("ADDON_STATUS", {
        state = "ONLINE",
        version = ver
    })

    C_Timer.After(1, function()
        if ns.sync and ns.sync.altlinks and ns.sync.altlinks.requestFull then
            ns.sync.altlinks.requestFull(true)
        end
    end)

    return true
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
        ns.ui.initialize()
        ns.components.minimapbutton.create()
        C_Timer.After(2, function()
            if IsInGuild() and GuildRoster then
                GuildRoster()
            end
        end)
        C_Timer.After(4, function()
            if IsInGuild() and GuildRoster then
                GuildRoster()
            end
        end)
        C_Timer.After(7, function()
            if IsInGuild() and GuildRoster then
                GuildRoster()
            end
            TryGuildInit()
            if ns.ui and ns.ui.refresh then
                ns.ui.refresh()
            end
        end)
        
        self:UnregisterEvent("PLAYER_LOGIN")
        return

    elseif event == "PLAYER_GUILD_UPDATE" then
        if IsInGuild() then
            if GuildRoster then
                GuildRoster()
            end
            C_Timer.After(1, function()
                if ns.globals and ns.globals.update then
                    ns.globals.update()
                end
                if GuildRoster then
                    GuildRoster()
                end
                TryGuildInit()
                if ns.ui and ns.ui.refresh then
                    ns.ui.refresh()
                end
            end)
            C_Timer.After(3, function()
                if GuildRoster then
                    GuildRoster()
                end
                TryGuildInit()
                if ns.ui and ns.ui.refresh then
                    ns.ui.refresh()
                end
            end)
        else
            didGuildInit = false
        end
        return

    elseif event == "PLAYER_LOGOUT" then
        if ns.sync and ns.sync.mailexception and ns.sync.mailexception.writeTransactions then
            ns.sync.mailexception.writeTransactions()
        end

        local ver = ns.globals and ns.globals.ADDONVERSION or "?"
        local meKey = (ns.helpers and ns.helpers.getKey and ns.globals and ns.globals.CHARACTERNAME)
            and ns.helpers.getKey(ns.globals.CHARACTERNAME) or nil
        local now = (ns.helpers and ns.helpers.nowStamp and ns.helpers.nowStamp()) or time()

        if meKey and ns.db and ns.db.addonStatus then
            ns.db.addonStatus[meKey] = ns.db.addonStatus[meKey] or {}
            local s = ns.db.addonStatus[meKey]
            s.seen = true
            s.version = ver
            s.lastSeen = now
            s.offlineAt = now
            s.online = false
            s._lastOfflineAt = now
        end

        if ns.networking and ns.networking.SendToGuild and ns.networking.CommHandler then
            ns.networking.SendToGuild("ADDON_STATUS", {
                state = "OFFLINE",
                version = ver
            })
        end 
        return

    elseif event == "GUILD_ROSTER_UPDATE" then
        ns.globals.update()

        if not IsInGuild() then
            return
        end

        TryGuildInit()
        QueueGuildUIRefresh()

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

            local now = GetTime()
            local cooldownKey = (ns.helpers and ns.helpers.getKey and ns.helpers.getKey(inviteName)) or inviteName
            local lastReply = inviteReplyCooldown[cooldownKey] or 0

            if (now - lastReply) >= INVITE_REPLY_COOLDOWN then
                inviteReplyCooldown[cooldownKey] = now
                if SendChatMessage then
                    SendChatMessage(
                        "This character is part of <Earned Not Bought>'s GuildFound/CraftedLocked challenge, so I only group with guildmates. We're recruiting! Fresh character required, join before leveling, in-house addon used. Whisper if interested!",
                        "WHISPER",
                        nil,
                        inviteName
                    )
                end
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

    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(2, function()
            if IsInGuild() then
                ns.log.debug("Refreshing guild roster after entering world")
                if GuildRoster then
                    GuildRoster()
                end
            end
        end)
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

    elseif event == "PLAYER_MONEY" then
        if ns.helpers and ns.helpers.getPlayerMoney and ns.helpers.getKey and ns.globals and ns.globals.CHARACTERNAME and ns.db then
            local meKey = ns.helpers.getKey(ns.globals.CHARACTERNAME)
            local nowStamp = (ns.helpers.nowStamp and ns.helpers.nowStamp()) or time()
            local money = ns.helpers.getPlayerMoney()

            ns.db.addonStatus = ns.db.addonStatus or {}
            ns.db.addonStatus[meKey] = ns.db.addonStatus[meKey] or {}

            local s = ns.db.addonStatus[meKey]
            local oldMoney = tonumber(s.money) or money

            s.prevMoney = tonumber(s.money) or money
            s.money = money
            s.moneyDelta = money - oldMoney
            s.moneyUpdatedAt = nowStamp
        end
        return

    elseif event == "PLAYER_DEAD" then
        local tx = {
            u = ns.helpers.getKey(ns.globals.CHARACTERNAME),
            t = time(),
            d = 0
        }
        ns.sync.mailexception._RecordTransaction(tx)
        ns.networking.SendToGuild("BROADCAST_MAIL_EXCEPTIONS", tx)
        return
    end

end)