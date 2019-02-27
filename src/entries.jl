struct Entry{C<:Cash}
    debit::Account{C}
    credit::Account{C}
    amount::Position{C}
end

debit!(a::Account{C},c::Position{C}) where C = debit!(a,c,accounttype(a))
credit!(a::Account{C},c::Position{C}) where C = credit!(a,c,accounttype(a))

function debit!(a::Account{C},c::Position{C},::DebitAccount{C}) where C
    a.balance += c
    return a
end
function debit!(a::Account{C},c::Position{C},::CreditAccount{C}) where C
    a.balance -= c
    return a
end
function credit!(a::Account{C},c::Position{C},::CreditAccount{C}) where C
    a.balance += c
    return a
end
function credit!(a::Account{C},c::Position{C},::DebitAccount{C}) where C
    a.balance -= c
    return a
end

function post!(e::Entry)
    debit!(e.debit,e.amount)
    credit!(e.credit,e.amount)
end

