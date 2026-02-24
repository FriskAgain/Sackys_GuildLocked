local addonName, ns = ...
local option_defaults = {}
ns.option_defaults = option_defaults

function option_defaults.initialize()
    -- SavedVariables: DB first
    if type(SGLKDB) ~= "table" then SGLKDB = {} end
    if type(SGLKDB.chars) ~= "table" then SGLKDB.chars = {} end
    if type(SGLKDB.addonStatus) ~= "table" then SGLKDB.addonStatus = {} end
    if type(SGLKDB.guildLog) ~= "table" then SGLKDB.guildLog = {} end
    if type(SGLKDB.profile) ~= "table" then SGLKDB.profile = {} end

    ns.db = SGLKDB

    -- SavedVariables: options
    if type(SGLKOptions) ~= "table" then SGLKOptions = {} end
    ns.options = SGLKOptions

    if type(ns.options.debug) ~= "boolean" then
        ns.options.debug = false
    end

    if type(ns.options.minimap) ~= "table" then
        ns.options.minimap = {}
    end

    -- Officer visibility setting (0=GM, 1=Officer, 2=2.Officer)
    if type(ns.db.profile.logMinRank) ~= "number" then
        ns.db.profile.logMinRank = 2
    end
end