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
        local live = ns.networking.activeUsers[key]
        local saved = ns.db.addonStatus[key]

        if live and live.version and live.version ~= "" then
            member.version = live.version
        elseif saved and saved.version and saved.version ~= "" then
            member.version = saved.version
        else
            member.version = "-"
        end

        if live and live.active then
            member.addon_active = true
        elseif saved and (saved.seen or (saved.version and saved.version ~= "" and saved.version ~= "")) then
            member.addon_active = true
        else member.addon_active = false
        end
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
