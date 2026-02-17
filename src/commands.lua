local addonName, ns = ...
local commands = {}
ns.commands = commands

SLASH_GUILDFOUND1 = "/gf"
function commands.SlashHandler(msg)

    local rank = ns.helpers.getGuildMemberRank(ns.globals.CHARACTERNAME)
    if type(rank) ~= "number" then
        return
    end

    if not (rank <= 2) then
        ns.log.info("Permission denied (only Guild Master and Officers allowed)")
        return
    end

    msg = msg:match("^%s*(.-)%s*$")
    local args = {}
    for word in string.gmatch(msg, "%S+") do
        table.insert(args, word)
    end

    if args[1] == "test" then
        --
    elseif args[1] == "mailexceptions" and args[2] == "delete" and args[3] then
        local name = args[3]
        local tx = {
            u = name,
            t = time(),
            d = 1
        }
        ns.sync.mailexception._RecordTransaction(tx)
        ns.networking.SendToGuild("BROADCAST_MAIL_EXCEPTION", tx)
        ns.log.info("Mailexception: " .. name .. " deleted")
    elseif args[1] == "mailexceptions" and args[2] == "delete" then
        ns.log.info("/gf mailexceptions delete <charname>")
    elseif args[1] == "mailexceptions" and args[2] == "add" and args[3] then
        local name = args[3]
        local tx = {
            u = name,
            t = time(),
            d = 0
        }
        ns.sync.mailexception._RecordTransaction(tx)
        ns.networking.SendToGuild("BROADCAST_MAIL_EXCEPTION", tx)
        ns.log.info("Mailexception: " .. name .. " added")
    elseif args[1] == "mailexceptions" and args[2] == "add" then
        ns.log.info("/gf mailexceptions add <charname>")
    elseif args[1] == "mailexceptions" and args[2] == "list" then
        local list = ns.sync.mailexception.getList()
        local isEmpty = true
        for _, entry in ipairs(list) do
            isEmpty = false
            local dateStr = date("%Y-%m-%d %H:%M:%S", entry.t)
            ns.log.info(dateStr .. " | " .. entry.u)
        end
        if isEmpty then ns.log.info("Mailexception: None") end
    elseif args[1] == "mailexceptions" then
        ns.log.info("/gf mailexceptions <option>")
        ns.log.info("Options: list, add, delete")
    else
        ns.log.info("/gf <option>")
        ns.log.info("Options: mailexceptions")
    end
end
SlashCmdList["GUILDFOUND"] = commands.SlashHandler
