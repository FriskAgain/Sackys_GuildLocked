local addonName, ns = ...
local mailexception = {
    initialSyncDone = false,
    transactions = {},
    transactionQueue = {},
    transactionMaxAge = 60 * 60 * 24 * 1, -- 1 day
    processingTransactions = false,
    timerForResponseRunning = false
}
if not ns.sync then ns.sync = {} end
ns.sync.mailexception = mailexception

local function txKey(tx)
    return table.concat({
        tx.t, -- timestamp
        tx.u, -- username
        tx.d, -- deleted
    }, "|")
end

function mailexception.initialize()
    if not SGLKMailExceptions then
        SGLKMailExceptions = {}
    end
    if not SGLKMailExceptions[ns.globals.SERVERNAME.."-"..ns.globals.GUILDNAME] then
        SGLKMailExceptions[ns.globals.SERVERNAME.."-"..ns.globals.GUILDNAME] = {}
    end

    mailexception.readTransactions()
end

function mailexception.enqueueTransactions(transactions)
    if type(transactions) == "table" then
        for _, tx in ipairs(transactions) do
            table.insert(mailexception.transactionQueue, tx)
        end
    end
    mailexception:processTransactionQueue()
end

function mailexception:processTransactionQueue()
    if mailexception.processingTransactions then return end
    mailexception.processingTransactions = true

    local existing = {}
    local cleanedMap = {}

    for _, tx in ipairs(mailexception.transactions) do
        existing[txKey(tx)] = true
    end

    local added = 0

    while #mailexception.transactionQueue > 0 do
        local tx = table.remove(mailexception.transactionQueue, 1)
        local key = tx.t .. ":" .. tx.u
        if not (cleanedMap[key] and tx.t and tx.t <= cleanedMap[key]) then
            if not (tx.t and (time() - tx.t > mailexception.transactionMaxAge)) and not existing[txKey(tx)] then
                mailexception._RecordTransaction(tx)
                existing[txKey(tx)] = true
                added = added + 1
            end
        end
    end

    mailexception.transactions = mailexception.filterDeletedTransactions(mailexception.transactions)
    ns.log.debug("Mailexception: Transactions processed, new added: " .. tostring(added))
    mailexception.processingTransactions = false

    if ns.sync.base.userSyncFailed or mailexception.initialSyncDone then return end
    mailexception.initialSyncDone = true

    ns.log.info("Mailexception: Synchronization done")

    C_Timer.After(15, function()
        mailexception.returnTransactionsToSelectedUsers()
    end)
end

function mailexception._RecordTransaction(tx)
    table.insert(mailexception.transactions, tx)
end

function mailexception.returnTransactionsToSelectedUsers()
    if not mailexception.transactions or #mailexception.transactions == 0 then
        ns.log.debug("No transactions to return.")
        return
    end

    local selectedUsers = ns.sync.base.selectedUsers
    if not selectedUsers or #selectedUsers == 0 then
        ns.log.debug("No selected users to return transactions to.")
        return
    end

    for _, user in ipairs(selectedUsers) do
        ns.networking.SendWhisper("PROV_MAIL_EXCEPTIONS", mailexception.transactions, user)
    end
end

function mailexception.writeTransactions()
    if not mailexception.transactions then return end
    if not SGLKMailExceptions[ns.globals.SERVERNAME.."-"..ns.globals.GUILDNAME] then return end

    local result = ns.helpers.encrypt(mailexception.transactions)
    SGLKMailExceptions[ns.globals.SERVERNAME.."-"..ns.globals.GUILDNAME] = result
end

function mailexception.readTransactions()
    if not SGLKMailExceptions[ns.globals.SERVERNAME.."-"..ns.globals.GUILDNAME] then return end
    local transactions = ns.helpers.decrypt(SGLKMailExceptions[ns.globals.SERVERNAME.."-"..ns.globals.GUILDNAME])
    -- local transactions = SGLKMailExceptions[ns.globals.SERVERNAME.."-"..ns.globals.GUILDNAME]
    local filtered = mailexception.filterDeletedTransactions(transactions)
    mailexception.transactions = filtered
end

function mailexception.filterDeletedTransactions(transactions)
    local filtered = {}
    local deletedMap = {}
    -- Zuerst alle Lösch-Transaktionen merken (und deren Timestamp)
    for _, tx in ipairs(transactions) do
        if tx.d and tx.u and tx.t then
            deletedMap[tx.u] = math.max(deletedMap[tx.u] or 0, tx.t)
        end
    end
    -- Dann alle gültigen Transaktionen übernehmen
    for _, tx in ipairs(transactions) do
        local isOld = tx.t and (time() - tx.t > mailexception.transactionMaxAge)
        local isObsolete = tx.u and deletedMap[tx.u] and tx.t and tx.t < deletedMap[tx.u]
        -- Lösch-Transaktion selbst immer behalten
        if not isOld and not isObsolete then
            table.insert(filtered, tx)
        end
    end
    return filtered
end

function mailexception.getList()
    if not mailexception.transactions then
        return {}
    end
    local filtered = mailexception.filterDeletedTransactions(mailexception.transactions)

    local list = {}
    for _, tx in ipairs(filtered) do
        if tx.u and tx.d == 0 then
            list[tx.u] = tx.t
        end
    end

    local sorted = {}
    for u, t in pairs(list) do
        table.insert(sorted, {u = u, t = t})
    end
    table.sort(sorted, function(a, b) return a.t > b.t end)

    return sorted
end
