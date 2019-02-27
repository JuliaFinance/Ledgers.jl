struct GeneralLedger{C} end
struct DebitGroup{C} end
struct CreditGroup{C} end
struct DebitAccount{C} end
struct CreditAccount{C} end

struct Module
    balance::Function
end

mutable struct Account{C<:Cash}
    parent::Union{Account,Nothing}
    name::String
    code::String
    isdebit::Bool
    balance::Union{Position{C},Module}
    subaccounts::Vector{Account}
    chart::Union{Dict{String,Account},Nothing}

    function Account{C}(parent,name,code,isdebit,balance,subaccounts,chart) where C<:Cash
        a = new(parent,name,code,isdebit,balance,subaccounts,chart)
        isnothing(parent) || push!(parent.subaccounts,a)
        add(a)
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
    isnothing(a.parent) && return GeneralLedger{C}()
    if a.isdebit
        isempty(a.subaccounts) && return DebitAccount{C}()
        return DebitGroup{C}()
    else
        isempty(a.subaccounts) && return CreditAccount{C}()
        return CreditGroup{C}()
    end
end

balance(a::Account{C}) where C = balance(a,a.balance)::Position{C}
balance(a::Account{C},b::Position{C}) where C = b
balance(a::Account{C},m::Module) where C = m.balance(a)

balance(a::Account{C}, ::Union{DebitAccount{C},CreditAccount{C}}) where C = a.balance

function _aggregate(a::Account{C}) where C
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
Aggregate = Module(_aggregate)

DebitAccount(p,n,c,b::Union{Position{C},Module}=Position(FI.USD,0.)) where C = Account{C}(p,n,c,true,b,Vector{Account}(),nothing)
CreditAccount(p,n,c,b::Union{Position{C},Module}=Position(FI.USD,0.)) where C = Account{C}(p,n,c,false,b,Vector{Account}(),nothing)
DebitGroup(p,n,c,::C=FI.USD) where C = Account{C}(p,n,c,true,Aggregate,Vector{Account}(),nothing)
CreditGroup(p,n,c,::C=FI.USD) where C = Account{C}(p,n,c,false,Aggregate,Vector{Account}(),nothing)
GeneralLedger(n,c,::C=FI.USD) where C = Account{C}(nothing,n,c,true,Aggregate,Vector{Account}(),Dict{String,Account}())

currency(a::Account{C}) where C = C()
iscontra(a::Account) = !isnothing(a.parent) && !isequal(a.parent,get_ledger(a)) && !isequal(a.parent.isdebit,a.isdebit)