struct Entry{C<:Cash,A<:Real}
    _debit::Account{C,A}
    _credit::Account{C,A}
end
# const entries = Dict{String,Entry}()

function debit!(a::Account{C,A},c::Position{C,A}) where C where A
    !isempty(a._subaccounts) && error("Can only debit accounts with no subaccounts.")
    a._balance = a._isdebit ? a._balance+c : a._balance-c
    return a
end

function credit!(a::Account{C,A},c::Position{C,A}) where C where A
    !isempty(a._subaccounts) && error("Can only credit accounts with no subaccounts.")
    a._balance = a._isdebit ? a._balance-c : a._balance+c
    return a
end

function post!(entry::Entry,amount::Position{C,A}) where C where A
    debit!(entry._debit,amount)
    credit!(entry._credit,amount)
end
