local addonName, ns = ...

local REQ_ALT_LINKS = {}
ns.packets = ns.packets or {}
ns.packets.REQ_ALT_LINKS = REQ_ALT_LINKS

function REQ_ALT_LINKS.handle(sender, payload)
    if not ns.sync or not ns.sync.altlinks or not ns.sync.altlinks.handleRequest then
        return
    end

    local ok, err = ns.sync.altlinks.handleRequest(sender, payload)
    if not ok and ns.log and ns.log.debug then
        ns.log.debug("REQ_ALT_LINKS ignored: " .. tostring(err))
    end
end