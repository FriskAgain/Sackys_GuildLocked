local addonName, ns = ...
local ui = {}
ns.ui = ui
ui._profReqLast = ui._profReqLast or {}
ui._profReqCooldown = 60 -- seconds per player

local function whisperTarget(keyOrName)
    if ns.helpers and ns.helpers.getShort then
        return ns.helpers.getShort(keyOrName)
    end
    if type(keyOrName) == "string" then
        return keyOrName:match("^([^%-]+)") or keyOrName
    end
    return keyOrName
end

local function shouldRequestProf(charData)
    if not charData then return true end

    local p1 = charData.prof1
    local p2 = charData.prof2

    local missing1 = (p1 == nil or p1 == "" or p1 == "-")
    local missing2 = (p2 == nil or p2 == "" or p2 == "-")

    return missing1 or missing2
end

function ui.initialize()
    if ui.frame then return end

    ui.frame = ns.components.windowframe
        :Create(760, 440, "SGLKMainFrame")
        :Title("Sacky's Guild Locked")
        :Draggable()
        :Resizable(760, 440)
        :EscClose()

    ui.frame.background = ui.frame.frame:CreateTexture(nil, "BACKGROUND")
    ui.frame.background:SetColorTexture(0, 0, 0, 0.3)
    ui.frame.background:SetAllPoints()

    ui.frame.frame:Hide()

    -- Officer Log Button
    local function canSeeLog()
        return (ns.helpers and ns.helpers.playerCanViewGuildLog and ns.helpers.playerCanViewGuildLog()) or false
    end

    local logBtn = CreateFrame("Button", nil, ui.frame.frame, "UIPanelButtonTemplate")
    logBtn:SetSize(100, 22)
    logBtn:SetPoint("TOPRIGHT", ui.frame.frame, "TOPRIGHT", -70, -30)
    logBtn:SetText("Officer Log")

    logBtn:SetScript("OnClick", function()
        if ns.ui and ns.ui.toggleGuildLog then
            ns.ui.toggleGuildLog()
        end
    end)

    if not canSeeLog() then
        logBtn:Hide()
    end
    ui._officerLogBtn = logBtn

    local altBtn = CreateFrame("Button", nil, ui.frame.frame, "UIPanelButtonTemplate")
    altBtn:SetSize(100, 22)
    altBtn:SetPoint("TOPRIGHT", ui.frame.frame, "TOPRIGHT", -180. -30)
    altBtn:SetText("Alt Links")
    altBtn:SetScript("OnClick", function()
        if ns.ui and ns.ui.toggleAltLinks then
            ns.ui.toggleAltLinks()
        end
    end)
    if not canSeeLog() then
        altBtn:Hide()
    end
    ui.altLinksBtn = altBtn

    local memberlist = CreateFrame("Frame", nil, ui.frame.frame)
    memberlist:SetPoint("TOPLEFT", ui.frame.frame, "TOPLEFT", 12, -58)
    memberlist:SetPoint("BOTTOMRIGHT", ui.frame.frame, "BOTTOMRIGHT", -12, 12)

    local metadata = {
        sort = {
            col1 = { field = "online", order = "desc" },
            col2 = { field = "name", order = "asc" }
        },

        col1 = {
            header = "Name",
            field = "name",
            minWidth = 140
        },

        col2 = {
            header = "Online",
            field = "online",
            width = 70
        },

        col3 = {
            header = "Profession 1",
            field = "prof1",
            minWidth = 120
        },

        col4 = {
            header = "Skill",
            field = "prof1Skill",
            width = 70
        },

        col5 = {
            header = "Profession 2",
            field = "prof2",
            minWidth = 120
        },

        col6 = {
            header = "Skill",
            field = "prof2Skill",
            width = 70
        },

        col7 = {
            header = "Addon Active",
            field = "addon_active",
            width = 110
        }
    }

    local showOnlineOnly = false

    if IsInGuild and IsInGuild() and GuildRoster then
        GuildRoster()
    end
    ui._memberlistFrame = memberlist
    ui._memberMetadata = metadata
    ui._tableBuilt = false
    ui.dataBuffer = ns.helpers.getGuildMemberData(showOnlineOnly)
end

function ui.buildMemberTable()
    if ui._tableBuilt then return true end
    if not ui._memberlistFrame or not ui._memberMetadata then return false end
    local w = ui._memberlistFrame:GetWidth() or 0
    if w <= 0 and ui.frame and ui.frame.frame then
        ui._memberlistFrame:ClearAllPoints()
        ui._memberlistFrame:SetPoint("TOPLEFT", ui.frame.frame, "TOPLEFT", 12, -58)
        ui._memberlistFrame:SetPoint("BOTTOMRIGHT", ui.frame.frame, "BOTTOMRIGHT", -12, 12)
        w = ui._memberlistFrame:GetWidth() or 0
    end
    if w <= 0 then
        return false
    end
    ui.memberTable = ns.components.tablev2:new(
        ui._memberlistFrame,
        ui._memberMetadata,
        {},
        20
    )

    ui.frame.frame.memberTable = ui.memberTable
    ui._tableBuilt = true
    return true
end

function ui.toggleWindow()
    if ui.frame.frame:IsShown() then
        ui.frame.frame:Hide()
        if ui.refreshTicker then
            ui.refreshTicker:Cancel()
            ui.refreshTicker = nil
        end
    else
        ui.frame.frame:Show()
        ui.frame.frame:Raise()

        local function tryBuildAndRefresh(attempt)
            attempt = attempt or 1
            if ns.ui and ns.ui.buildMemberTable and not ns.ui.memberTable then
                ns.ui.buildMemberTable()
            end
            if ns.ui and ns.ui.memberTable and ns.ui.memberTable.container then
                local w = ns.ui.memberTable.container:GetWidth() or 0
                if w > 0 then
                    if ns.ui.refresh then
                        ns.ui.refresh()
                    end
                    return
                end
            end
            if attempt < 20 then
                C_Timer.After(0.1, function()
                    tryBuildAndRefresh(attempt + 1)
                end)
            else
                if ns.ui.refresh then
                    ns.ui.refresh()
                end
            end
        end
        C_Timer.After(0.05, function()
            tryBuildAndRefresh(1)
        end)
    end
end

function ui.refresh()
    if not ui.frame then return end
    if ui._refreshPending then return end

    ui._refreshPending = true

    C_Timer.After(0.2, function()
        ui._refreshPending = false

        local showOnlineOnly = false

        ui.dataBuffer = ui.updateMemberList(showOnlineOnly)

        ui._rosterRetryCount = ui._rosterRetryCount or 0
        if IsInGuild and IsInGuild() and (#(ui.dataBuffer or {}) == 0) then
            if ui._rosterRetryCount < 5 then
                ui._rosterRetryCount = ui._rosterRetryCount + 1

                if GuildRoster then
                    GuildRoster()
                end

                C_Timer.After(1, function()
                    if ns.ui and ns.ui.refresh then
                        ns.ui.refresh()
                    end
                end)
            end
        else
            ui._rosterRetryCount = 0
        end

        ui._lastReqVersion = ui._lastReqVersion or 0
        local now = GetTime()

        if now - ui._lastReqVersion >= 30 then
            ui._lastReqVersion = now
            ns.networking.SendToGuild("REQ_VERSION", {})
        end

        if not ui.memberTable and ui.buildMemberTable then
            ui.buildMemberTable()
        end
        if ui.memberTable and ui.memberTable.container then
            local w = ui.memberTable.container:GetWidth() or 0
            if w > 0 then
                ui.memberTable.data = ui.dataBuffer or {}
                ui.memberTable:refresh(true)
            else
                C_Timer.After(0.1, function()
                    if ns.ui and ns.ui.memberTable and ns.ui.memberTable.container then
                        local retryW = ns.ui.memberTable.container:GetWidth() or 0
                        if retryW > 0 then
                            ns.ui.memberTable.data = ns.ui.dataBuffer or {}
                            ns.ui.memberTable:refresh(true)
                        end
                    end
                end)
            end
        end

        if ui._officerLogBtn and ns.helpers and ns.helpers.playerCanViewGuildLog then
            if ns.helpers.playerCanViewGuildLog() then
                ui._officerLogBtn:Show()
            else
                ui._officerLogBtn:Hide()
            end
        end
    end)
end

function ui.ensureGuildLogUI()
    if ui.guildLogFrame then return end
    if ns.helpers and ns.helpers.playerCanViewGuildLog and not ns.helpers.playerCanViewGuildLog() then
        return
    end

    ui.guildLogFrame = ns.components.windowframe
        :Create(820, 500, "SGLKGuildLogFrame")
        :Title("SGLK Officer Log")
        :Draggable()
        :Resizable(700, 380)
        :EscClose()

    local logFrame = ui.guildLogFrame.frame
    logFrame:ClearAllPoints()
    if ui.frame and ui.frame.frame then
        logFrame:SetPoint("TOPLEFT", ui.frame.frame, "TOPRIGHT", 12, 0)
    else
        logFrame:SetPoint("CENTER", UIParent, "CENTER", 120, 0)
    end

    logFrame:SetClampedToScreen(true)
    logFrame:Hide()

    logFrame.background = logFrame:CreateTexture(nil, "BACKGROUND")
    logFrame.background:SetColorTexture(0, 0, 0, 0.3)
    logFrame.background:SetAllPoints()

    local holder = CreateFrame("Frame", nil, logFrame)
    holder:SetPoint("TOPLEFT", logFrame, "TOPLEFT", 12, -58)
    holder:SetPoint("BOTTOMRIGHT", logFrame, "BOTTOMRIGHT", -12, 12)

    local meta = {
        sort = {
            col1 = { field = "ts", order = "desc" }
        },
        col1 = {
            header = "Time",
            field = "time",
            width = 135
        },
        col2 = {
            header = "Sender",
            field = "sender",
            width = 140
        },
        col3 = {
            header = "Message",
            field = "message"
        }
    }

    ui.guildLogTable = ns.components.tablev2:new(holder, meta, {}, 18)

    local clearBtn = CreateFrame("Button", nil, logFrame, "UIPanelButtonTemplate")
    clearBtn:SetSize(70, 22)
    clearBtn:SetPoint("TOPRIGHT", logFrame, "TOPRIGHT", -70, -30)
    clearBtn:SetText("Clear")
    clearBtn:SetScript("OnClick", function()
        if not ns.db then return end
        ns.db.guildLog = ns.db.guildLog or {}
        wipe(ns.db.guildLog)
        if ui.updateGuildLog then
            ui.updateGuildLog()
        end
    end)
end

function ui.ensureAltLinksUI()
    if ui.altLinksFrame then return end
    if ns.helpers and ns.helpers.playerCanViewGuildLog and not ns.helpers.playerCanViewGuildLog() then
        return
    end

    ui.altLinksFrame = ns.components.windowframe
        :Create(700, 520, "SGLKAltLinksFrame")
        :Title("SGLK Alt Links")
        :Draggable()
        :Resizable(560, 380)
        :EscClose()

    local frame = ui.altLinksFrame.frame
    frame:ClearAllPoints()

    if ui.frame and ui.frame.frame then
        frame:SetPoint("TOPLEFT", ui.frame.frame, "TOPRIGHT", 12, -110)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 180, 0)
    end

    frame:SetClampedToScreen(true)
    frame:Hide()

    frame.background = frame:CreateTexture(nil, "BACKGROUND")
    frame.background:SetColorTexture(0, 0, 0, 0.3)
    frame.background:SetAllPoints()

    local mainLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mainLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -34)
    mainLabel:SetText("Main Character")

    local altLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    altLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -84)
    altLabel:SetText("Alt Character")

    local mainBox = CreateFrame("EditBox", "SGLKAltLinksMainBox", frame, "InputBoxTemplate")
    mainBox:SetSize(220, 24)
    mainBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -52)
    mainBox:SetAutoFocus(false)
    mainBox:SetMaxLetters(80)

    local altBox = CreateFrame("EditBox", "SGLKAltLinksAltBox", frame, "InputBoxTemplate")
    altBox:SetSize(220, 24)
    altBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -102)
    altBox:SetAutoFocus(false)
    altBox:SetMaxLetters(80)

    ui._altLinksMainBox = mainBox
    ui._altLinksAltBox = altBox

    local createBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    createBtn:SetSize(110, 24)
    createBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 260, -52)
    createBtn:SetText("Create Group")

    local addBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    addBtn:SetSize(110, 24)
    addBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 380, -52)
    addBtn:SetText("Add Alt")

    local removeBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    removeBtn:SetSize(110, 24)
    removeBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 500, -52)
    removeBtn:SetText("Remove Char")

    local refreshBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    refreshBtn:SetSize(110, 24)
    refreshBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 260, -102)
    refreshBtn:SetText("Refresh")

    local scrollFrame = CreateFrame("ScrollFrame", "SGLKAltLinksScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -145)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -34, 16)

    local editBox = CreateFrame("EditBox", "SGLKAltLinksDisplayBox", scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetWidth(620)
    editBox:SetAutoFocus(false)
    editBox:EnableMouse(true)
    editBox:SetTextInsets(4, 4, 4, 4)

    scrollFrame:SetScrollChild(editBox)

    ui._altLinksScrollFrame = scrollFrame
    ui._altLinksDisplayBox = editBox

    local function refreshDisplay()
        ui.updateAltLinksUI()
    end

    createBtn:SetScript("OnClick", function()
        local mainText = ui._altLinksMainBox and ui._altLinksMainBox:GetText() or ""
        if not mainText or mainText == "" then
            if ns.log and ns.log.error then
                ns.log.error("Enter a main character first.")
            end
            return
        end

        local ok, err = ns.helpers.createAltGroup(mainText)
        if ok then
            if ns.log and ns.log.info then
                ns.log.info("Created alt group for " .. tostring(mainText))
            end
            refreshDisplay()
        else
            if ns.log and ns.log.error then
                ns.log.error(tostring(err or "Failed to create alt group."))
            end
        end
    end)

    addBtn:SetScript("OnClick", function()
        local mainText = ui._altLinksMainBox and ui._altLinksMainBox:GetText() or ""
        local altText = ui._altLinksAltBox and ui._altLinksAltBox:GetText() or ""

        if mainText == "" or altText == "" then
            if ns.log and ns.log.error then
                ns.log.error("Enter both a main character and an alt character.")
            end
            return
        end

        local ok, err = ns.helpers.addAltLink(mainText, altText)
        if ok then
            if ns.log and ns.log.info then
                ns.log.info("Linked alt " .. tostring(altText) .. " to main " .. tostring(mainText))
            end
            refreshDisplay()
        else
            if ns.log and ns.log.error then
                ns.log.error(tostring(err or "Failed to link alt."))
            end
        end
    end)

    removeBtn:SetScript("OnClick", function()
        local targetText = ui._altLinksAltBox and ui._altLinksAltBox:GetText() or ""
        if targetText == "" then
            targetText = ui._altLinksMainBox and ui._altLinksMainBox:GetText() or ""
        end

        if targetText == "" then
            if ns.log and ns.log.error then
                ns.log.error("Enter a character to remove.")
            end
            return
        end

        local ok, err = ns.helpers.removeCharacterFromAltLinks(targetText)
        if ok then
            if ns.log and ns.log.info then
                ns.log.info("Removed " .. tostring(targetText) .. " from alt links.")
            end
            refreshDisplay()
        else
            if ns.log and ns.log.error then
                ns.log.error(tostring(err or "Failed to remove character from alt links."))
            end
        end
    end)

    refreshBtn:SetScript("OnClick", refreshDisplay)
end

function ui.updateAltLinksUI()
    if not ui._altLinksDisplayBox then return end
    if not ns.helpers or not ns.helpers.getAllAltGroups then return end

    local lines = {}
    local groups = ns.helpers.getAllAltGroups() or {}

    if #groups == 0 then
        lines[#lines + 1] = "No alt groups defined."
    else
        for _, group in ipairs(groups) do
            local mainShort = (ns.helpers.getShort and ns.helpers.getShort(group.main)) or group.main
            lines[#lines + 1] = mainShort .. " [" .. tostring(group.main) .. "]"

            local altKeys = {}
            if group.alts then
                for altKey in pairs(group.alts) do
                    altKeys[#altKeys + 1] = altKey
                end
            end
            table.sort(altKeys)

            if #altKeys == 0 then
                lines[#lines + 1] = "  - (no alts)"
            else
                for _, altKey in ipairs(altKeys) do
                    local altShort = (ns.helpers.getShort and ns.helpers.getShort(altKey)) or altKey
                    lines[#lines + 1] = "  - " .. altShort .. " [" .. altKey .. "]"
                end
            end

            lines[#lines + 1] = ""
        end
    end

    local text = table.concat(lines, "\n")
    ui._altLinksDisplayBox:SetText(text)
    ui._altLinksDisplayBox:SetCursorPosition(0)
end

function ui.toggleAltLinks()
    ui.ensureAltLinksUI()
    if not ui.altLinksFrame then
        if ns.log and ns.log.error then
            ns.log.error("No permission to manage alt links.")
        end
        return
    end

    local frame = ui.altLinksFrame.frame
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
        frame:Raise()
        ui.updateAltLinksUI()
    end
end

function ui.toggleGuildLog()
    ui.ensureGuildLogUI()
    if not ui.guildLogFrame then
        if ns.log and ns.log.error then
            ns.log.error("No permission to view guild log.")
        end
        return
    end
    local frame = ui.guildLogFrame.frame
    if frame:IsShown() then
        frame:Hide()
    else
        if InCombatLockdown and InCombatLockdown() then
            if ns.log and ns.log.info then
                ns.log.info("Cannot open Officer Log during combat.")
            end
            return
        end
        frame:Show()
        frame:Raise()
        if ui.updateGuildLog then
            ui.updateGuildLog()
        end
    end
end

function ui.updateMemberList(showOnlineOnly)
    local data = ns.helpers.getGuildMemberData(showOnlineOnly)

    ns.networking.activeUsers = ns.networking.activeUsers or {}
    if not ns.db then return data end
    ns.db.addonStatus = ns.db.addonStatus or {}
    ns.db.chars = ns.db.chars or {}
    local now = GetTime()

    for _, member in ipairs(data) do
        local key = member.key
        local live  = key and ns.networking.activeUsers[key] or nil
        local saved = key and ns.db.addonStatus[key] or nil
        local charData = key and ns.db.chars[key] or nil

        local v = "-"
        if live and live.version and live.version ~= "" then
            v = live.version
        elseif saved and saved.version and saved.version ~= "" then
            v = saved.version
        end
        member.version = v

        local addonState = "-"

        local online = (member.online == "Yes")
        local savedMissing = (saved and saved._missing == true)
        local liveLastSeen = live and live.lastSeen or nil
        local liveRecent = (liveLastSeen and ((GetTime() - liveLastSeen) <= 120)) or false
        local liveActive = (live and live.active == true)

        if not online then
            addonState = "—"
        elseif savedMissing then
            addonState = false
        elseif liveRecent and liveActive then
            addonState = true
        else
            addonState = false
        end
        if key == "Frìaclaw-Spineshatter" then
            ns.log.info(
                "DEBUG key=" .. tostring(key) ..
                " online=" .. tostring(online) ..
                " savedMissing=" .. tostring(savedMissing) ..
                " liveRecent=" .. tostring(liveRecent) ..
                " liveActive=" .. tostring(liveActive) ..
                " final=" .. tostring(addonState)
            )
        end
        member.addon_active = addonState

        -- -----------------------------
        -- Profession polling
        -- -----------------------------

        local hasAddon = online and liveRecent and liveActive and not savedMissing

        if key and online and hasAddon and shouldRequestProf(charData) then
            ui._profReqLast[key] = ui._profReqLast[key] or 0
            if (now - ui._profReqLast[key]) >= (ui._profReqCooldown or 60) then
                ui._profReqLast[key] = now

                if ns.networking and ns.networking.SendWhisper then
                    local target = whisperTarget(key)
                    if target and target ~= "" then
                        ns.networking.SendWhisper("REQ_PROF", {}, target)
                    end
                end
            end
        end
    end
    return data
end

function ui.updateFieldValue(name, field, value)
    if not name or not field then return end
    for _, row in ipairs(ui.dataBuffer or {}) do
        if row.name and Ambiguate(row.name, "none") == Ambiguate(name, "none") then
            row[field] = value
            break
        end
    end
end

function ui.updateGuildLog()
    if not ns or not ns.db or not ns.db.guildLog then return end
    if not ui or not ui.guildLogTable then return end
    if ns.helpers and ns.helpers.playerCanViewGuildLog and not ns.helpers.playerCanViewGuildLog() then
        return
    end

    if ui._guildLogUpdatePending then return end
    ui._guildLogUpdatePending = true

    C_Timer.After(0.35, function()
        ui._guildLogUpdatePending = false

        ui._guildRows = ui._guildRows or {}
        local rows = ui._guildRows
        wipe(rows)
        for _, entry in ipairs(ns.db.guildLog or {}) do
            local ts = entry.time or 0
            local sender = tostring(entry.sender or "?")
            local shortSender = Ambiguate(sender, "short") or sender
            local msg = tostring(entry.message or "")
            rows[#rows+1] = {
                ts = ts,
                time = date("%d/%m %H:%M", ts),
                sender = shortSender,
                message = msg,
                kind = entry.kind or "info"
            }
        end

        ui.guildLogTable.data = rows
        if ui.guildLogTable.refresh then
            ui.guildLogTable:refresh()
        end
    end)
end