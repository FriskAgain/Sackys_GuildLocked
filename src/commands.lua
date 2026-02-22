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

local function ParseArgs(msg)
    msg = (msg or ""):match("^%s*(.-)%s*$")
    local args = {}
    for w in msg:gmatch("%S+") do args[#args+1] = w end
    return args
end

local function GetRank()
    if not (ns.helpers and ns.helpers.getGuildMemberRank) then return nil end
    return ns.helpers.getGuildMemberRank(UnitName("player"))
end

local function IsOfficer(rank)
    return type(rank) == "number" and rank <= 2
end

-- If roster isn't ready, stash the command and retry on GUILD_ROSTER_UPDATE
ns._pendingSlash = ns._pendingSlash or nil

function commands.TryRunPending()
    if not ns._pendingSlash then return end
    local msg = ns._pendingSlash
    ns._pendingSlash = nil
    commands.Run(msg)
end

function commands.Run(msg)
    if not IsInGuild() then
        ns.log.info("You must be in a guild to use " .. PRIMARY_CMD .. ".")
        return
    end
    local args = ParseArgs(msg)
    local cmd = (args[1] or ""):lower()
    local sub = (args[2] or ""):lower()
    -- Always allow help output for everyone
    if cmd == "" or cmd == "help" then
        PrintRootHelp()
        return
    end
    if cmd == "mailexceptions" and (sub == "" or sub == "help") then
        PrintMailexceptionHelp()
        return
    end
    -- Allow list for everyone
    if cmd == "mailexceptions" and sub == "list" then
        local list = ns.sync and ns.sync.mailexception and ns.sync.mailexception.getList
            and ns.sync.mailexception.getList() or nil
        if not list or #list == 0 then
            ns.log.info("Mailexception: None")
            return
        end
        for _, entry in ipairs(list) do
            local dateStr = date("%Y-%m-%d %H:%M:%S", entry.t)
            ns.log.info(dateStr .. " | " .. entry.u)
        end
        return
    end

    -- Actions below require officer + rank available
    local rank = GetRank()
    if type(rank) ~= "number" then
        if GuildRoster then
            GuildRoster()
        elseif C_GuildInfo and C_GuildInfo.GuildRoster then
            C_GuildInfo.GuildRoster()
        end
        ns._pendingSlash = msg or ""
        ns.log.info("Guild roster not ready yet - try again in a moment.")
        return
    end

    if cmd == "mailexceptions" and sub == "add" and args[3] then
        if not IsOfficer(rank) then
            ns.log.info("Permission denied (only Guild Master and Officers allowed)")
            return
        end
        local name = args[3]
        local tx = { u = name, t = time(), d = 0 }
        ns.sync.mailexception._RecordTransaction(tx)
        ns.networking.SendToGuild("BROADCAST_MAIL_EXCEPTIONS", tx)
        ns.log.info("Mailexception: " .. name .. " added")
        return
    end

    if cmd == "mailexceptions" and sub == "delete" and args[3] then
        if not IsOfficer(rank) then
            ns.log.info("Permission denied (only Guild Master and Officers allowed)")
            return
        end
        local name = args[3]
        local tx = { u = name, t = time(), d = 1 }
        ns.sync.mailexception._RecordTransaction(tx)
        ns.networking.SendToGuild("BROADCAST_MAIL_EXCEPTIONS", tx)
        ns.log.info("Mailexception: " .. name .. " deleted")
        return
    end
    
    if cmd == "mailexceptions" and sub == "add" then
        ns.log.info(PRIMARY_CMD .. " mailexceptions add <charname>")
        return
    end
    if cmd == "mailexceptions" and sub == "delete" then
        ns.log.info(PRIMARY_CMD .. " mailexceptions delete <charname>")
        return
    end

    PrintRootHelp()
end

function commands.SlashHandler(msg)
    commands.Run(msg or "")
end

SLASH_SGLK1 = PRIMARY_CMD
SLASH_SGLK2 = ALT_CMD
SLASH_SGLKLOG1 = "/sglklog"
SlashCmdList.SGLKLOG = function()
    if ns.ui and ns.ui.toggleGuildLog then
        ns.ui.toggleGuildLog()
    end
end
SlashCmdList["SGLK"] = function(msg)
    commands.SlashHandler(msg or "")
end