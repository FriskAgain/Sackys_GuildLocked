local addonName, ns = ...

local group = {}
ns.restrictions = ns.restrictions or {}
ns.restrictions.group = group

-- Prevent leave spam loop
ns.restrictions.leavingGroup = ns.restrictions.leavingGroup or false

local function rosterReady()
    if not IsInGuild() then return false end
    local n = GetNumGuildMembers()
    return n and n > 0
end

local function checkUnit(unit)
    if not UnitExists(unit) then return true end

    local name, realm = UnitFullName(unit)
    if not name then return true end

    local full = realm and realm ~= "" and (name .. "-" .. realm) or name
    local short = Ambiguate(full, "none")

    if ns.helpers.isGuildMember(short) then
        return true
    end
    ns.log.debug("Non-guild member detected:" .. tostring(full))
    ns.restrictions.leavingGroup = true

    if LeaveParty then LeaveParty() end

    if SendChatMessage then
        SendChatMessage(
            "You are not in my guild. Leaving group.",
            "WHISPER",
            nil,
            full
        )
    end
    C_Timer.After(2, function()
        ns.restrictions.leavingGroup = false
    end)
    return false
end

function group.handle()
    -- Already leaving, do nothing
    if ns.restrictions.leavingGroup then return end
    -- Not in group, nothing to do
    if not IsInGroup() then return end

    -- Check if Roster
    if not rosterReady() then
        C_Timer.After(1, function()
            if IsInGroup() then group.handle() end
        end)
        return
    end
    -- Check player too for edge cases
    if not checkUnit("player") then return end
    if IsInRaid() then
        local n = GetNumGroupMembers()
        if i = 1, n do
            if not checkUnit("raid" .. i) then return end
        end
    else
        for i = 1, 4 do
            if not checkUnit("party" .. i) then return end
        end
    end
end