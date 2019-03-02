mutable struct Account{C<:Cash}
    _parent::Account{C}
    _name::String
    _code::String
    _isdebit::Bool
    _balance::Position{C}
    _subaccounts::Vector{Account{C}}

    function Account{C}(parent::Account{C},name,code,isdebit) where C
        a = new(parent,name,code,isdebit,Position(C(),0.),Vector{Account{C}}())
        push!(parent._subaccounts,a)
        # haskey(chartofaccounts,code) && error("Account with code $(code) already exists.")
        # chartofaccounts[code] = a
        return a
    end

    function Account{C}(name::String,code) where C
        a = new()
        a._parent = a
        a._name = name
        a._code = code
        a._isdebit = true
        a._balance = Position(C(),0.)
        a._subaccounts = Vector{Account{C}}()
        # haskey(chartofaccounts,code) && error("Account with code $(code) already exists.")
        # chartofaccounts[code] = a
        return a
    end
end
Account(parent::Account{C},name,code,isdebit,::C=FI.USD) where C<:Cash = Account{C}(parent,name,code,isdebit)
Account(name::String,code,::C=FI.USD) where C<:Cash = Account{C}(name,code)
const chartofaccounts = Dict{String,Account{<:Cash}}()

function get_ledger(a::Account{C}) where C
    while !isequal(a,a._parent)
        a = a._parent
    end
    return a
end

function add(a::Account{C}) where C
        haskey(chartofaccounts,a._code) && error("Account with code $(a._code) already exists.")
        chartofaccounts[a._code] = a
        return a
end

currency(a::Account{C}) where C = C
parent(a::Account{C}) where C = a._parent
name(a::Account{C}) where C = a._name
isdebit(a::Account{C}) where C = a._isdebit
function balance(a::Account{C}) where C
    isempty(a._subaccounts) && return a._balance
    b = Position{C}(0.)
    for account in a._subaccounts
        if isequal(a._isdebit,account._isdebit)
            b += balance(account)
        else
            b -= balance(account)
        end
    end
    return b
end
subaccounts(a::Account{C}) where C = a._subaccounts

iscontra(a::Account{C}) where C = !isequal(a,a._parent) && !isequal(a._parent,get_ledger(a)) && !isequal(a._parent._isdebit,a._isdebit)

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

function trim(account::Account{C},newparent::Account{C}=Account(account._parent._name,account._parent._code)) where C
    newaccount = isequal(account,account._parent) ? newparent : Account{C}(newparent,account._name,account._code,account._isdebit)
    newaccount._balance = account._balance
    for subaccount in account._subaccounts
        if balance(subaccount).amount > 0.
            trim(subaccount,newaccount)
        end
    end
    return newaccount
end
