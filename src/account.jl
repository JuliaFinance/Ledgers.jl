struct GeneralLedger{C} end
struct DebitGroup{C} end
struct CreditGroup{C} end
struct DebitAccount{C} end
struct CreditAccount{C} end

mutable struct Account{C<:Currency}
    parent::Union{Account,Nothing}
    name::String
    code::Union{String,Nothing}
    isdebit::Union{Bool,Nothing}
    balance::Union{Position{C},Nothing}
    subaccounts::Union{Vector{Account},Nothing}
    chart::Union{Dict{String,Account},Nothing}

    function Account{C}(parent,name,code,isdebit,balance,subaccounts,chart) where C<:Currency 
        a = new(parent,name,code,isdebit,balance,subaccounts,chart)
        if !isnothing(parent)
            push!(parent.subaccounts,a)
            if isnothing(subaccounts)
                add(a)
            end
        end
        return a
    end
end

function get_ledger(a::Account)
    p = a
    while !isnothing(p.parent)
        p = p.parent
    end
    return p
end

function add(a::Account)
    ledger = get_ledger(a)
    ledger.chart[a.code] = a
end

function accounttype(a::Account{C}) where C
    if isnothing(a.parent)
        return GeneralLedger{C}()
    elseif a.isdebit
        if isnothing(a.subaccounts)
            return DebitAccount{C}()
        else
            return DebitGroup{C}()
        end
    else
        if isnothing(a.subaccounts)
            return CreditAccount{C}()
        else
            return CreditGroup{C}()
        end
    end
end

DebitAccount(p,n,c,b::Position{C}=Position(Currencies.USD,0.)) where C = Account{C}(p,n,c,true,b,nothing,nothing)
CreditAccount(p,n,c,b::Position{C}=Position(Currencies.USD,0.)) where C = Account{C}(p,n,c,false,b,nothing,nothing)
DebitGroup(p,n,c,::C=Currencies.USD) where C = Account{C}(p,n,c,true,nothing,Vector{Account}(),nothing)
CreditGroup(p,n,c,::C=Currencies.USD) where C = Account{C}(p,n,c,false,nothing,Vector{Account}(),nothing)
GeneralLedger(n,::C=Currencies.USD) where C = Account{C}(nothing,n,nothing,true,nothing,Vector{Account}(),Dict{String,Account}())

currency(a::Account{C}) where C = C()

balance(a::Account) = balance(a,accounttype(a))
balance(a::Account{C}, ::Union{DebitAccount{C},CreditAccount{C}}) where C = a.balance
function balance(a::Account{C}, ::Any) where C
    b = Position{C}(0.)
    for account in a.subaccounts
        if isequal(a.isdebit,account.isdebit)
            b += balance(account)
        else
            b -= balance(account)
        end
    end
    return b
end
