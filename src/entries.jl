struct Entry{C<:Cash}
    _debit::Account{C}
    _credit::Account{C}
end
# const entries = Dict{String,Entry}()

function debit!(a::Account{C},c::Position{C}) where C
    !isempty(a._subaccounts) && error("Can only debit accounts with no subaccounts.")
    a._balance = a._isdebit ? a._balance+c : a._balance-c
    return a
end

function credit!(a::Account{C},c::Position{C}) where C
    !isempty(a._subaccounts) && error("Can only credit accounts with no subaccounts.")
    a._balance = a._isdebit ? a._balance-c : a._balance+c
    return a
end

function post!(entry::Entry,amount::Position{C}) where C
    debit!(entry._debit,amount)
    credit!(entry._credit,amount)
end
