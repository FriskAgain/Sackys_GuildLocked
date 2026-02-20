local addonName, ns = ...

local group = {}
ns.restrictions = ns.restrictions or {}
ns.restrictions.group = group

-- Prevent leave spam loop
ns.restrictions.leavingGroup = ns.restrictions.leavingGroup or false

function group.handle()

    -- Already leaving, do nothing
    if ns.restrictions.leavingGroup then return end

    -- Not in group, nothing to do
    if not IsInGroup() then return end

    local numMembers = GetNumGroupMembers()

    for i = 1, numMembers do

        local unit

        if IsInRaid() then
            unit = "raid"..i
        else
            unit = "party"..i
        end

        if UnitExists(unit) then

            local name = UnitName(unit)
            local key = name and ns.helpers.getKey(name) or nil

            if key and not ns.helpers.isGuildMember(key) then

                ns.log.debug("Non-guild member detected:", key)

                -- prevent loop
                ns.restrictions.leavingGroup = true

                LeaveParty()

                SendChatMessage(
                    "You are not in my guild. Leaving group.",
                    "WHISPER",
                    nil,
                    key
                )

                -- reset protection after short delay
                C_Timer.After(2, function()
                    ns.restrictions.leavingGroup = false
                end)

                return

            end

        end

    end

end
