mutable struct Account{C<:Cash,A<:Real}
    _parent::Account{C,A}
    _name::String
    _code::String
    _isdebit::Bool
    _balance::Position{C,A}
    _subaccounts::Vector{Account{C,A}}

    function Account{C,A}(parent::Account{C,A},name,code,isdebit,balance=Position(C(),0.)) where C where A
        a = new(parent,name,code,isdebit,balance,Vector{Account{C,A}}())
        push!(parent._subaccounts,a)
        return a
    end

    function Account{C,A}(name::String,code,balance=Position(C(),0.)) where C where A
        a = new()
        a._parent = a
        a._name = name
        a._code = code
        a._isdebit = true
        a._balance = balance
        a._subaccounts = Vector{Account{C,A}}()
        return a
    end
end
Account(parent::Account{C,A},name,code,isdebit,balance::Position{C,A}=Position(FI.USD,0.)) where C where A = Account{C,A}(parent,name,code,isdebit,balance)
Account(name::String,code,balance::Position{C,A}=Position(FI.USD,0.)) where C where A = Account{C,A}(name,code,balance)
const chartofaccounts = Dict{String,Account{<:Cash}}()

function get_ledger(a::Account{C,A}) where C where A
    while !isequal(a,a._parent)
        a = a._parent
    end
    return a
end

function add(a::Account{C,A}) where C where A
        haskey(chartofaccounts,a._code) && error("Account with code $(a._code) already exists.")
        chartofaccounts[a._code] = a
        return a
end

currency(a::Account{C,A}) where C where A = C
parent(a::Account{C,A}) where C where A = a._parent
name(a::Account{C,A}) where C where A = a._name
isdebit(a::Account{C,A}) where C where A = a._isdebit
function balance(a::Account{C,A}) where C where A
    isempty(a._subaccounts) && return a._balance
    b = Position{C,A}(0.)
    for account in a._subaccounts
        if isequal(a._isdebit,account._isdebit)
            b += balance(account)
        else
            b -= balance(account)
        end
    end
    return b
end
subaccounts(a::Account{C,A}) where C where A = a._subaccounts

iscontra(a::Account{C,A}) where C where A = !isequal(a,a._parent) && !isequal(a._parent,get_ledger(a)) && !isequal(a._parent._isdebit,a._isdebit)

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

function trim(a::Account{C,A},newparent::Account{C,A}=Account(a._parent._name,a._parent._code)) where C where A
    newaccount = isequal(a,a._parent) ? newparent : Account{C,A}(newparent,a._name,a._code,a._isdebit,a._balance)
    for subaccount in a._subaccounts
        balance(subaccount).amount > 0. && trim(subaccount,newaccount)
    end
    return newaccount
end
