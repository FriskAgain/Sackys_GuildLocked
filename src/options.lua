local addonName, ns = ...
local options = nil
local option_defaults = {}
ns.option_defaults = option_defaults

function option_defaults.initialize()
    if type(SGLKOptions) ~= "table" then
        SGLKOptions = {}
    end

    ns.options = SGLKOptions

    if type(ns.options.debug) ~= "boolean" then
        ns.options.debug = false
    end

    if type(ns.options.minimap) ~= "table" then
        ns.options.minimap = {}
    end

    if type(SGLKDB) ~= "table" then
    SGLKDB = {}
    end

    if type(SGLKDB.chars) ~= "table" then
    SGLKDB.chars = {}
    end

    ns.db = SGLKDB


end