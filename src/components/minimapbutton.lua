local addonName, ns = ...
if not ns.components then ns.components = {} end
local minimapbutton = {
    LDB,
    LDBIcon
}
ns.components.minimapbutton = minimapbutton

function minimapbutton.create()
    minimapbutton.LDB = LibStub("LibDataBroker-1.1")
    minimapbutton.LDBIcon = LibStub("LibDBIcon-1.0")

    local dataObject = minimapbutton.LDB:NewDataObject("Sacky's GuildLocked", {
        type = "data source",
        text = "Sacky's GuildLocked",
        icon = "Interface\\AddOns\\" .. addonName .. "\\src\\images\\blp\\icon.blp",
        OnClick = function(self, button)
            if button == "LeftButton" then
                ns.ui.toggleWindow()
            elseif button == "RightButton" then
                if SGLKRightClickWindow:IsShown() then
                    SGLKRightClickWindow:Hide()
                else
                    SGLKRightClickWindow:Show()
                end
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("Sacky's GuildLocked", 1, 1, 1)
            tooltip:AddLine("Left-Click: Toggle Sacky's GuildLocked window", 0.8, 0.8, 0.8)
            tooltip:AddLine("Right-Click: Open Options", 0.8, 0.8, 0.8)
        end,
    })

    minimapbutton.LDBIcon:Register("SGLK", dataObject, ns.options.minimap)

    local rightClickWindow = CreateFrame("Frame", "SGLKRightClickWindow", UIParent, "BackdropTemplate")
    rightClickWindow:SetSize(300, 200) -- Set the size of the window
    rightClickWindow:SetPoint("CENTER") -- Position it in the center of the screen
    rightClickWindow:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    rightClickWindow:SetBackdropColor(0, 0, 0, 1)
    rightClickWindow:Hide()

    local closeButton = CreateFrame("Button", nil, rightClickWindow, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", rightClickWindow, "TOPRIGHT", -5, -5)

    local title = rightClickWindow:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", rightClickWindow, "TOP", 0, -10)
    title:SetText("Options")

    local debugCheckbox = CreateFrame("CheckButton", nil, rightClickWindow, "UICheckButtonTemplate")
    debugCheckbox:SetPoint("TOPLEFT", rightClickWindow, "TOPLEFT", 20, -40)
    debugCheckbox.text = debugCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    debugCheckbox.text:SetPoint("LEFT", debugCheckbox, "RIGHT", 5, 0)
    debugCheckbox.text:SetText("Enable Debug Mode")

    debugCheckbox:SetChecked(ns.options.debug) -- Set the checkbox state based on the debug option
    debugCheckbox:SetScript("OnClick", function(self)
        ns.options.debug = self:GetChecked()
        ns.log.info("Debug mode " .. (ns.options.debug and "enabled" or "disabled"))
    end)
end
