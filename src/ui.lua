local addonName, ns = ...
local ui = {}
ns.ui = ui

function ui.initialize()

    if ui.frame then return end

    ui.frame = ns.components.windowframe:Create(650, 400):Title("Sacky's Guild Locked"):Draggable()

    ui.frame.background = ui.frame.frame:CreateTexture(nil, "BACKGROUND")
    ui.frame.background:SetColorTexture(0, 0, 0, 0.3)
    ui.frame.background:SetAllPoints()

    ui.frame.frame:Hide()

    local memberlist = CreateFrame("Frame", nil, ui.frame.frame)
    memberlist:SetPoint("TOPLEFT", ui.frame.frame, "TOPLEFT", 10, -30)
    memberlist:SetPoint("BOTTOMRIGHT", ui.frame.frame, "BOTTOMRIGHT", -10, 10)

    local metadata = {

        sort = {
            col1 = { field = "online", order = "desc" },
            col2 = { field = "name", order = "asc" }
        },

        col1 = {
            header = "Name",
            field = "name"
        },

        col2 = {
            header = "Online",
            field = "online"
        },

        col3 = {
            header = "Profession 1",
            field = "prof1"
        },

        col4 = {
            header = "Skill",
            field = "prof1Skill"
        },

        col5 = {
            header = "Profession 2",
            field = "prof2"
        },

        col6 = {
            header = "Skill",
            field = "prof2Skill"
        },

        col7 = {
            header = "Addon Active",
            field = "addon_active"
        }

    }

    local showOnlineOnly = false

    ui.dataBuffer = ns.helpers.getGuildMemberData(showOnlineOnly)
    ui.memberTable = ns.components.tablev2:new(
        memberlist,
        metadata,
        ui.dataBuffer,
        20
    )

    ui.refresh()
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
        ui.refresh()
        ui.frame.frame:Show()
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

    local showOnlineOnly = false

    ui.dataBuffer = ui.updateMemberList(showOnlineOnly)
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

end


function ui.updateMemberList(showOnlineOnly)
    local data = ns.helpers.getGuildMemberData(showOnlineOnly)

    ns.networking.activeUsers = ns.networking.activeUsers or {}
    if not ns.db then return data end
    ns.db.addonStatus = ns.db.addonStatus or {}

    for _, member in ipairs(data) do
        local short = Ambiguate(member.name, "none")
        local key = ns.helpers.getKey(member.name)
        local live = key and ns.networking.activeUsers[key] or nil
        local saved = key and ns.db.addonStatus[key] or nil

        local v = "-"
        if live and live.version and live.version ~= "" then
            v = live.version
        elseif saved and saved.version and saved.version ~= "" then
            v = saved.version
        end
        member.version = v

        local everSeen = false
        if saved then
            if saved.seen == true then
                everSeen = true
            elseif saved.version and saved.version ~= "" and saved.version ~= "-" then
                everSeen = true
            end
        end
        if live and live.active == true then
            everSeen = true
        end
        member.addon_active = everSeen
        member.name = short
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
    if not ns.ui or not ns.ui.guildLogTable or not ns.ui.guildLogTable.setData then return end
    if ns.helpers and ns.helpers.playerCanViewGuildLog and not ns.helpers.playerCanViewGuildLog() then
        return
    end
    local rows = {}
    for _, entry in ipairs(ns.db.guildLog or {}) do
        rows[#rows+1] = {
            time = date("%d/%m %H:%M:%S", entry.time),
            message = entry.message
        }
    end
    ns.ui.guildLogTable:setData(rows)
end