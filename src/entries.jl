struct Entry{C<:Cash}
    debit::Account{C}
    credit::Account{C}
    amount::Position{C}
end

function debit!(a::Account{C},c::Position{C}) where C
    !isempty(a.subaccounts) && error("Can only debit accounts with no subaccounts.")
    a.__balance = a.isdebit ? a.__balance+c : a.__balance-c
    return a
end

function credit!(a::Account{C},c::Position{C}) where C
    !isempty(a.subaccounts) && error("Can only credit accounts with no subaccounts.")
    a.__balance = a.isdebit ? a.__balance-c : a.__balance+c
    return a
end

function post!(e::Entry)
    debit!(e.debit,e.amount)
    credit!(e.credit,e.amount)
end
