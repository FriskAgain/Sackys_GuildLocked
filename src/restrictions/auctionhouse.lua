local addonName, ns = ...
local auctionhouse = {}
if not ns.restrictions then ns.restrictions = {} end
ns.restrictions.auctionhouse = auctionhouse

local lastBlockedAt = 0
local BLOCK_LOG_COOLDOWN = 3

function auctionhouse.handle()
    ns.log.error("Auction house usage not allowed.")

    local now = GetTime and GetTime() or 0
    if now - lastBlockedAt >= BLOCK_LOG_COOLDOWN then
        lastBlockedAt = now

        if ns.guildLog and ns.guildLog.send then
            ns.guildLog.send("Blocked Auction House access.", {
                kind = "blocked",
                broadcast = true
            })
        end
    end

    if AuctionFrame and AuctionFrame:IsShown() then
        C_Timer.After(0, function()
            CloseAuctionHouse()
        end)
    end
end