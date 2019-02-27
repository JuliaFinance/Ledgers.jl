mutable struct Account{C<:Cash}
    parent::Account{C}
    name::String
    code::String
    isdebit::Bool
    __balance::Position{C} ## Use `balance(account)` instead
    subaccounts::Vector{Account{C}}

    function Account{C}(parent::Account{C},name,code,isdebit) where C
        a = new(parent,name,code,isdebit,Position(C(),0.),Vector{Account{C}}())
        push!(parent.subaccounts,a)
        haskey(chartofaccounts,code) && error("Account with code $(code) already exists.")
        chartofaccounts[code] = a
        return a
    end

    function Account{C}(name::String,code) where C
        a = new()
        a.parent = a
        a.name = name
        a.code = code
        a.isdebit = true
        a.__balance = Position(C(),0.)
        a.subaccounts = Vector{Account{C}}()
        haskey(chartofaccounts,code) && error("Account with code $(code) already exists.")
        chartofaccounts[code] = a
        return a
    end
end
Account(parent::Account{C},name,code,isdebit,::C=FI.USD) where C<:Cash = Account{C}(parent,name,code,isdebit)
Account(name::String,code,::C=FI.USD) where C<:Cash = Account{C}(name,code)
const chartofaccounts = Dict{String,Account}()

function get_ledger(a::Account{C}) where C
    while !isequal(a,a.parent)
        a = a.parent
    end
    return a
end

function balance(a::Account{C}) where C
    isempty(a.subaccounts) && return a.__balance
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

currency(a::Account{C}) where C = C()
iscontra(a::Account{C}) where C = !isequal(a,a.parent) && !isequal(a.parent,get_ledger(a)) && !isequal(a.parent.isdebit,a.isdebit)