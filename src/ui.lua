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
    -- Hide if no permissions
    if not canSeeLog() then
        logBtn:Hide()
    end
    ui._officerLogBtn = logBtn

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
            minwidth = 120
        },

        col4 = {
            header = "Skill",
            field = "prof1Skill",
            width = 70
        },

        col5 = {
            header = "Profession 2",
            field = "prof2",
            minwidth = 120
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

    ui.dataBuffer = ns.helpers.getGuildMemberData(showOnlineOnly)
    ui.memberTable = ns.components.tablev2:new(
        memberlist,
        metadata,
        {},
        20
    )
    ui.frame.frame.memberTable = ui.memberTable
    C_Timer.After(0.5, function()
        if ns.ui and ns.ui.refresh then
            ns.ui.refresh()
        end
    end)
    ns.networking.SendToGuild("REQ_VERSION", {})

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

        C_Timer.After(0.1, function()
            if ns.ui and ns.ui.refresh then
                ns.ui.refresh()
            end
        end)
        if ui.refreshTicker then
            ui.refreshTicker:Cancel()
        end
        ui.refreshTicker = C_Timer.NewTicker(10, function()
            if ui.frame.frame:IsShown() then
                ui.refresh()
            end
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

        if IsInGuild and IsInGuild() and GuildRoster then
            GuildRoster()
        end

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

        if ui.memberTable then
            ui.memberTable.data = ui.dataBuffer
            ui.memberTable:refresh()
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
        if InCombatLockdown and InCombatLockdown() then
            ui._closeGuildLogAfterCombat = true
            if ns.log and ns.log.info then
                ns.log.info("Will close Officer Log after combat.")
            end
            return
        end
        frame:Hide()
    else
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

        -- Addon Active:
        -- Yes if we have a live heartbeat,
        -- else Yes if DB says enabled=true,
        -- else No.
        local enabled = false
        if live and live.active == true then
            enabled = true
        elseif saved and saved.enabled == true then
            enabled = true
        end
        member.addon_active = enabled

        -- -----------------------------
        -- Profession polling
        -- -----------------------------
        local online = (member.online == "Yes")

        local hasAddon = saved and saved.seen == true and saved.enabled ~= false

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

    -- Debounce refresh
    if ui._guildLogUpdatePending then return end
    ui._guildLogUpdatePending = true

    C_Timer.After(0.35, function()
        ui._guildLogUpdatePending = false

        -- Version 1.0.7 new code
        ui._guildRows = ui._guildRows or {}
        local rows = ui._guildRows
        wipe(rows)
        -- New code ends here
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