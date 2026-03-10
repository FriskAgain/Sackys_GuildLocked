local addonName, ns = ...
local WindowFrame = {}
if not ns.components then ns.components = {} end
ns.components.windowframe = WindowFrame

local function registerEscClose(frame)
    if not frame or not frame:GetName() then return end
    _G.UISpecialFrames = _G.UISpecialFrames or {}

    local name = frame:GetName()
    for _, existing in ipairs(UISpecialFrames) do
        if existing == name then
            return
        end
    end

    table.insert(UISpecialFrames, name)
end

function WindowFrame:EscClose()
    registerEscClose(self.frame)
    return self
end

function WindowFrame:Create(width, height, globalName)
    local obj = {}
    setmetatable(obj, self)
    self.__index = self
    local frame = CreateFrame("Frame", globalName, UIParent, "BasicFrameTemplate")
    frame:SetPoint("TOP", UIParent, "TOP", 0, -100)
    frame:SetSize(width, height)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()
    obj.frame = frame
    obj.MIN_W = width or 300
    obj.MIN_H = height or 200
    return obj
end

function WindowFrame:Title(title)
    if self.frame.TitleText then
        self.frame.TitleText:SetText(title or "")
        return self
    end
    local titleString = self.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.title = titleString
    titleString:SetPoint("TOP", self.frame, "TOP", 0, -6)

    if addonName then
        local ok = pcall(function()
            titleString:SetFont("Interface\\AddOns\\" .. addonName .. "\\src\\Fonts\\LifeCraft_Font.ttf", 14)
        end)
        if not ok then
            titleString:SetFontObject(GameFontHighlight)
        end
    end

    titleString:SetText(title or "")
    return self
end

function WindowFrame:Draggable()
    self.frame:EnableMouse(true)
    self.frame:SetMovable(true)
    self.frame:RegisterForDrag("LeftButton")
    self.frame:SetScript("OnDragStart", function(frame)
        frame:StartMoving()
    end)
    self.frame:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
    end)
    return self
end

function WindowFrame:Resizable(minW, minH)
    self.MIN_W = minW or self.MIN_W or 300
    self.MIN_H = minH or self.MIN_H or 200

    self.frame:SetResizable(true)

    local resize = CreateFrame("Button", nil, self.frame)
    resize:SetSize(16, 16)
    resize:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -6, 6)
    resize:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resize:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resize:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

    resize:SetScript("OnMouseDown", function(_, btn)
        if btn == "LeftButton" then
            self.frame:StartSizing("BOTTOMRIGHT")
        end
    end)

    resize:SetScript("OnMouseUp", function(_, btn)
        if btn == "LeftButton" then
            self.frame:StopMovingOrSizing()

            local w = self.frame:GetWidth()
            local h = self.frame:GetHeight()

            if w < self.MIN_W or h < self.MIN_H then
                self.frame:SetSize(
                    math.max(w, self.MIN_W),
                    math.max(h, self.MIN_H)
                )
            end
        end
    end)

    self.frame._windowFrame = self
    self.frame:SetScript("OnSizeChanged", function(frame, width, height)
        local obj = frame._windowFrame
        local limitReached = false

        if obj and obj.MIN_W and width < obj.MIN_W then
            width = obj.MIN_W
            limitReached = true
        end

        if obj and obj.MIN_H and height < obj.MIN_H then
            height = obj.MIN_H
            limitReached = true
        end

        if limitReached then
            frame:SetSize(width, height)
            return
        end
    end)

    self.resizeButton = resize
    return self
end

function WindowFrame:SetSize(width, height)
    if not self.frame or not width or not height then return self end
    self.frame:SetSize(width, height)
    return self
end

function WindowFrame:SetColumns(numColumns)
    if not self.frame or not numColumns or numColumns < 1 then return self end

    self.columns = {}
    local totalWidth = self.frame:GetWidth()
    local fixedWidth = 200
    local xOffset = 0
    for i = 1, numColumns do
        local colFrame = CreateFrame("Frame", nil, self.frame)
        colFrame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", xOffset, -30)
        colFrame:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", xOffset, 0)
        if i < numColumns then
            colFrame:SetWidth(fixedWidth)
        else
            colFrame:SetWidth(totalWidth - fixedWidth * (numColumns - 1))
        end
        colFrame:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background" })
        colFrame:SetBackdropColor(0.1 * i, 0.1 * i, 0.3, 0.3)
        table.insert(self.columns, colFrame)
        xOffset = xOffset + colFrame:GetWidth()
    end
    return self
end