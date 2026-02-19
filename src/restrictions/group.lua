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

            local name = Ambiguate(UnitName(unit), "none")

            if name and not ns.helpers.isGuildMember(name) then

                ns.log.debug("Non-guild member detected:", name)

                -- prevent loop
                ns.restrictions.leavingGroup = true

                LeaveParty()

                SendChatMessage(
                    "You are not in my guild. Leaving group.",
                    "WHISPER",
                    nil,
                    name
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
