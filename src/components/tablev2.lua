local addonName, ns = ...
if not ns.components then ns.components = {} end
local tablev2 = {}
ns.components.tablev2 = tablev2

tablev2.__index = tablev2

function tablev2:new(parent, metadata, data, row_height)
    if not parent then error("Parent frame is required") end
    if not metadata then error("Metadata is required") end

    local obj = setmetatable({}, self)

    self.container = CreateFrame("Frame", nil, parent)
    self.container:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    self.container:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -23, 0)

    self.metadata = metadata or {}
    self.data = data or {}
    self.row_height = row_height or 20

    self.fields = {}
    for k, v in pairs(self.metadata) do
        if v.header and v.field then
            table.insert(self.fields, {key = k, header = v.header, field = v.field})
        end
    end
    table.sort(self.fields, function(a, b) return a.key < b.key end)

    self.rows = {}
    self.scrollFrame = CreateFrame("ScrollFrame", nil, self.container, "UIPanelScrollFrameTemplate")
    self.scrollFrame:SetPoint("TOPLEFT", self.container, "TOPLEFT", 0, -self.row_height)
    self.scrollFrame:SetPoint("BOTTOMRIGHT", self.container, "BOTTOMRIGHT", 0, 0)

    self.content = CreateFrame("Frame", nil, self.scrollFrame)
    self.content:SetSize(self.scrollFrame:GetWidth(), #self.data * self.row_height)
    self.scrollFrame:SetScrollChild(self.content)

    self:refresh()

    return self
end

function tablev2:refresh()
    self:calculateFieldWidths()
    self:updateHeader()
    self:updateRows()

    return self
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
        fieldWidths[i] = math.max(maxWidth, 60)
    end

    self.fieldWidths = fieldWidths

    return self

end

function tablev2:updateHeader()
    if self.header then
        self.header:Hide()
        self.header:SetParent(nil)
    end

    self.header = CreateFrame("Frame", nil, self.container)
    self.header:SetSize(self.container:GetWidth(), self.row_height)
    self.header:SetPoint("TOPLEFT", self.container, "TOPLEFT", 0, 0)

    local x = 0
    for i, field in ipairs(self.fields) do
        local fs = self.header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("TOPLEFT", self.header, "TOPLEFT", x, 0)
        fs:SetWidth(self.fieldWidths[i])
        fs:SetText(field.header)
        fs:SetJustifyH("LEFT")
        x = x + self.fieldWidths[i]
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
        self.content:SetSize(self.container:GetWidth(), #self.data * self.row_height)
    end

    self.rows = {}

    if self.metadata.sort then
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
        row:SetSize(self.content:GetWidth(), self.row_height)
        row:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -(rowIdx-1)*self.row_height)
        local x = 0
        for idx, field in ipairs(self.fields) do
            local value = item[field.field]
            local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            fs:SetPoint("TOPLEFT", row, "TOPLEFT", x, 0)
            fs:SetWidth(self.fieldWidths[idx])
            fs:SetText(tostring(value))
            fs:SetJustifyH("LEFT")

            if type(value) == "boolean" then
                if value then
                    fs:SetTextColor(0.3, 0.9, 0.3) -- green
                else
                    fs:SetTextColor(1, 0.3, 0.3) -- red
                end
            end

            x = x + self.fieldWidths[idx]
        end
        table.insert(self.rows, row)
    end

    return self
end

function tablev2:updateFieldValue(name, field, value)
    if not name or not field or not value then return end
    for i, row in ipairs(self.data) do
        if row.name == Ambiguate(name, "none") then
            row[field] = value
            break
        end
    end

    return self
end
