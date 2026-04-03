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

    obj.parent     = parent
    obj.metadata   = metadata or {}
    obj.data       = data or {}
    obj.row_height = row_height or 20
    obj.fields     = {}
    obj.rows       = {}
    obj._rowPool   = {}
    obj.sortState  = { column = nil, ascending = true }

    for k, v in pairs(obj.metadata) do
        if type(v) == "table" and v.header and v.field then
            table.insert(obj.fields, {
                key      = k,
                header   = v.header,
                field    = v.field,
                width    = v.width,
                minWidth = v.minWidth,
                maxWidth = v.maxWidth,
                justify  = v.justify or "LEFT"
            })
        end
    end
    table.sort(obj.fields, function(a, b) return a.key < b.key end)

    obj.container = CreateFrame("Frame", nil, parent)
    obj.container:SetAllPoints(parent)

    obj.header = CreateFrame("Frame", nil, obj.container)
    obj.header:SetPoint("TOPLEFT",  obj.container, "TOPLEFT",  0, 0)
    obj.header:SetPoint("TOPRIGHT", obj.container, "TOPRIGHT", 0, 0)
    obj.header:SetHeight(obj.row_height)
    obj.headerCells  = {}
    obj._headerBuilt = false

    obj.scrollFrame = CreateFrame("ScrollFrame", nil, obj.container, "UIPanelScrollFrameTemplate")
    obj.scrollFrame:SetPoint("TOPLEFT",     obj.header,    "BOTTOMLEFT",  0,   0)
    obj.scrollFrame:SetPoint("BOTTOMRIGHT", obj.container, "BOTTOMRIGHT", -26, 0)

    obj.content = CreateFrame("Frame", nil, obj.scrollFrame)
    obj.content:SetPoint("TOPLEFT",  obj.scrollFrame, "TOPLEFT",  0, 0)
    obj.content:SetPoint("TOPRIGHT", obj.scrollFrame, "TOPRIGHT", 0, 0)
    obj.scrollFrame:SetScrollChild(obj.content)

    local scrollbar = obj.scrollFrame.ScrollBar
    if scrollbar then
        scrollbar:ClearAllPoints()
        scrollbar:SetPoint("TOPLEFT",    obj.scrollFrame, "TOPRIGHT",    4, -16)
        scrollbar:SetPoint("BOTTOMLEFT", obj.scrollFrame, "BOTTOMRIGHT", 4,  16)
    end

    obj._resizePending     = false
    obj._lastMeasuredWidth = 0

    obj.container:SetScript("OnSizeChanged", function()
        local newWidth = obj.container:GetWidth() or 0
        if newWidth <= 0 then return end
        if math.abs(newWidth - (obj._lastMeasuredWidth or 0)) < 4 then return end
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
    if not w or w <= 0 then w = self.parent:GetWidth() end
    if not w or w <= 0 then w = 600 end
    return math.max(120, w - 8)
end

function tablev2:measureTextWidth(text)
    return string.len(safeString(text)) * 8
end

function tablev2:calculateFieldWidths()
    if not self.fields or #self.fields == 0 then return end

    local usableWidth    = snapWidth(self:getUsableWidth(), 4)
    local widths         = {}
    local flexibleIndices = {}
    local usedWidth      = 0

    for i, field in ipairs(self.fields) do
        local explicit = tonumber(field.width)
        if explicit and explicit > 0 then
            widths[i] = snapWidth(explicit, 4)
            usedWidth  = usedWidth + widths[i]
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
                local w = self:measureTextWidth(value) + 14
                if w > maxWidth then maxWidth = w end
            end

            local minWidth = field.minWidth or 60
            if     field.field == "online"       then minWidth = math.max(minWidth, 70)
            elseif field.field == "addon_active" then minWidth = math.max(minWidth, 110)
            elseif field.field == "message"      then minWidth = math.max(minWidth, 280)
            elseif field.field == "sender"       then minWidth = math.max(minWidth, 120)
            elseif field.field == "time"         then minWidth = math.max(minWidth, 120)
            end

            if field.maxWidth and maxWidth > field.maxWidth then maxWidth = field.maxWidth end
            widths[i] = snapWidth(math.max(maxWidth, minWidth), 4)
            usedWidth  = usedWidth + widths[i]
            table.insert(flexibleIndices, i)
        end
    end

    if usedWidth < usableWidth and #flexibleIndices > 0 then
        local extra     = usableWidth - usedWidth
        local perCol    = snapWidth(math.floor(extra / #flexibleIndices), 4)
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
        widths[#self.fields] = widths[#self.fields] + (usableWidth - usedWidth)
        usedWidth = usableWidth
    end

    self.fieldWidths      = widths
    self.totalColumnWidth = usedWidth
    return self
end

function tablev2:_ensurePool(count)
    local colCount = #self.fields
    while #self._rowPool < count do
        local row = CreateFrame("Frame", nil, self.content)
        row:SetHeight(self.row_height)

        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(1, 1, 1, 0.03)

        local bottomLine = row:CreateTexture(nil, "BACKGROUND")
        bottomLine:SetColorTexture(0.3, 0.3, 0.3, 1)

        local cells  = {}
        local vlines = {}
        for idx = 1, colCount do
            local vline = row:CreateTexture(nil, "BACKGROUND")
            vline:SetColorTexture(0.3, 0.3, 0.3, 1)
            vlines[idx] = vline

            local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            fs:SetWordWrap(false)
            fs:SetJustifyV("MIDDLE")
            cells[idx] = fs
        end

        table.insert(self._rowPool, {
            frame      = row,
            bg         = bg,
            bottomLine = bottomLine,
            cells      = cells,
            vlines     = vlines,
        })
        row:Hide()
    end
end

function tablev2:_layoutPoolRows()
    for _, poolRow in ipairs(self._rowPool) do
        poolRow.frame:SetWidth(self.totalColumnWidth)

        poolRow.bottomLine:ClearAllPoints()
        poolRow.bottomLine:SetPoint("BOTTOMLEFT", poolRow.frame, "BOTTOMLEFT", 0, 0)
        poolRow.bottomLine:SetSize(self.totalColumnWidth, 1)

        local x = 0
        for idx, field in ipairs(self.fields) do
            local width = self.fieldWidths[idx] or 60

            local vline = poolRow.vlines[idx]
            vline:ClearAllPoints()
            vline:SetPoint("TOPLEFT", poolRow.frame, "TOPLEFT", x, 0)
            vline:SetSize(1, self.row_height)

            local fs = poolRow.cells[idx]
            fs:ClearAllPoints()
            fs:SetPoint("TOPLEFT",    poolRow.frame, "TOPLEFT",    x + 4, -2)
            fs:SetPoint("BOTTOMLEFT", poolRow.frame, "BOTTOMLEFT", x + 4,  2)
            fs:SetWidth(math.max(10, width - 8))
            fs:SetJustifyH(field.justify or "LEFT")
            if field.field == "message" then
                fs:SetMaxLines(1)
            end

            x = x + width
        end
    end
end

function tablev2:_updateCell(fs, value, field, item)
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
            local r, g, b = getKindColor(kind)
            fs:SetText(getKindIcon(kind) .. text)
            fs:SetTextColor(r, g, b)
        elseif field.field == "addon_active" and text == "—" then
            fs:SetText(text)
            fs:SetTextColor(0.6, 0.6, 0.6)
        else
            fs:SetText(text)
            fs:SetTextColor(1, 1, 1)
        end
    end
end

function tablev2:updateHeader()
    if not self._headerBuilt then
        local x = 0
        for i, field in ipairs(self.fields) do
            local width  = self.fieldWidths[i] or 60
            local button = CreateFrame("Button", nil, self.header)
            button:SetPoint("TOPLEFT", self.header, "TOPLEFT", x, 0)
            button:SetSize(width, self.row_height)
            button:SetFrameLevel(self.header:GetFrameLevel() + 5)

            local fs = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            fs:SetPoint("LEFT",  button, "LEFT",  4,  0)
            fs:SetPoint("RIGHT", button, "RIGHT", -4, 0)
            fs:SetJustifyH("LEFT")
            fs:SetJustifyV("MIDDLE")
            fs:SetWordWrap(false)

            local vline = self:createLine(self.header, x, 0, 1, self.row_height, 0.3, 0.3, 0.3, 1)

            button._fs    = fs
            button._field = field
            button._vline = vline

            button:SetScript("OnClick",  function() self:sortByColumn(field.field) end)
            button:SetScript("OnEnter",  function() fs:SetTextColor(1, 0.82, 0) end)
            button:SetScript("OnLeave",  function() fs:SetTextColor(1, 1, 1) end)

            self.headerCells[i] = button
            x = x + width
        end

        self._headerHLine = self:createLine(
            self.header, 0, -self.row_height + 1,
            self.totalColumnWidth, 1, 0.3, 0.3, 0.3, 1
        )
        self._headerBuilt = true
    end

    local x = 0
    for i, field in ipairs(self.fields) do
        local width  = self.fieldWidths[i] or 60
        local button = self.headerCells[i]
        if button then
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", self.header, "TOPLEFT", x, 0)
            button:SetSize(width, self.row_height)

            if button._vline then
                button._vline:ClearAllPoints()
                button._vline:SetPoint("TOPLEFT", self.header, "TOPLEFT", x, 0)
                button._vline:SetSize(1, self.row_height)
            end

            local arrow = ""
            if self.sortState.column == field.field then
                if self.sortState.ascending then
                    arrow = " |TInterface\\Buttons\\UI-SortArrow:12:12:0:0:16:16:0:16:0:16|t"
                else
                    arrow = " |TInterface\\Buttons\\UI-SortArrow:12:12:0:0:16:16:0:16:16:0|t"
                end
            end
            if button._fs then
                button._fs:SetText(field.header .. arrow)
            end

            x = x + width
        end
    end

    if self._headerHLine then
        self._headerHLine:ClearAllPoints()
        self._headerHLine:SetPoint("TOPLEFT", self.header, "TOPLEFT", 0, -self.row_height + 1)
        self._headerHLine:SetSize(self.totalColumnWidth, 1)
    end
end

function tablev2:updateRows()
    if self.metadata.sort and not self.sortState.column then
        local sortOrder = {}
        local sortKeys  = {}
        for k in pairs(self.metadata.sort) do table.insert(sortKeys, k) end
        table.sort(sortKeys)
        for _, k in ipairs(sortKeys) do
            local v = self.metadata.sort[k]
            table.insert(sortOrder, { field = v.field, order = v.order or "asc" })
        end
        table.sort(self.data, function(a, b)
            for _, sortDef in ipairs(sortOrder) do
                local va = safeString(a[sortDef.field])
                local vb = safeString(b[sortDef.field])
                if va ~= vb then
                    if sortDef.order == "asc" then
                        return va < vb
                    else
                        return va > vb
                    end
                end
            end
            return false
        end)
    end

    local count = #self.data
    self.content:SetSize(self.totalColumnWidth, math.max(1, count * self.row_height))
    self:_ensurePool(count)
    self:_layoutPoolRows()

    for rowIdx = 1, count do
        local item    = self.data[rowIdx]
        local poolRow = self._rowPool[rowIdx]
        local frame   = poolRow.frame

        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -(rowIdx - 1) * self.row_height)
        frame:Show()

        if rowIdx % 2 == 0 then poolRow.bg:Show() else poolRow.bg:Hide() end

        for idx, field in ipairs(self.fields) do
            local value
            if item[field.field] ~= nil then value = item[field.field]
            elseif item[string.lower(field.field)] ~= nil then value = item[string.lower(field.field)]
            else value = item[string.gsub(field.field, "_", "")]
            end
            self:_updateCell(poolRow.cells[idx], value, field, item)
        end
    end

    for i = count + 1, #self._rowPool do
        self._rowPool[i].frame:Hide()
    end

    wipe(self.rows)
    for i = 1, count do
        self.rows[i] = self._rowPool[i].frame
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
        self.sortState.column    = fieldName
        self.sortState.ascending = false
    end
    self:applySort()
    self:updateHeader()
    self:updateRows()
end

function tablev2:normalizeSortValue(value)
    if value == nil or value == "" or value == "-" then return nil end
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
        if v ~= nil then table.insert(cleanData, v) end
    end
    self.data = cleanData

    local fieldName = self.sortState.column
    local ascending = self.sortState.ascending

    table.sort(self.data, function(a, b)
        local function getValue(item)
            if not item then return nil end
            if item[fieldName] ~= nil then return item[fieldName]
            elseif item[string.lower(fieldName)] ~= nil then return item[string.lower(fieldName)]
            else return item[string.gsub(fieldName, "_", "")]
            end
        end

        local va = self:normalizeSortValue(getValue(a))
        local vb = self:normalizeSortValue(getValue(b))

        if va == nil and vb == nil then return false end
        if va == nil then return false end
        if vb == nil then return true  end

        if type(va) == "boolean" and type(vb) == "boolean" then
            if va == vb then return false end
            if ascending then return va == false else return va == true end
        end

        if type(va) == "number" and type(vb) == "number" then
            if va == vb then return false end
            if ascending then return va < vb else return va > vb end
        end

        va = tostring(va)
        vb = tostring(vb)
        if va == vb then return false end
        if ascending then return va < vb else return va > vb end
    end)
end

function tablev2:refresh(forceRows)
    if not self.container then return self end

    local containerWidth = self.container:GetWidth() or 0
    if containerWidth <= 0 then return self end
    if self.content and self.scrollFrame then
        local scrollWidth = self.scrollFrame:GetWidth() or 0
        if scrollWidth > 0 then
            self.content:SetWidth(scrollWidth)
        end
    end

    local oldWidth = self.totalColumnWidth or 0
    local oldCount = self._lastRowCount    or 0
    self:calculateFieldWidths()
    self:applySort()
    local newWidth = self.totalColumnWidth or 0
    local newCount = #(self.data or {})
    local newRevision = tonumber(self.dataRevision) or 0

    local widthChanged    = (oldWidth ~= newWidth)
    local rowCountChanged = (oldCount ~= newCount)
    local needsRows = forceRows or widthChanged or rowCountChanged or not self.rows or #self.rows == 0

    if not self.header or widthChanged then
        self:updateHeader()
    end
    if needsRows then
        self:updateRows()
    end
    self._lastRowCount = newCount
    self._lastDataRevision = newRevision
    return self
end