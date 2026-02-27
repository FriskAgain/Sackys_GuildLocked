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

    ns.db.profile = ns.db.profile or {}
    ns.db = SGLKDB
    -------------------------------------------------
    -- Schema Migration System
    -------------------------------------------------
    local schema = tonumber(ns.db.profile._schemaVersion or 0) or 0
    if schema < 1 then
        if ns.db.profile.logMinRank == nil then
            ns.db.profile.logMinRank = 3
        elseif ns.db.profile.logMinRank == 2 then
            ns.db.profile.logMinRank = 3
        end
        ns.db.profile._schemaVersion = 1
    end

    -- SavedVariables: options
    if type(SGLKOptions) ~= "table" then SGLKOptions = {} end
    ns.options = SGLKOptions

    if type(ns.options.debug) ~= "boolean" then
        ns.options.debug = false
    end

    if type(ns.options.minimap) ~= "table" then
        ns.options.minimap = {}
    end

    -- Officer visibility setting (0=GM, 1=GM2, 2=Officer, 3=2.Officer)
    if type(ns.db.profile.logMinRank) ~= "number" then
        ns.db.profile.logMinRank = 3
    end
end