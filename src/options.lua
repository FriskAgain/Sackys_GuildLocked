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
    ns.db.profile = ns.db.profile or {}

    -------------------------------------------------
    -- Schema Migration System
    -------------------------------------------------
    local schema = tonumber(ns.db.profile._schemaVersion or 0) or 0

    -- v1: old single-rank migration
    if schema < 1 then
        if ns.db.profile.logMinRank == nil then
            ns.db.profile.logMinRank = 3
        elseif ns.db.profile.logMinRank == 2 then
            ns.db.profile.logMinRank = 3
        end
        ns.db.profile._schemaVersion = 1
        schema = 1
    end

    -- v2: move from single logMinRank to per-realm logMinRankByRealm
    if schema < 2 then
        ns.db.profile.logMinRankByRealm = ns.db.profile.logMinRankByRealm or {}
        local oldRank = ns.db.profile.logMinRank
        if type(oldRank) == "number" then
            ns.db.profile.logMinRankByRealm["Thunderstrike"] =
                ns.db.profile.logMinRankByRealm["Thunderstrike"] or 3
            ns.db.profile.logMinRankByRealm["Dreamscythe"] =
                ns.db.profile.logMinRankByRealm["Dreamscythe"] or 1
            ns.db.profile.logMinRankByRealm._default =
                ns.db.profile.logMinRankByRealm._default or oldRank
        else
            ns.db.profile.logMinRankByRealm["Thunderstrike"] =
                ns.db.profile.logMinRankByRealm["Thunderstrike"] or 3
            ns.db.profile.logMinRankByRealm["Dreamscythe"] =
                ns.db.profile.logMinRankByRealm["Dreamscythe"] or 1
            ns.db.profile.logMinRankByRealm._default =
                ns.db.profile.logMinRankByRealm._default or 3
        end
        ns.db.profile._schemaVersion = 2
        schema = 2
    end
    ns.db.profile.logMinRankByRealm = ns.db.profile.logMinRankByRealm or {}
    if type(ns.db.profile.logMinRankByRealm["Thunderstrike"]) ~= "number" then
        ns.db.profile.logMinRankByRealm["Thunderstrike"] = 3
    end
    if type(ns.db.profile.logMinRankByRealm["Dreamscythe"]) ~= "number" then
        ns.db.profile.logMinRankByRealm["Dreamscythe"] = 1
    end
    if type(ns.db.profile.logMinRankByRealm._default) ~= "number" then
        ns.db.profile.logMinRankByRealm._default = 3
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
end