mutable struct Account{C<:Cash,F<:FinancialInstrument,A<:Real}
    _parent::Account{C,<:FinancialInstrument}
    _name::String
    _code::String
    _isdebit::Bool
    _balance::Position{F,A}
    _subaccounts::Vector{Account{C,<:FinancialInstrument}}

    function Account{C,F,A}(parent::Account{C,<:FinancialInstrument},name,code,isdebit,balance::Position{F,A}=Position(FI.USD,0.)) where {C,F,A}
        a = new(parent,name,code,isdebit,balance,Vector{Account{C,<:FinancialInstrument}}())
        push!(parent._subaccounts,a)
        return a
    end

    function Account{F,F,A}(name::String,code,balance::Position{F,A}=Position(FI.USD,0.)) where {F,A}
        a = new()
        a._parent = a
        a._name = name
        a._code = code
        a._isdebit = true
        a._balance = balance
        a._subaccounts = Vector{Account{F,<:FinancialInstrument}}()
        return a
    end
end
Account(parent::Account{C},name,code,isdebit,balance::Position{F,A}=Position(FI.USD,0.)) where {C,F,A} = Account{C,F,A}(parent,name,code,isdebit,balance)
Account(name::String,code,balance::Position{F,A}=Position(FI.USD,0.)) where {F,A} = Account{F,F,A}(name,code,balance)
const chartofaccounts = Dict{String,Account{<:Cash}}()

function get_ledger(a::Account)
    while !isequal(a,a._parent)
        a = a._parent
    end
    return a
end

function add(a::Account)
        haskey(chartofaccounts,a._code) && error("Account with code $(a._code) already exists.")
        chartofaccounts[a._code] = a
        return a
end

parent(a::Account) = a._parent
name(a::Account) = a._name
isdebit(a::Account) = a._isdebit
function balance(a::Account{C,F,A}) where {C,F,A}
    isempty(a._subaccounts) && return FX.convert(Position{C,A},a._balance)
    b = zero(Position{C,A})
    for account in a._subaccounts
        if isequal(a._isdebit,account._isdebit)
            b += balance(account)
        else
            b -= balance(account)
        end
    end
    return b::Position{C,A}
end
subaccounts(a::Account) = a._subaccounts

iscontra(a::Account) = !isequal(a,a._parent) && !isequal(a._parent,get_ledger(a)) && !isequal(a._parent._isdebit,a._isdebit)

function loadchart(ledgername,ledgercode,csvfile)
    data, headers = readdlm(csvfile,',',String,header=true)
    nrow,ncol = size(data)

    ledger = add(Account(ledgername,ledgercode))
    for i = 1:nrow
        row = data[i,:]
        code = row[1]
        name = row[2]
        parent = chartofaccounts[row[3]]
        isdebit = isequal(row[4],"Debit")
        add(Account(parent,name,code,isdebit))
    end
    return ledger
end

function trim(a::Account,newparent::Account=Account(a._parent._name,a._parent._code))
    newaccount = isequal(a,a._parent) ? newparent : Account(newparent,a._name,a._code,a._isdebit,a._balance)
    for subaccount in a._subaccounts
        balance(subaccount).amount > 0. && trim(subaccount,newaccount)
    end
    return newaccount
end
