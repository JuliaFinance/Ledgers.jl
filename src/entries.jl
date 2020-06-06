struct Entry
    debit::Account
    credit::Account
end

function debit!(a::Account,c::Position)
    !isempty(a.subaccounts) && error("Can only debit accounts with no subaccounts.")
    a.balance = a.isdebit ? a.balance+c : a.balance-c
    return a
end

function credit!(a::Account,c::Position)
    !isempty(a.subaccounts) && error("Can only credit accounts with no subaccounts.")
    a.balance = a.isdebit ? a.balance-c : a.balance+c
    return a
end

function post!(entry::Entry,amount::Position)
    debit!(entry.debit,amount)
    credit!(entry.credit,amount)
    getledger(entry.debit)
end
