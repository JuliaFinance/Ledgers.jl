mutable struct Account
    _parent::Account
    _name::String
    _code::String
    _isdebit::Bool
    _balance::Position
    _subaccounts::Vector{Account}

    function Account(parent::Account,name,code,isdebit,balance::Position=Position(FI.USD,0.))
        a = new(parent,name,code,isdebit,balance,Vector{Account}())
        push!(parent._subaccounts,a)
        return a
    end

    function Account(name::String,code,balance::Position=Position(FI.USD,0.))
        a = new()
        a._parent = a
        a._name = name
        a._code = code
        a._isdebit = true
        a._balance = balance
        a._subaccounts = Vector{Account}()
        return a
    end
end
const chartofaccounts = Dict{String,Account}()

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
function balance(a::Account)
    isempty(a._subaccounts) && return a._balance
    b = zero(typeof(a._balance))
    for account in a._subaccounts
        if isequal(a._isdebit,account._isdebit)
            b += balance(account)
        else
            b -= balance(account)
        end
    end
    return b
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
