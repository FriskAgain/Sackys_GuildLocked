local addonName, ns = ...
local trade = {}
if not ns.restrictions then ns.restrictions = {} end
ns.restrictions.trade = trade

function trade.handle(name)
    ns.log.debug("trade.handle: name=" .. tostring(name))
    local target = name or UnitName("NPC") or UnitName("target")
    local shortName = true
    if not target or not ns.helpers.isGuildMember(target, shortName) then
        ns.log.error("Trade is only allowed with guild members.")
        if TradeFrame and TradeFrame:IsShown() then
            C_Timer.After(0.1, function()
                CloseTrade()
            end)
        end
        return
    end
end
