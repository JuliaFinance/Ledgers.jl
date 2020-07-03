"""
Ledgers

This package provides support for general financial ledgers

See README.md for the full documentation

Copyright 2019-2020, Eric Forgy, Scott P. Jones and other contributors

Licensed under MIT License, see LICENSE.md
"""
module Ledgers

using UUIDs, StructArrays, AbstractTrees
using Instruments
import Instruments: instrument, symbol, amount, name, currency

export Account, Ledger, Entry, AccountId, AccountCode, AccountInfo, AccountGroup
export id, balance, credit!, debit!, post!, instrument, currency, symbol, amount
export code, name, isdebit, iscontra, subaccounts, subgroups

abstract type Identifier end

struct AccountId <: Identifier
    value::UUID
end

AccountId() = AccountId(uuid4())

struct AccountCode
    value::String
end

abstract type AccountType{B <: Position} end

mutable struct Account{B <: Position} <: AccountType{B}
    id::AccountId
    balance::B
end

Account(balance::Position) = Account{typeof(balance)}(AccountId(), balance)

abstract type AccountNode{B <: Position} <: AccountType{B} end

struct AccountInfo{B <: Position} <: AccountNode{B}
    account::Account{B}
    code::AccountCode
    name::String
    isdebit::Bool
    iscontra::Bool
end

function AccountInfo(account::Account{B}, code, name, isdebit=true; parent=nothing) where {B <: Position}
    if parent === nothing
        return AccountInfo{B}(account, code, name, isdebit, false)
    else
        acc = AccountInfo{B}(account, code, name, isdebit, parent.isdebit !== isdebit)
        push!(parent.subaccounts, acc)
        return acc
    end
end

struct AccountGroup{B <: Position} <: AccountNode{B}
    id::AccountId
    code::AccountCode
    name::String
    isdebit::Bool
    iscontra::Bool
    subaccounts::StructArray{AccountInfo{B}}
    subgroups::StructArray{AccountGroup{B}}
end

function AccountGroup(
        ::B,
        code,
        name,
        isdebit=true;
        id=AccountId(),
        subaccounts=StructArray(Vector{AccountInfo{B}}()),
        subgroups=StructArray(Vector{AccountGroup{B}}()),
        parent=nothing
    ) where {B <: Position}
    if parent === nothing
        return AccountGroup{B}(id, code, name, isdebit, false, subaccounts, subgroups)
    else
        acc = AccountGroup{B}(id, code, name, isdebit, parent.isdebit !== isdebit, subaccounts, subgroups)
        push!(parent.subgroups, acc)
        return acc
    end
end

# Identity function (to make code more generic)
account(acc::AccountType) = acc
account(info::AccountInfo) = info.account

code(acc::AccountNode) = acc.code
name(acc::AccountNode) = acc.name
isdebit(acc::AccountNode) = acc.isdebit
iscontra(acc::AccountNode) = acc.iscontra

subaccounts(group::AccountGroup) = group.subaccounts
subgroups(group::AccountGroup) = group.subgroups

id(acc::AccountType) = account(acc).id

balance(acc) = account(acc).balance
function balance(group::AccountGroup{B}) where {B <: Position}
    btot = zero(B)
    for acc in group.subaccounts.account
        btot += balance(acc)
    end
    for grp in group.subgroups
        btot += balance(grp)
    end
    btot
end

instrument(::AccountType{B}) where {B <: Position} = instrument(B)

symbol(::AccountType{B}) where {B <: Position} = symbol(B)

currency(::AccountType{B}) where {B <: Position} = currency(B)

amount(acc::AccountType) = amount(balance(acc))

debit!(acc::Account, amt::Position) = (acc.balance += amt)
credit!(acc::Account, amt::Position) = (acc.balance -= amt)

struct Entry{B <: Position}
    debit::AccountInfo{B}
    credit::AccountInfo{B}
end

function post!(entry::Entry, amt::Position)
    debit!(account(entry.debit), amt)
    credit!(account(entry.credit), amt)
    entry
end

struct Ledger{P <: Position}
    indexes::Dict{AccountId,Int}
    accounts::StructArray{Account{P}}

    function Ledger(accounts::Vector{Account{P}}) where {P <: Position}
        indexes = Dict{AccountId,Int}()
        for (index, account) in enumerate(accounts)
            indexes[id(account)] = index
        end
        new{P}(indexes, StructArray(accounts))
    end
end

Base.getindex(ledger::Ledger, ix) = ledger.accounts[ix]
Base.getindex(ledger::Ledger, id::AccountId) =
    ledger.accounts[ledger.indexes[id]]
Base.getindex(ledger::Ledger, array::AbstractVector{<:AccountId}) =
    ledger.accounts[broadcast(id->ledger.indexes[id], array)]

function add_account!(ledger::Ledger, acc::Account)
    push!(ledger.accounts, acc)
    ledger.indexes[id(acc)] = length(ledger.accounts)
end




# const chartofaccounts = Dict{String,AccountGroup{<:Cash}}()

# function getledger(a::AccountGroup)
#     while !isequal(a,a.parent)
#         a = a.parent
#     end
#     return a
# end

# function add(a::AccountGroup)
#         haskey(chartofaccounts,a.code) && error("AccountGroup with code $(a.code) already exists.")
#         chartofaccounts[a.code] = a
#         return a
# end

# iscontra(a::AccountGroup) = !isequal(a,a.parent) && !isequal(a.parent,getledger(a)) && !isequal(a.parent.isdebit,a.isdebit)

# function loadchart(ledgername,ledgercode,csvfile)
#     data, headers = readdlm(csvfile,',',String,header=true)
#     nrow,ncol = size(data)

#     ledger = add(AccountGroup(ledgername,ledgercode))
#     for i = 1:nrow
#         row = data[i,:]
#         code = row[1]
#         name = row[2]
#         parent = chartofaccounts[row[3]]
#         isdebit = isequal(row[4],"Debit")
#         add(AccountGroup(parent,name,code,isdebit))
#     end
#     return ledger
# end

# function trim(a::AccountGroup,newparent::AccountGroup=AccountGroup(a.parent.name,a.parent.code))
#     newaccount = isequal(a,a.parent) ? newparent : AccountGroup(newparent,a.name,a.code,a.isdebit,a.balance)
#     for subaccount in a.subaccounts
#         balance(subaccount).amount > 0. && trim(subaccount,newaccount)
#     end
#     return newaccount
# end

Base.show(io::IO, id::Identifier) = print(io, id.value)

Base.show(io::IO, code::AccountCode) = print(io, code.value)

Base.show(io::IO, acc::Account) = print(io, "$(string(id(acc))): $(balance(acc))")

Base.show(io::IO, acc::AccountNode) = print_tree(io, acc)

Base.show(io::IO, entry::Entry) = print_tree(io, entry)

AbstractTrees.children(acc::AccountGroup) = vcat(Vector(subgroups(acc)), Vector(subaccounts(acc)))

AbstractTrees.printnode(io::IO, acc::AccountNode) = 
    print(io, "[$(code(acc))] $(name(acc)): $(isdebit(acc) ? balance(acc) : -balance(acc))")

AbstractTrees.children(entry::Entry) = [entry.debit, entry.credit]

AbstractTrees.printnode(io::IO, ::Entry) = print(io, "Entry:")

end # module Ledgers
