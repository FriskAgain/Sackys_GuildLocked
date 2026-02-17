local addonName, ns = ...
local auctionhouse = {}
if not ns.restrictions then ns.restrictions = {} end
ns.restrictions.auctionhouse = auctionhouse

function auctionhouse.handle()
    ns.log.error("Auctionhouse usage not allowed.")
    if AuctionFrame and AuctionFrame:IsShown() then
        C_Timer.After(0, function()
            CloseAuctionHouse()
        end)
    end
end
