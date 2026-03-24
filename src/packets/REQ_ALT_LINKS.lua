local addonName, ns = ...

local ALT_LINKS_FULL = {}
ns.packets = ns.packets or {}
ns.packets.ALT_LINKS_FULL = ALT_LINKS_FULL

function ALT_LINKS_FULL.handle(sender, payload)
    if not ns.sync or not ns.sync.altlinks or not ns.sync.altlinks.applyFull then
        return
    end

    local ok, err = ns.sync.altlinks.applyFull(payload, sender)
    if not ok and ns.log and ns.log.error then
        ns.log.error("ALT_LINKS_FULL apply failed: " .. tostring(err))
    end
end