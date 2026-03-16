local addonName, ns = ...
if not ns.components then ns.components = {} end

local tablev2 = {}
ns.components.tablev2 = tablev2
tablev2.__index = tablev2

local function safeString(v)
    if v == nil then return "" end
    return tostring(v)
end

local function snapWidth(value, step)
    step = step or 2
    if not value then return 0 end
    return math.floor((value / step) + 0.5) * step
end

local function getKindColor(kind)
    if kind == "warn" then
        return 1, 0.82, 0
    elseif kind == "blocked" then
        return 1, 0.3, 0.3
    elseif kind == "sync" then
        return 0.6, 0.7, 1
    elseif kind == "system" then
        return 0.75, 0.75, 0.75
    end

    return 1, 1, 1
end

local function getKindIcon(kind)
    if kind == "warn" then
        return "|TInterface\\COMMON\\Indicator-Yellow:12:12:0:0|t "
    elseif kind == "blocked" then
        return "|TInterface\\COMMON\\Indicator-Red:12:12:0:0|t "
    elseif kind == "sync" then
        return "|TInterface\\COMMON\\Indicator-Gray:12:12:0:0|t "
    elseif kind == "system" then
        return "|TInterface\\COMMON\\Indicator-Blue:12:12:0:0|t "
    end

    return "|TInterface\\COMMON\\Indicator-Green:12:12:0:0|t "
end

function tablev2:new(parent, metadata, data, row_height)
    if not parent then error("Parent frame is required") end
    if not metadata then error("Metadata is required") end

    local obj = setmetatable({}, self)

    obj.parent = parent
    obj.metadata = metadata or {}
    obj.data = data or {}
    obj.row_height = row_height or 20
    obj.fields = {}
    obj.rows = {}
    obj.sortState = {
        column = nil,
        ascending = true
    }

    for k, v in pairs(obj.metadata) do
        if type(v) == "table" and v.header and v.field then
            table.insert(obj.fields, {
                key = k,
                header = v.header,
                field = v.field,
                width = v.width,
                minWidth = v.minWidth,
                maxWidth = v.maxWidth,
                justify = v.justify or "LEFT"
            })
        end
    end

    table.sort(obj.fields, function(a, b)
        return a.key < b.key
    end)

    obj.container = CreateFrame("Frame", nil, parent)
    obj.container:SetAllPoints(parent)

    obj.header = CreateFrame("Frame", nil, obj.container)
    obj.header:SetPoint("TOPLEFT", obj.container, "TOPLEFT", 0, 0)
    obj.header:SetPoint("TOPRIGHT", obj.container, "TOPRIGHT", 0, 0)
    obj.header:SetHeight(obj.row_height)

    obj.scrollFrame = CreateFrame("ScrollFrame", nil, obj.container, "UIPanelScrollFrameTemplate")
    obj.scrollFrame:SetPoint("TOPLEFT", obj.header, "BOTTOMLEFT", 0, 0)
    obj.scrollFrame:SetPoint("BOTTOMRIGHT", obj.container, "BOTTOMRIGHT", -26, 0)

    obj.content = CreateFrame("Frame", nil, obj.scrollFrame)
    obj.content:SetPoint("TOPLEFT", obj.scrollFrame, "TOPLEFT", 0, 0)
    obj.content:SetPoint("TOPRIGHT", obj.scrollFrame, "TOPRIGHT", 0, 0)
    obj.scrollFrame:SetScrollChild(obj.content)

    local scrollbar = obj.scrollFrame.ScrollBar
    if scrollbar then
        scrollbar:ClearAllPoints()
        scrollbar:SetPoint("TOPLEFT", obj.scrollFrame, "TOPRIGHT", 4, -16)
        scrollbar:SetPoint("BOTTOMLEFT", obj.scrollFrame, "BOTTOMRIGHT", 4, 16)
    end

    obj._resizePending = false
    obj._lastMeasuredWidth = 0

    obj.container:SetScript("OnSizeChanged", function()
        local newWidth = obj.container:GetWidth() or 0
        if newWidth <= 0 then return end

        if math.abs(newWidth - (obj._lastMeasuredWidth or 0)) < 4 then
            return
        end

        obj._lastMeasuredWidth = newWidth

        if obj._resizePending then return end
        obj._resizePending = true

        C_Timer.After(0.1, function()
            obj._resizePending = false
            if obj and obj.container then
                obj:refresh()
            end
        end)
    end)
    C_Timer.After(0.05, function()
        if obj and obj.container and (obj.container:GetWidth() or 0) > 0 then
            obj:refresh()
        end
    end)

    return obj
end

function tablev2:setData(newData)
    self.data = newData or {}
    self:refresh()
end

function tablev2:getUsableWidth()
    local w = self.container:GetWidth()
    if not w or w <= 0 then
        w = self.parent:GetWidth()
    end
    if not w or w <= 0 then
        w = 600
    end
    return math.max(120, w - 8)
end

function tablev2:measureTextWidth(text)
    return string.len(safeString(text)) * 8
end

function tablev2:calculateFieldWidths()
    if not self.fields or #self.fields == 0 then return end

    local usableWidth = snapWidth(self:getUsableWidth(), 4)
    local widths = {}
    local flexibleIndices = {}
    local usedWidth = 0

    for i, field in ipairs(self.fields) do
        local explicit = tonumber(field.width)
        if explicit and explicit > 0 then
            widths[i] = snapWidth(explicit, 4)
            usedWidth = usedWidth + widths[i]
        else
            local maxWidth = self:measureTextWidth(field.header) + 18
            for _, item in ipairs(self.data) do
                local value
                if item[field.field] ~= nil then
                    value = item[field.field]
                elseif item[string.lower(field.field)] ~= nil then
                    value = item[string.lower(field.field)]
                elseif item[string.gsub(field.field, "_", "")] ~= nil then
                    value = item[string.gsub(field.field, "_", "")]
                else
                    value = ""
                end

                local width = self:measureTextWidth(value) + 14
                if width > maxWidth then
                    maxWidth = width
                end
            end

            local minWidth = field.minWidth or 60

            if field.field == "online" then
                minWidth = math.max(minWidth, 70)
            elseif field.field == "addon_active" then
                minWidth = math.max(minWidth, 110)
            elseif field.field == "message" then
                minWidth = math.max(minWidth, 280)
            elseif field.field == "sender" then
                minWidth = math.max(minWidth, 120)
            elseif field.field == "time" then
                minWidth = math.max(minWidth, 120)
            end

            if field.maxWidth and maxWidth > field.maxWidth then
                maxWidth = field.maxWidth
            end

            widths[i] = snapWidth(math.max(maxWidth, minWidth), 4)
            usedWidth = usedWidth + widths[i]
            table.insert(flexibleIndices, i)
        end
    end

    if usedWidth < usableWidth and #flexibleIndices > 0 then
        local extra = usableWidth - usedWidth
        local perCol = snapWidth(math.floor(extra / #flexibleIndices), 4)
        local distributed = 0

        for _, idx in ipairs(flexibleIndices) do
            widths[idx] = widths[idx] + perCol
            distributed = distributed + perCol
        end

        local remainder = usableWidth - (usedWidth + distributed)
        if remainder > 0 then
            widths[flexibleIndices[#flexibleIndices]] = widths[flexibleIndices[#flexibleIndices]] + remainder
        end

        usedWidth = usableWidth

    elseif usedWidth < usableWidth then
        local growIndex = #self.fields
        widths[growIndex] = widths[growIndex] + (usableWidth - usedWidth)
        usedWidth = usableWidth
    end

    self.fieldWidths = widths
    self.totalColumnWidth = usedWidth
    return self
end

function tablev2:createHeaderCell(parent, x, width, field)
    local button = CreateFrame("Button", nil, parent)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, 0)
    button:SetSize(width, self.row_height)
    button:SetFrameLevel(parent:GetFrameLevel() + 5)

    local fs = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("LEFT", button, "LEFT", 4, 0)
    fs:SetPoint("RIGHT", button, "RIGHT", -4, 0)
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("MIDDLE")
    fs:SetWordWrap(false)

    local arrow = ""
    if self.sortState.column == field.field then
        if self.sortState.ascending then
            arrow = " |TInterface\\Buttons\\UI-SortArrow:12:12:0:0:16:16:0:16:0:16|t"
        else
            arrow = " |TInterface\\Buttons\\UI-SortArrow:12:12:0:0:16:16:0:16:16:0|t"
        end
    end

    fs:SetText(field.header .. arrow)

    button:SetScript("OnClick", function()
        self:sortByColumn(field.field)
    end)

    button:SetScript("OnEnter", function()
        fs:SetTextColor(1, 0.82, 0)
    end)

    button:SetScript("OnLeave", function()
        fs:SetTextColor(1, 1, 1)
    end)

    return button
end

function tablev2:updateHeader()
    if self.header then
        self.header:Hide()
        self.header:SetParent(nil)
        self.header = nil
    end

    self.header = CreateFrame("Frame", nil, self.container)
    self.header:SetPoint("TOPLEFT", self.container, "TOPLEFT", 0, 0)
    self.header:SetPoint("TOPRIGHT", self.container, "TOPRIGHT", 0, 0)
    self.header:SetHeight(self.row_height)

    self.headerCells = {}

    local x = 0
    for i, field in ipairs(self.fields) do
        local width = self.fieldWidths[i] or 60
        local button = self:createHeaderCell(self.header, x, width, field)
        table.insert(self.headerCells, button)

        self:createLine(self.header, x, 0, 1, self.row_height, 0.3, 0.3, 0.3, 1)
        x = x + width
    end

    self:createLine(self.header, 0, -self.row_height + 1, self.totalColumnWidth, 1, 0.3, 0.3, 0.3, 1) 
end

function tablev2:createCell(row, x, width, value, field, item)
    local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("TOPLEFT", row, "TOPLEFT", x + 4, -2)
    fs:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", x + 4, 2)
    fs:SetWidth(math.max(10, width - 8))
    fs:SetJustifyH(field.justify or "LEFT")
    fs:SetJustifyV("MIDDLE")
    fs:SetWordWrap(false)

    if field.field == "message" then
        fs:SetMaxLines(1)
    end

    if type(value) == "boolean" then
        if value then
            fs:SetText("Yes")
            fs:SetTextColor(0.3, 0.9, 0.3)
        else
            fs:SetText("No")
            fs:SetTextColor(1, 0.3, 0.3)
        end

    elseif field.field == "online" then
        local text = tostring(value or "")
        fs:SetText(text)

        if text == "Yes" then
            fs:SetTextColor(0.3, 0.9, 0.3)
        else
            fs:SetTextColor(1, 0.3, 0.3)
        end

    else
        local text = safeString(value)

        if field.field == "message" then
            local kind = (item and item.kind) or "info"
            local icon = getKindIcon(kind)
            local r, g, b = getKindColor(kind)

            fs:SetText(icon .. text)
            fs:SetTextColor(r, g, b)
        else
            fs:SetText(text)
            fs:SetTextColor(1, 1, 1)
        end
    end

    return fs
end

function tablev2:updateRows()
    if self.content then
        for i = self.content:GetNumChildren(), 1, -1 do
            local child = select(i, self.content:GetChildren())
            if child then
                child:Hide()
                child:SetParent(nil)
            end
        end
    end

    wipe(self.rows)

    if self.metadata.sort and not self.sortState.column then
        local sortOrder = {}
        local sortKeys = {}

        for k in pairs(self.metadata.sort) do
            table.insert(sortKeys, k)
        end
        table.sort(sortKeys)

        for _, k in ipairs(sortKeys) do
            local v = self.metadata.sort[k]
            table.insert(sortOrder, {
                key = k,
                field = v.field,
                order = v.order or "asc"
            })
        end

        table.sort(self.data, function(a, b)
            for _, sortDef in ipairs(sortOrder) do
                local field = sortDef.field
                local order = sortDef.order
                local va = safeString(a[field])
                local vb = safeString(b[field])

                if va ~= vb then
                    if order == "asc" then
                        return va < vb
                    else
                        return va > vb
                    end
                end
            end
            return false
        end)
    end

    self.content:SetSize(self.totalColumnWidth, math.max(1, #self.data * self.row_height))

    for rowIdx, item in ipairs(self.data) do
        local row = CreateFrame("Frame", nil, self.content)
        row:SetSize(self.totalColumnWidth, self.row_height)
        row:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -(rowIdx - 1) * self.row_height)

        if rowIdx % 2 == 0 then
            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(1, 1, 1, 0.03)
        end

        self:createLine(row, 0, -self.row_height + 1, self.totalColumnWidth, 1, 0.3, 0.3, 0.3, 1)

        local x = 0
        for idx, field in ipairs(self.fields) do
            local width = self.fieldWidths[idx] or 60
            self:createLine(row, x, 0, 1, self.row_height, 0.3, 0.3, 0.3, 1)

            local value
            if item[field.field] ~= nil then
                value = item[field.field]
            elseif item[string.lower(field.field)] ~= nil then
                value = item[string.lower(field.field)]
            else
                value = item[string.gsub(field.field, "_", "")]
            end

            self:createCell(row, x, width, value, field, item)
            x = x + width
        end

        table.insert(self.rows, row)
    end
end

function tablev2:updateFieldValue(name, field, value)
    if not name or not field then return end

    for _, row in ipairs(self.data) do
        if row.name and Ambiguate(row.name, "none") == Ambiguate(name, "none") then
            row[field] = value
            break
        end
    end

    self:refresh()
    return self
end

function tablev2:createLine(parent, x, y, width, height, r, g, b, a)
    if not parent then return end

    local line = parent:CreateTexture(nil, "BACKGROUND")
    line:SetColorTexture(r or 0.5, g or 0.5, b or 0.5, a or 1)
    line:SetPoint("TOPLEFT", parent, "TOPLEFT", x or 0, y or 0)
    line:SetSize(width or 1, height or 1)
    return line
end

function tablev2:sortByColumn(fieldName)
    if self.sortState.column == fieldName then
        self.sortState.ascending = not self.sortState.ascending
    else
        self.sortState.column = fieldName
        self.sortState.ascending = false
    end

    self:applySort()
    self:updateHeader()
    self:updateRows()
end

function tablev2:normalizeSortValue(value)
    if value == nil or value == "" or value == "-" then
        return nil
    end

    if type(value) == "string" then
        local num = tonumber(value)
        if num then return num end
        return value:lower()
    end
    return value
end

function tablev2:applySort()
    if not self.sortState.column then return end

    local cleanData = {}
    for _, v in ipairs(self.data) do
        if v ~= nil then
            table.insert(cleanData, v)
        end
    end
    self.data = cleanData

    local fieldName = self.sortState.column
    local ascending = self.sortState.ascending

    table.sort(self.data, function(a, b)
        local function getValue(item)
            if not item then return nil end
            if item[fieldName] ~= nil then
                return item[fieldName]
            elseif item[string.lower(fieldName)] ~= nil then
                return item[string.lower(fieldName)]
            else
                return item[string.gsub(fieldName, "_", "")]
            end
        end

        local va = self:normalizeSortValue(getValue(a))
        local vb = self:normalizeSortValue(getValue(b))

        if va == nil and vb == nil then
            return false
        elseif va == nil then
            return false
        elseif vb == nil then
            return true
        end

        if type(va) == "boolean" and type(vb) == "boolean" then
            if va == vb then return false end
            if ascending then
                return va == false and vb == true
            else
                return va == true and vb == false
            end
        end

        if type(va) == "number" and type(vb) == "number" then
            if va == vb then return false end
            if ascending then
                return va < vb
            else
                return va > vb
            end
        end

        va = tostring(va)
        vb = tostring(vb)

        if va == vb then return false end
        if ascending then
            return va < vb
        else
            return va > vb
        end
    end)
end

function tablev2:refresh(forceRows)
    if not self.container then return self end

    local containerWidth = self.container:GetWidth() or 0
    if containerWidth <= 0 then
        return self
    end
    if self.content and self.scrollFrame then
        local scrollWidth = self.scrollFrame:GetWidth() or 0
        if scrollWidth > 0 then
            self.content:SetWidth(scrollWidth)
        end
    end

    local oldWidth = self.totalColumnWidth or 0
    local oldCount = self._lastRowCount or 0
    self:calculateFieldWidths()
    self:applySort()
    local newWidth = self.totalColumnWidth or 0
    local newCount = #(self.data or {})
    local widthChanged = (oldWidth ~= newWidth)
    local rowCountChanged = (oldCount ~= newCount)
    local needsRows = forceRows or widthChanged or rowCountChanged or not self.rows or #self.rows == 0

    if not self.header or widthChanged then
        self:updateHeader()
    end
    if needsRows then
        self:updateRows()
    end
    self._lastRowCount = newCount
    return self
end