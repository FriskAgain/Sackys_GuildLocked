local addonName, ns = ...
local REQ_USERS = {}
ns.packets = ns.packets or {}
ns.packets.REQ_USERS = REQ_USERS

local function whisperTarget(sender)
    if ns.helpers and ns.helpers.getShort then
        return ns.helpers.getShort(sender)
    end
    return Ambiguate(sender, "none")
end

function REQ_USERS.handle(sender, payload)
    if not sender then return end

    -- ignore self
    local me = ns.globals and ns.globals.CHARACTERNAME
    if me and ns.helpers and ns.helpers.getKey then
        if ns.helpers.getKey(me) == ns.helpers.getKey(sender) then
            return
        end
    end

    local target = whisperTarget(sender)
    if not target or target == "" then return end

    ns.networking.SendWhisper("RSP_USERS", {}, target)
end
