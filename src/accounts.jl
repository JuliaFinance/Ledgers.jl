mutable struct Account{C<:Cash,F<:Instrument,A<:Real}
    parent::Account{C,<:Instrument}
    name::String
    code::String
    isdebit::Bool
    balance::Position{F,A}
    subaccounts::Vector{Account{C,<:Instrument}}

    function Account{C,F,A}(parent::Account{C,<:Instrument},name,code,isdebit,balance::Position{F,A}=Position(Assets.USD,0.)) where {C,F,A}
        a = new(parent,name,code,isdebit,balance,Vector{Account{C,<:Instrument}}())
        push!(parent.subaccounts,a)
        return a
    end

    function Account{F,F,A}(name::String,code,balance::Position{F,A}=Position(Assets.USD,0.)) where {F,A}
        a = new()
        a.parent = a
        a.name = name
        a.code = code
        a.isdebit = true
        a.balance = balance
        a.subaccounts = Vector{Account{F,<:Instrument}}()
        return a
    end
end
Account(parent::Account{C},name,code,isdebit,balance::Position{F,A}=Position(Assets.USD,0.)) where {C,F,A} = Account{C,F,A}(parent,name,code,isdebit,balance)
Account(name::String,code,balance::Position{F,A}=Position(Assets.USD,0.)) where {F,A} = Account{F,F,A}(name,code,balance)
const chartofaccounts = Dict{String,Account{<:Cash}}()

function getledger(a::Account)
    while !isequal(a,a.parent)
        a = a.parent
    end
    return a
end

function add(a::Account)
        haskey(chartofaccounts,a.code) && error("Account with code $(a.code) already exists.")
        chartofaccounts[a.code] = a
        return a
end

parent(a::Account) = a.parent
name(a::Account) = a.name
isdebit(a::Account) = a.isdebit
function balance(a::Account{C,F,A}) where {C,F,A}
    isempty(a.subaccounts) && return FX.convert(Position{C,A},a.balance)
    b = zero(Position{C,A})
    for account in a.subaccounts
        if isequal(a.isdebit,account.isdebit)
            b += balance(account)
        else
            b -= balance(account)
        end
    end
    return b::Position{C,A}
end
subaccounts(a::Account) = a.subaccounts

iscontra(a::Account) = !isequal(a,a.parent) && !isequal(a.parent,getledger(a)) && !isequal(a.parent.isdebit,a.isdebit)

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

function trim(a::Account,newparent::Account=Account(a.parent.name,a.parent.code))
    newaccount = isequal(a,a.parent) ? newparent : Account(newparent,a.name,a.code,a.isdebit,a.balance)
    for subaccount in a.subaccounts
        balance(subaccount).amount > 0. && trim(subaccount,newaccount)
    end
    return newaccount
end
