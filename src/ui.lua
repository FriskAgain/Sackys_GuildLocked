local addonName, ns = ...
local ui = {}
ns.ui = ui

function ui.initialize()

    if ui.frame then return end

    ui.frame = ns.components.windowframe:Create(600, 400):Title("SGLK"):Draggable()

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

    if ui.memberTable then

        ui.memberTable.data = ui.dataBuffer
        ui.memberTable:refresh()

    end

end


function ui.updateMemberList(showOnlineOnly)

    local data = ns.helpers.getGuildMemberData(showOnlineOnly)

    ns.networking.activeUsers = ns.networking.activeUsers or {}
    ns.db.addonStatus = ns.db.addonStatus or {}

    for i, member in ipairs(data) do

        local name = Ambiguate(member.name, "none")

        local live = ns.networking.activeUsers[name]
        local saved = ns.db.addonStatus[name]

        if live then

            member.version = live.version or "-"
            member.addon_active = live.active

        elseif saved then

            member.version = saved.version or "-"
            member.addon_active = saved.active

        else

            member.version = "-"
            member.addon_active = false

        end

    end

    return data

end


function ui.updateFieldValue(name, field, value)
    if not name or not field or not value then return end
    for i, row in ipairs(ui.dataBuffer) do
        if row.name == Ambiguate(name, "none") then
            row[field] = value
            break
        end
    end
end
