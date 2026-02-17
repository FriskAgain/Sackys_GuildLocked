local addonName, ns = ...
local receivemail = {
    running = false,

    _blocked = {},
    _pending = {},

    _openAll = {
        running = false,
        wrapped = {},
    },
}
if not ns.restrictions then ns.restrictions = {} end
ns.restrictions.receivemail = receivemail

local RF_DELAY = {
    start = 0.20,
    money = 0.25,
    item  = 0.25,
    idle  = 0.20,
}

local function RF_GetMaxAttach() return (ATTACHMENTS_MAX_RECEIVE or ATTACHMENTS_MAX or 12) end

local function RF_GetFreeGeneralSlots()
    local free = 0
    if C_Container and C_Container.GetContainerNumFreeSlots then
        for bag = 0, NUM_BAG_SLOTS do
            local f, family = C_Container.GetContainerNumFreeSlots(bag)
            if f and family == 0 then free = free + f end
        end
    elseif GetContainerNumFreeSlots then
        for bag = 0, NUM_BAG_SLOTS do
            local f, family = GetContainerNumFreeSlots(bag)
            if f and family == 0 then free = free + f end
        end
    end
    return free
end

function receivemail.buildMailKey(index)
    local _, _, sender, subject, money, CODAmount, _, hasItem, wasRead, _, _, _, isGM = GetInboxHeaderInfo(index)
    if not sender and not subject then return nil end
    local parts = {}
    parts[#parts+1] = sender or "<nil>"
    parts[#parts+1] = subject or "<nil>"
    parts[#parts+1] = tostring(money or 0)
    parts[#parts+1] = tostring(CODAmount or 0)
    parts[#parts+1] = hasItem and "1" or "0"
    parts[#parts+1] = wasRead and "1" or "0"
    parts[#parts+1] = isGM and "1" or "0"
    for a = 1, RF_GetMaxAttach() do
        local link = GetInboxItemLink(index, a)
        if link then
            local id = link:match("item:(%d+)")
            parts[#parts+1] = id or link
        end
    end
    return table.concat(parts, "|")
end

function receivemail.findIndexByKey(key)
    if not key then return nil end
    local n = GetInboxNumItems()
    for i = 1, n do
        if receivemail.buildMailKey(i) == key then
            return i
        end
    end
    return nil
end

local function rf_extractIndexFromArgs(...)
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if type(v) == "number" then return v end
    end
end

local function ensureWrapped(globalName, fieldName, blockerFn, logMsg)
    local current = _G[globalName]
    if type(current) ~= "function" then return end
    if receivemail[fieldName] and current == receivemail[fieldName] then return end

    local orig = current
    local wrapper = function(...)
        local idx = rf_extractIndexFromArgs(...)
        if idx and blockerFn(idx) then
            if logMsg then ns.log.error(logMsg) end
            receivemail.enforceOpenAllButtons()
            receivemail.enforceOpenMailButtons()
            return
        end
        return orig(...)
    end
    receivemail[fieldName] = wrapper
    _G[globalName] = wrapper
end

local function setButtonEnabled(btn, enabled)
    if not btn then return end
    if btn.SetEnabled then btn:SetEnabled(enabled) end
    if btn.SetAlpha then btn:SetAlpha(enabled and 1 or 0.5) end
end

function receivemail.isMailFromNPC(index, sender)
    if not sender then return false end
    local _, _, _, _, _, _, _, _, _, _, _, canReply, isGM = GetInboxHeaderInfo(index)
    if isGM then return true end
    return sender:find(" ", 1, true) ~= nil
end

function receivemail.isOnExceptionList(sender)
    if not sender then return false end
    local list = ns.sync.mailexception.getList()
    for _, entry in ipairs(list) do
        if entry.u == sender then
            return true
        end
    end
    return false
end

local function isUnknownSender(sender)
    if not sender then return true end
    local s = string.lower(sender)
    return s == "unknown" or s == "unbekannt"
end

function receivemail.isAllowed(index)
    local _, _, sender, _, money, CODAmount, _, hasItem = GetInboxHeaderInfo(index)
    if not sender or isUnknownSender(sender) then
        return false
    end
    local shortName = true
    if ns.helpers.isGuildMember(sender, shortName) then
        return true
    end
    if not hasItem and not (money and money > 0) then
        return true
    end
    if receivemail.isMailFromNPC(index, sender) then
        return true
    end
    if receivemail.isOnExceptionList(sender) then
        return true
    end
    return false
end

function receivemail.attemptReturn(index)
    local _, _, sender = GetInboxHeaderInfo(index)
    if not sender or isUnknownSender(sender) then
        local key = receivemail.buildMailKey(index)
        if key then receivemail._blocked[key] = true end
        return
    end
    local key = receivemail.buildMailKey(index)
    if not key or receivemail._blocked[key] or receivemail._pending[key] then return end
    receivemail._pending[key] = { attempts = 1 }
    ReturnInboxItem(index)
    C_Timer.After(0.5, function() receivemail.checkReturnOutcome(key) end)
end

function receivemail.checkReturnOutcome(key)
    local pend = receivemail._pending[key]
    if not pend then return end
    local idx = receivemail.findIndexByKey(key)
    if not idx then
        receivemail._pending[key] = nil
        receivemail.enforceOpenAllButtons()
        receivemail.enforceOpenMailButtons()
        return
    end
    if pend.attempts < 2 then
        pend.attempts = 2
        ReturnInboxItem(idx)
        C_Timer.After(0.5, function() receivemail.checkReturnOutcome(key) end)
        return
    end
    receivemail._pending[key] = nil
    receivemail._blocked[key] = true
    receivemail.enforceOpenAllButtons()
    receivemail.enforceOpenMailButtons()
end

function receivemail.shouldBlockOpen(index)
    if not index then return false end
    local _, _, sender = GetInboxHeaderInfo(index)
    if not sender or isUnknownSender(sender) then
        local key = receivemail.buildMailKey(index)
        if key then receivemail._blocked[key] = true end
        return true
    end
    if receivemail.isAllowed(index) then
        return false
    end
    local key = receivemail.buildMailKey(index)
    if key and not receivemail._pending[key] and not receivemail._blocked[key] then
        receivemail.attemptReturn(index)
    end
    if key and (receivemail._pending[key] or receivemail._blocked[key]) then
        return true
    end
    return false
end

function receivemail.enforceOpenMailButtons()
    if not (OpenMailFrame and OpenMailFrame:IsShown()) then return end
    local index = OpenMailFrame.openMailID
    if not index then return end
    local shouldBlock = receivemail.shouldBlockOpen(index)
    setButtonEnabled(OpenMailMoneyButton, not shouldBlock)
    for a = 1, RF_GetMaxAttach() do
        setButtonEnabled(_G["OpenMailAttachmentButton"..a], not shouldBlock)
    end
end

function receivemail._hasLoot(index)
    local _, _, _, _, money, CODAmount, _, hasItem = GetInboxHeaderInfo(index)
    if CODAmount and CODAmount > 0 then return false end
    if money and money > 0 then return true end
    if hasItem then
        for a = 1, RF_GetMaxAttach() do
            if GetInboxItemLink(index, a) then
                return true
            end
        end
    end
    return false
end

function receivemail._isProcessable(index)
    if receivemail.shouldBlockOpen(index) then return false end
    local _, _, _, _, money, _, _, hasItem = GetInboxHeaderInfo(index)
    if money and money > 0 then return true end
    if hasItem and RF_GetFreeGeneralSlots() > 0 then return true end
    return false
end

function receivemail._findNextIndex()
    local n = GetInboxNumItems()
    for i = 1, n do
        if receivemail._isProcessable(i) then
            return i
        end
    end
    return nil
end

function receivemail._step()
    if not receivemail._openAll.running then return end
    local idx = receivemail._findNextIndex()
    if not idx then
        receivemail._openAll.running = false
        receivemail.enforceOpenAllButtons()
        receivemail.enforceOpenMailButtons()
        return
    end
    local _, _, _, _, money, _, _, hasItem = GetInboxHeaderInfo(idx)
    if money and money > 0 then
        TakeInboxMoney(idx)
        C_Timer.After(RF_DELAY.money, receivemail._step)
        return
    end
    if hasItem then
        if RF_GetFreeGeneralSlots() <= 0 then
            ns.log.warn("Open All aborted: inventory full")
            receivemail._openAll.running = false
            receivemail.enforceOpenAllButtons()
            receivemail.enforceOpenMailButtons()
            return
        end
        for a = 1, RF_GetMaxAttach() do
            if GetInboxItemLink(idx, a) then
                TakeInboxItem(idx, a)
                C_Timer.After(RF_DELAY.item, receivemail._step)
                return
            end
        end
    end
    C_Timer.After(RF_DELAY.idle, receivemail._step)
end

function receivemail.openAllAllowed()
    if receivemail._openAll.running then return end
    local any = false
    do
        local n = GetInboxNumItems()
        for i = 1, n do
            if receivemail._isProcessable(i) then any = true; break end
        end
    end
    if not any then
        receivemail.enforceOpenAllButtons()
        return
    end
    receivemail._openAll.running = true
    receivemail.enforceOpenAllButtons()
    C_Timer.After(RF_DELAY.start, receivemail._step)
end

function receivemail.bindOpenAllButtons()
    local names = {
        "OpenAllMail",
        "OpenAll",
        "MailFrameOpenAll",
        "PostalOpenAllButton",
        "Postal_OpenAllButton",
    }
    for _, g in ipairs(names) do
        local btn = _G[g]
        if btn and btn.GetObjectType and btn:GetObjectType() == "Button" then
            if not receivemail._openAll.wrapped[g] then
                receivemail._openAll.wrapped[g] = true
                btn:SetScript("OnClick", function() receivemail.openAllAllowed() end)
                ns.log.debug(("Open All-Button '%s' modified, skipping blocked mails"):format(g))
            end
        end
    end
end

function receivemail.enforceOpenAllButtons()
    local running = receivemail._openAll.running
    local anyProcessable = false
    if not running then
        local n = GetInboxNumItems()
        for i = 1, n do
            if receivemail._isProcessable(i) then anyProcessable = true; break end
        end
    end
    local names = { "OpenAllMail", "OpenAll", "MailFrameOpenAll", "PostalOpenAllButton", "Postal_OpenAllButton" }
    for _, g in ipairs(names) do
        local btn = _G[g]
        if btn and btn.IsShown and btn:IsShown() then
            setButtonEnabled(btn, (not running) and anyProcessable)
        end
    end
end

function receivemail.setupHooks()
    ensureWrapped("InboxFrame_OnClick",         "_wrapped_OnClick",
        receivemail.shouldBlockOpen, "Mail blocked")
    ensureWrapped("InboxFrame_OnModifiedClick", "_wrapped_OnModifiedClick",
        receivemail.shouldBlockOpen, "Mail blocked")
    receivemail.bindOpenAllButtons()

    if not receivemail._hookedInboxUpdate and type(InboxFrame_Update) == "function" then
        hooksecurefunc("InboxFrame_Update", function()
            receivemail.bindOpenAllButtons()
            receivemail.enforceOpenAllButtons()
            receivemail.enforceOpenMailButtons()
        end)
        receivemail._hookedInboxUpdate = true
    end
    if not receivemail._hookedOpenMailUpdate and type(OpenMail_Update) == "function" then
        hooksecurefunc("OpenMail_Update", function()
            receivemail.enforceOpenMailButtons()
        end)
        receivemail._hookedOpenMailUpdate = true
    end
end

function receivemail.handle()
    receivemail.setupHooks()
    if receivemail.running then return end
    receivemail.running = true

    local inboxCount = GetInboxNumItems()
    for i = 1, inboxCount do
        local _, _, sender, subject, money, CODAmount, _, hasItem = GetInboxHeaderInfo(i)
        if not sender or isUnknownSender(sender) then
            ns.log.debug("Mail Sender error (Index " .. tostring(i) .. ")")
            local key = receivemail.buildMailKey(i)
            if key then receivemail._blocked[key] = true end
        else
            local isOk = false
            local shortName = true

            if not isOk and ns.helpers.isGuildMember(sender, shortName) then
                ns.log.debug(("Mail from %s: Guildmember"):format(sender)); isOk = true
            end

            if not isOk and not hasItem and not (money and money > 0) then
                ns.log.debug(("Mail from %s: ignored (no items/money)"):format(sender)); isOk = true
            end

            if not isOk and receivemail.isMailFromNPC(i, sender) then
                ns.log.debug(("Mail from %s: NPC/System"):format(sender)); isOk = true
            end

            if not isOk and receivemail.isOnExceptionList(sender) then
                ns.log.debug(("Mail from %s: On exception list"):format(sender)); isOk = true
            end

            if not isOk then
                ns.log.debug(("Mail from %s: Not a guild member and no exception. Returning"):format(sender))
                receivemail.attemptReturn(i)
            end
        end
    end

    receivemail.bindOpenAllButtons()
    receivemail.enforceOpenAllButtons()
    receivemail.enforceOpenMailButtons()

    receivemail.running = false
end
