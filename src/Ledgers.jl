"""
Ledgers

This package provides support for general financial ledgers

See README.md for the full documentation

Copyright 2019-2020, Eric Forgy, Scott P. Jones and other contributors

Licensed under MIT License, see LICENSE.md
"""
module Ledgers

using UUIDs, StructArrays, AbstractTrees
using Assets, Instruments, Currencies

export Account, Ledger, Entry, Identifier, AccountId, AccountCode, AccountInfo, AccountGroup
export id, balance, credit!, debit!, post!, instrument, currency, symbol, amount
export code, name, isdebit, iscontra, subaccounts, subgroups

abstract type Identifier end

struct AccountId <: Identifier
    value::UUID
end

AccountId() = AccountId(uuid4())

macro id_str(id)
    AccountId(id)
end

struct AccountCode
    value::String
end

macro code_str(code)
    AccountCode(code)
end

abstract type AccountType{P <: Position} end

mutable struct Account{P <: Position} <: AccountType{P}
    id::AccountId
    balance::P
end

Account(balance::Position) = Account{typeof(balance)}(AccountId(), balance)

abstract type AccountNode{P <: Position} <: AccountType{P} end

struct AccountInfo{P <: Position} <: AccountNode{P}
    account::Account{P}
    code::AccountCode
    name::String
    isdebit::Bool
    iscontra::Bool
end

function AccountInfo(account::Account{P}, code, name, isdebit=true; parent=nothing) where {P <: Position}
    if parent === nothing
        return AccountInfo{P}(account, code, name, isdebit, false)
    else
        acc = AccountInfo{P}(account, code, name, isdebit, parent.isdebit !== isdebit)
        push!(parent.subaccounts, acc)
        return acc
    end
end

struct AccountGroup{P <: Position} <: AccountNode{P}
    id::AccountId
    code::AccountCode
    name::String
    isdebit::Bool
    iscontra::Bool
    subaccounts::StructArray{AccountInfo{P}}
    subgroups::StructArray{AccountGroup{P}}
end

function AccountGroup(
        ::Type{P},
        code,
        name,
        isdebit=true;
        id=AccountId(),
        subaccounts=StructArray(Vector{AccountInfo{P}}()),
        subgroups=StructArray(Vector{AccountGroup{P}}()),
        parent=nothing
    ) where {P <: Position}
    if parent === nothing
        return AccountGroup{P}(id, code, name, isdebit, false, subaccounts, subgroups)
    else
        acc = AccountGroup{P}(id, code, name, isdebit, parent.isdebit !== isdebit, subaccounts, subgroups)
        push!(parent.subgroups, acc)
        return acc
    end
end

# Identity function (to make code more generic)
account(acc::AccountType) = acc

account(info::AccountInfo) = info.account

id(acc::AccountType) = account(acc).id

balance(acc) = account(acc).balance

function balance(group::AccountGroup{P}) where {P <: Position}
    btot = zero(P)
    for acc in group.subaccounts.account
        btot += balance(acc)
    end
    for grp in group.subgroups
        btot += balance(grp)
    end
    btot
end

code(acc::AccountNode) = acc.code

name(acc::AccountNode) = acc.name

isdebit(acc::AccountNode) = acc.isdebit

iscontra(acc::AccountNode) = acc.iscontra

subaccounts(group::AccountGroup) = group.subaccounts

subgroups(group::AccountGroup) = group.subgroups

instrument(::AccountType{P}) where {P <: Position} = instrument(P)

# import Instruments: symbol, currency, instrument, position, amount

Instruments.symbol(::AccountType{P}) where {I,P <: Position{I}} = symbol(I)

Instruments.currency(::AccountType{P}) where {I,P <: Position{I}} = currency(I)

Instruments.instrument(::AccountType{P}) where {I,P <: Position{I}} = instrument(I)

Instruments.position(::AccountType{P}) where {I,P <: Position{I}} = position(I)

Instruments.amount(acc::AccountType) = amount(balance(acc))

debit!(acc::Account, amt::Position) = (acc.balance += amt)

credit!(acc::Account, amt::Position) = (acc.balance -= amt)

struct Entry{P <: Position}
    debit::AccountInfo{P}
    credit::AccountInfo{P}
end

function post!(entry::Entry, amt::Position)
    debit!(account(entry.debit), amt)
    credit!(account(entry.credit), amt)
    entry
end

struct LedgerId <: Identifier
    value::UUID
end

LedgerId() = LedgerId(uuid4())

struct Ledger{P <: Position}
    id::LedgerId
    indexes::Dict{AccountId,Int}
    codes::Dict{AccountCode,Int}
    accounts::StructArray{Account{P}}
end

function Ledger(accounts::Vector{AccountInfo{P}}; id=LedgerId()) where {P <: Position}
    indexes = Dict{AccountId,Int}()
    codes = Dict{AccountCode,Int}()
    for (index, account) in enumerate(accounts)
        indexes[account.id] = index
        codes[account.code] = index
    end
    Ledger{P}(id, indexes, codes, StructArray(account.(accounts)))
end

Ledger(::Type{P}) where {P<:Position} = Ledger(Vector{AccountInfo{P}}())

function add_account!(ledger::Ledger, acc::AccountInfo)
    push!(ledger.accounts, acc)
    ledger.indexes[id(acc)] = length(ledger.accounts)
    ledger.codes[code(acc)] = length(ledger.accounts)
end

Base.getindex(ledger::Ledger, ix) = ledger.accounts[ix]

Base.getindex(ledger::Ledger, id::AccountId) =
    ledger.accounts[ledger.indexes[id]]

Base.getindex(ledger::Ledger, code::AccountCode) =
    ledger.accounts[ledger.codes[code]]

Base.getindex(ledger::Ledger, array::AbstractVector{<:AccountId}) =
    ledger.accounts[broadcast(id->ledger.indexes[id], array)]

Base.getindex(ledger::Ledger, array::AbstractVector{<:AccountCode}) =
    ledger.accounts[broadcast(code->ledger.codes[code], array)]

struct EntityId <: Identifier
    value::UUID
end

EntityId() = EntityId(uuid4())

struct Entity
    id::EntityId
    name::String
    ledgers::Dict{P,Ledger{P}} where {P<:Position}
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
