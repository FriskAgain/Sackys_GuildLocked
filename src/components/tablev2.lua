local addonName, ns = ...
if not ns.components then ns.components = {} end
local tablev2 = {}
ns.components.tablev2 = tablev2

tablev2.__index = tablev2

function tablev2:new(parent, metadata, data, row_height)

    if not parent then error("Parent frame is required") end
    if not metadata then error("Metadata is required") end

    local obj = setmetatable({}, self)

    obj.container = CreateFrame("Frame", nil, parent)
    obj.container:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    obj.container:SetSize(700, parent:GetHeight())
    obj.container:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    obj.metadata = metadata or {}
    obj.data = data or {}
    obj.row_height = row_height or 20
    obj.fields = {}

    for k, v in pairs(obj.metadata) do
        if v.header and v.field then
            table.insert(obj.fields, {key = k, header = v.header, field = v.field})
        end
    end
    table.sort(obj.fields, function(a, b)
        return a.key < b.key
    end)

    obj.rows = {}
    obj.scrollFrame = CreateFrame("ScrollFrame", nil, obj.container, "UIPanelScrollFrameTemplate")
    obj.scrollFrame:SetPoint("TOPLEFT", obj.container, "TOPLEFT", 0, -obj.row_height)
    obj.scrollFrame:SetPoint("BOTTOMRIGHT", obj.container, "BOTTOMRIGHT", 0, 0)
    obj.content = CreateFrame("Frame", nil, obj.scrollFrame)
    obj.scrollFrame:SetScrollChild(obj.content)
    local scrollbar = obj.scrollFrame.ScrollBar

    scrollbar:ClearAllPoints()
    scrollbar:SetPoint(
        "TOPRIGHT",
        obj.scrollFrame,
        "TOPRIGHT",
        -66,   -- negativ værdi flytter den til venstre
        0
    )
    scrollbar:SetPoint(
        "BOTTOMRIGHT",
        obj.scrollFrame,
        "BOTTOMRIGHT",
        -80,   -- samme offset her
        16
    )
    obj.sortState = {
        column = nil,
        ascending = true
    }
    _G.MyAddonTable = obj
    obj:refresh()
    return obj
end

function tablev2:refresh()
    self:calculateFieldWidths()
    self:applySort()
    self:updateHeader()
    self:updateRows()
end

function tablev2:setData(newData)
    self.data = newData or {}
    self:refresh()
end


function tablev2:calculateFieldWidths()
    if not self.fields or #self.fields == 0 then return end

    local fieldWidths = {}
    for i, field in ipairs(self.fields) do
        local maxWidth = 0
        -- Header berücksichtigen
        local headerWidth = string.len(tostring(field.header)) * 8
        if headerWidth > maxWidth then maxWidth = headerWidth end
        for _, item in ipairs(self.data) do
            local value = item[field.field] or item[string.lower(field.field)] or item[string.gsub(field.field, "_", "")] or ""
            local text = tostring(value)
            local width = string.len(text) * 8
            if width > maxWidth then maxWidth = width end
        end
        local minWidth = 60

-- gør name kolonne bredere
if field.field == "online" then
    minWidth = 70
end

-- gør profession kolonner bredere
if field.field == "addon_active" then
    minWidth = 120
end
fieldWidths[i] = math.max(maxWidth, minWidth)
    end
    self.fieldWidths = fieldWidths
    local totalColumnWidth = 0
    for _, width in ipairs(fieldWidths) do
        totalColumnWidth = totalColumnWidth + width
    end
    self.totalColumnWidth = totalColumnWidth
    return self
end

function tablev2:updateHeader()
    if self.header then
        self.header:Hide()
        self.header:SetParent(nil)
    end
    self.header = CreateFrame("Frame", nil, self.container)
    self.header:SetSize(self.totalColumnWidth, self.row_height)
    self.header:SetPoint("TOPLEFT", self.container, "TOPLEFT", 0, 0)

local x = 0

for i, field in ipairs(self.fields) do
    local width = self.fieldWidths[i]
    local button = CreateFrame("Button", nil, self.header)

    button:SetPoint("TOPLEFT", self.header, "TOPLEFT", x, 0)
    button:SetSize(width, self.row_height)
    button:SetFrameLevel(self.header:GetFrameLevel() + 10)

    local fs = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetAllPoints(button)
    fs:SetJustifyH("LEFT")

    local arrow = ""
    if self.sortState.column == field.field then
        if self.sortState.ascending then
            arrow = " |TInterface\\Buttons\\UI-SortArrow:12:12:0:0:16:16:0:16:0:16|t"
        else
            arrow = " |TInterface\\Buttons\\UI-SortArrow:12:12:0:0:16:16:0:16:16:0|t"
        end
    end

fs:SetText(field.header .. "  " .. arrow)
    button:SetScript("OnClick", function()
    self:sortByColumn(field.field)
    end)

    button:SetScript("OnEnter", function()
        fs:SetTextColor(1, 0.82, 0)
    end)

    button:SetScript("OnLeave", function()
        fs:SetTextColor(1, 1, 1)
    end)
    x = x + width
    end
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
        -- Setze die Größe passend zu den Daten
        wipe(self.rows)
        local totalColumnWidth = 0

        for _, width in ipairs(self.fieldWidths) do
            totalColumnWidth = totalColumnWidth + width
        end
        self.content:SetSize(self.totalColumnWidth, #self.data * self.row_height)
    end

    self.rows = {}

    local visibleWidth = self.scrollFrame:GetWidth()

    -- fallback hvis width er 0 (kan ske første frame)
    if visibleWidth == 0 then
        visibleWidth = self.container:GetWidth() - self.scrollFrame.ScrollBar:GetWidth()
    end

    if self.metadata.sort and not self.sortState.column then
        local sortOrder = {}
        local sortKeys = {}
        for k in pairs(self.metadata.sort) do
            table.insert(sortKeys, k)
        end
        table.sort(sortKeys)
        for _, k in ipairs(sortKeys) do
            local v = self.metadata.sort[k]
            table.insert(sortOrder, {key = k, field = v.field, order = v.order or "asc"})
        end
        table.sort(self.data, function(a, b)
            for _, sortDef in ipairs(sortOrder) do
                local field = sortDef.field
                local order = sortDef.order
                local va = tostring(a[field]) or ""
                local vb = tostring(b[field]) or ""
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

    for rowIdx, item in ipairs(self.data) do
    local row = CreateFrame("Frame", nil, self.content)
    row:SetSize(self.totalColumnWidth, self.row_height)
    row:SetPoint(
        "TOPLEFT",
        self.content,
        "TOPLEFT",
        0,
        -(rowIdx-1)*self.row_height
    )

    local x = 0

    -- horizontal line
    self:createLine(
        row,
        0,
        -self.row_height,
        self.totalColumnWidth,
        1,
        0.3, 0.3, 0.3, 1
    )

    for idx, field in ipairs(self.fields) do
        local width = self.fieldWidths[idx] or 60
        -- vertical line
        self:createLine(
            row,
            x,
            0,
            1,
            self.row_height,
            0.3, 0.3, 0.3, 1
        )
        local value = item[field.field]
        local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")

        fs:SetPoint("TOPLEFT", row, "TOPLEFT", x + 4, -2)
        fs:SetWidth(width)
        fs:SetText(tostring(value or ""))
        fs:SetJustifyH("LEFT")

        if type(value) == "boolean" then
            if value then
                fs:SetText("Yes")
                fs:SetTextColor(0.3, 0.9, 0.3)
            else
                fs:SetText("No")
                fs:SetTextColor(1, 0.3, 0.3)
            end
        end
        x = x + width
    end
    table.insert(self.rows, row)
    end
end

function tablev2:updateFieldValue(name, field, value)
    if not name or not field or not value then return end
    for i, row in ipairs(self.data) do
        if row.name == Ambiguate(name, "none") then
            row[field] = value
            break
        end
    end

    self:refresh()
    return self
end

function tablev2:createLine(parent, x, y, width, height, r, g, b, a)
    if not parent then
        return
    end
    local line = parent:CreateTexture(nil, "BACKGROUND")
    line:SetColorTexture(r or 0.5, g or 0.5, b or 0.5, a or 1)
    line:SetPoint(
        "TOPLEFT",
        parent,
        "TOPLEFT",
        x or 0,
        y or 0
    )
    line:SetSize(
        width or 1,
        height or 1
    )
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

    if value == nil then return nil end
    if value == "" then return nil end
    if value == "-" then return nil end

    if type(value) == "string" then
        local num = tonumber(value)
        if num then return num end
        return value:lower()
    end
    return value
end

function tablev2:applySort()

    if not self.sortState.column then return end

    -- remove nil holes
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

        return item[fieldName]
            or item[string.lower(fieldName)]
            or item[string.gsub(fieldName, "_", "")]
    end

    local va = self:normalizeSortValue(getValue(a))
    local vb = self:normalizeSortValue(getValue(b))

    -- nil handling
    if va == nil and vb == nil then
        return false
    elseif va == nil then
        return false
    elseif vb == nil then
        return true
    end

    -- boolean handling
    if type(va) == "boolean" and type(vb) == "boolean" then

        if va == vb then
            return false
        end

        if ascending then
            return va == false and vb == true
        else
            return va == true and vb == false
        end
    end

    -- number handling
    if type(va) == "number" and type(vb) == "number" then

        if va == vb then
            return false
        end

        if ascending then
            return va < vb
        else
            return va > vb
        end

    end

    -- string handling
    va = tostring(va)
    vb = tostring(vb)

    if va == vb then
        return false
    end

    if ascending then
        return va < vb
    else
        return va > vb
    end

end)

end