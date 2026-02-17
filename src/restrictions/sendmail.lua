local addonName, ns = ...
local sendmail = {}
if not ns.restrictions then ns.restrictions = {} end
ns.restrictions.sendmail = sendmail

function sendmail.initialize()
    sendmail.hookMailInput()
end

function sendmail.hookMailInput()
    if SendMailNameEditBox then
        SendMailNameEditBox:HookScript("OnTextChanged", sendmail.validateRecipient)
    end

    if SendMailSubjectEditBox then
        SendMailSubjectEditBox:HookScript("OnTextChanged", sendmail.validateRecipient)
    end

    if SendMailBodyEditBox then
        SendMailBodyEditBox:HookScript("OnTextChanged", sendmail.validateRecipient)
    end

    if SendMailMoneyGold then
        SendMailMoneyGold:HookScript("OnTextChanged", sendmail.validateRecipient)
    end

    if SendMailMoneySilver then
        SendMailMoneySilver:HookScript("OnTextChanged", sendmail.validateRecipient)
    end

    if SendMailMoneyCopper then
        SendMailMoneyCopper:HookScript("OnTextChanged", sendmail.validateRecipient)
    end

    if SendMailSendMoneyButton then
        SendMailSendMoneyButton:HookScript("OnClick", sendmail.validateRecipient)
    end

    if SendMailCODButton then
        SendMailCODButton:HookScript("OnClick", sendmail.validateRecipient)
    end

    for i = 1, ATTACHMENTS_MAX_SEND do
        local button = _G["SendMailAttachment" .. i]
        if button then
            button:HookScript("OnReceiveDrag", sendmail.validateRecipient)
            button:HookScript("OnMouseUp", sendmail.validateRecipient)
        end
    end
end

function sendmail.validateRecipient()
    if not SendMailNameEditBox or not SendMailMailButton then return end
    SendMailMailButton:Disable()
    local target = SendMailNameEditBox:GetText()
    if not target or target == "" then
        SendMailNameEditBox:SetTextColor(1, 1, 1)
        return
    end
    local shortName = true
    local isGuildMember = ns.helpers.isGuildMember(target, shortName) or ns.helpers.isGuildMember(target, not shortName)

    -- Prüfe, ob überhaupt etwas verschickt werden soll
    local hasItem = false
    for i = 1, ATTACHMENTS_MAX_SEND do
        if GetSendMailItem(i) then hasItem = true break end
    end
    local subject = SendMailSubjectEditBox and SendMailSubjectEditBox:GetText() or ""
    local body = SendMailBodyEditBox and SendMailBodyEditBox:GetText() or ""
    local gold = tonumber(SendMailMoneyGold and SendMailMoneyGold:GetText() or "0") or 0
    local silver = tonumber(SendMailMoneySilver and SendMailMoneySilver:GetText() or "0") or 0
    local copper = tonumber(SendMailMoneyCopper and SendMailMoneyCopper:GetText() or "0") or 0

    local hasMoney = (gold > 0 or silver > 0 or copper > 0)
    local hasSubject = subject ~= ""

    local hasContent = hasItem or hasMoney

    if isGuildMember then
        SendMailNameEditBox:SetTextColor(0.3, 0.9, 0.3)
    else
        SendMailNameEditBox:SetTextColor(0.9, 0.3, 0.3)
    end

    if isGuildMember and hasSubject then
        SendMailMailButton:Enable()
    elseif not hasContent and hasSubject then
        SendMailMailButton:Enable()
    end
end
