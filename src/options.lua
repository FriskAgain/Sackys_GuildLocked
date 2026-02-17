local addonName, ns = ...
local options = nil
local option_defaults = {}
ns.option_defaults = option_defaults

function option_defaults.initialize()
    if type(GuildFoundOptions) ~= "table" then
        GuildFoundOptions = {}
    end

    ns.options = GuildFoundOptions

    if type(ns.options.debug) ~= "boolean" then
        ns.options.debug = false
    end

    if type(ns.options.minimap) ~= "table" then
        ns.options.minimap = {}
    end

    if type(GuildFoundDB) ~= "table" then
    GuildFoundDB = {}
    end

    if type(GuildFoundDB.chars) ~= "table" then
    GuildFoundDB.chars = {}
    end

    ns.db = GuildFoundDB


end