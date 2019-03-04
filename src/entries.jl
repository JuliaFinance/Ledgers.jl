struct Entry
    _debit::Account
    _credit::Account
end

function debit!(a::Account,c::Position)
    !isempty(a._subaccounts) && error("Can only debit accounts with no subaccounts.")
    a._balance = a._isdebit ? a._balance+c : a._balance-c
    return a
end

function credit!(a::Account,c::Position)
    !isempty(a._subaccounts) && error("Can only credit accounts with no subaccounts.")
    a._balance = a._isdebit ? a._balance-c : a._balance+c
    return a
end

function post!(entry::Entry,amount::Position)
    debit!(entry._debit,amount)
    credit!(entry._credit,amount)
end
