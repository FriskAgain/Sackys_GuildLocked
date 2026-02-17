local addonName, ns = ...
local WindowFrame = {}
if not ns.components then ns.components = {} end
ns.components.windowframe = WindowFrame

function WindowFrame:Create(width, height)
    local obj = {}
    setmetatable(obj, self)
    self.__index = self

    local frame = CreateFrame("Frame", nil, UIParent, "BasicFrameTemplate")
    frame:SetPoint("TOP", UIParent, "TOP", 0, -100)
    frame:SetSize(width, height)
    obj.frame = frame

    return obj
end

function WindowFrame:Title(title)
    local titleString = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")

    self.title = titleString
    titleString:SetPoint("TOP", self.frame, "TOP", 0, -5)
    titleString:SetFont("Interface\\AddOns\\" .. addonName .. "\\src\\Fonts\\LifeCraft_Font.ttf", 14)
    titleString:SetText(title)
    return self
end

function WindowFrame:Draggable()
    self.frame:EnableMouse(true)
    self.frame:SetMovable(true)
    self.frame:RegisterForDrag("LeftButton")
    self.frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    self.frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    return self
end

function WindowFrame:Resizable()
    self.frame:SetResizable(true)
    local resize = CreateFrame("Button", nil, self.frame)
    resize:SetSize(16, 16)
    resize:SetPoint("BOTTOMRIGHT")
    resize:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resize:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resize:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resize:SetScript("OnMouseDown", function(_, btn)
        if btn == "LeftButton" then
            self.frame:StartSizing("BOTTOMRIGHT")
        end
    end)
    resize:SetScript("OnMouseUp", function(_, btn)
        if btn == "LeftButton" then
            self.frame:StopMovingOrSizing()
        end
    end)
    self.frame._windowFrame = self -- Store reference to WindowFrame object
    self.frame:SetScript("OnSizeChanged", function(frame, width, height)
        local obj = frame._windowFrame
        local limitReached = false
        if obj and obj.MIN_W and width < obj.MIN_W then width = obj.MIN_W; limitReached = true end
        if obj and obj.MIN_H and height < obj.MIN_H then height = obj.MIN_H; limitReached = true end
        if limitReached then
            frame:SetSize(width, height)
            return
        end
        -- Options.windowWidth = width
        -- Options.windowHeight = height
    end)
    return self
end

function WindowFrame:SetSize(width, height)
    if not self.frame or not width or not height then return end
    self.frame:SetSize(width, height)
    return self
end

function WindowFrame:SetColumns(numColumns)
    if not self.frame or not numColumns or numColumns < 1 then return end
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
        colFrame:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background"})
        colFrame:SetBackdropColor(0.1 * i, 0.1 * i, 0.3, 0.3)
        table.insert(self.columns, colFrame)
        xOffset = xOffset + colFrame:GetWidth()
    end
    return self
end
