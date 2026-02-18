local addonName, ns = ...
local commands = {}
ns.commands = commands

local PRIMARY_CMD = "/sglk"
local ALT_CMD     = "/guildlocked"

local function PrintRootHelp()
    ns.log.info(PRIMARY_CMD .. " <option>")
    ns.log.info("Options: mailexceptions")
    ns.log.info("Alias: " .. ALT_CMD)
end

local function PrintMailexceptionHelp()
    ns.log.info(PRIMARY_CMD .. " mailexceptions <option>")
    ns.log.info("Options: list, add, delete")
end

function commands.SlashHandler(msg)

    local rank = ns.helpers.getGuildMemberRank(UnitName("player"))
    if type(rank) ~= "number" then
        ns.log.info("You must be in a guild to use "..PRIMARY_CMD..".")
        return
    end

    if rank > 2 then
        ns.log.info("Permission denied (only Guild Master and Officers allowed)")
        return
    end

    msg = (msg or ""):match("^%s*(.-)%s*$")
    local args = {}
    for word in string.gmatch(msg, "%S+") do
        args[#args+1] = word
    end

    local cmd = (args[1] or ""):lower()
    local sub = (args[2] or ""):lower()

    if args[1] == "test" then
        -- future 
        return

    elseif cmd == "mailexceptions" and sub == "delete" and args[3] then
        local name = args[3]
        local tx = { u = name, t = time(), d = 1 }
        ns.sync.mailexception._RecordTransaction(tx)
        ns.networking.SendToGuild("BROADCAST_MAIL_EXCEPTION", tx)
        ns.log.info("Mailexception: " .. name .. " deleted")
        return

    elseif cmd == "mailexceptions" and sub == "delete" then
        ns.log.info(PRIMARY_CMD .. " mailexceptions delete <charname>")
        return

    elseif cmd == "mailexceptions" and sub == "add" and args[3] then
        local name = args[3]
        local tx = { u = name, t = time(), d = 0 }
        ns.sync.mailexception._RecordTransaction(tx)
        ns.networking.SendToGuild("BROADCAST_MAIL_EXCEPTION", tx)
        ns.log.info("Mailexception: " .. name .. " added")
        return

    elseif cmd == "mailexceptions" and sub == "add" then
        ns.log.info(PRIMARY_CMD .. " mailexceptions add <charname>")
        return

    elseif cmd == "mailexceptions" and sub == "list" then
        local list = ns.sync.mailexception.getList()
        if not list or #list == 0 then
            ns.log.info("Mailexception: None")
            return
        end
        for _, entry in ipairs(list) do
            local dateStr = date("%Y-%m-%d %H:%M:%S", entry.t)
            ns.log.info(dateStr .. " | " .. entry.u)
        end
        return

    elseif cmd == "mailexceptions" then
        PrintMailexceptionHelp()
        return
    end

    PrintRootHelp()
end

SLASH_SGLK1 = PRIMARY_CMD
SLASH_SGLK2 = ALT_CMD
SlashCmdList["SGLK"] = function(msg)
    commands.SlashHandler(msg or "")
end