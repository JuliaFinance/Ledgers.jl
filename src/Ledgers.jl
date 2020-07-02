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
using Assets
@cash USD

export Account, Ledger, Entry, AccountId, AccountCode, AccountInfo, AccountGroup
export id, balance, credit!, debit!, post!, instrument, symbol, amount, code, name, currency
export parent, subaccounts, subgroups

abstract type Identifier end

struct AccountId <: Identifier
    value::UUID
end

AccountId() = AccountId(uuid4())

struct AccountCode
    value::String
end

abstract type AccountType{P<:Position} end

mutable struct Account{P<:Position} <: AccountType{P}
    id::AccountId
    balance::P
end

Account(balance::Position) = Account{typeof(balance)}(AccountId(), balance)

abstract type AccountNode{P<:Position} <: AccountType{P} end

struct AccountInfo{P<:Position} <: AccountNode{P}
    account::Account{P}
    code::AccountCode
    name::String
    isdebit::Bool

    function AccountInfo{P}(account::Account{P}, code, name, isdebit=true, parent=nothing
                            ) where {P<:Position}
        #println("Create a new AccountInfo{$P}, id=$id, code=$code, name=$name")
        acc = new{P}(account, code, name, isdebit)
        parent === nothing || push!(parent.subaccounts, acc)
        acc
    end
end

AccountInfo(account::Account{P}, code, name, args...) where {P<:Position} =
    AccountInfo{P}(account, code, name, args...)

mutable struct AccountGroup{P<:Position} <: AccountNode{P}
    id::AccountId
    code::AccountCode
    name::String
    isdebit::Bool

    parent::Union{Nothing,AccountGroup{P}}
    subaccounts::Vector{AccountInfo{P}}
    subgroups::Vector{AccountGroup{P}}

    function AccountGroup{P}(id, code, name,
                             isdebit=true,
                             parent=nothing,
                             subaccounts=Vector{AccountInfo{P}}(),
                             subgroups=Vector{AccountGroup{P}}()
                             ) where {P<:Position}
        #println("Create a new AccountGroup{$P}, id=$id, code=$code, name=$name")
        acc = new{P}(id, code, name, isdebit, parent, subaccounts, subgroups)
        parent === nothing || push!(parent.subgroups, acc)
        acc
    end
end

AccountGroup(::P, code, name, args...) where {P<:Position} =
    AccountGroup{P}(AccountId(), code, name, args...)

# Identity function (to make code more generic)
account(acc::AccountType) = acc
account(info::AccountInfo) = info.account

code(acc::AccountNode) = acc.code
name(acc::AccountNode) = acc.name
isdebit(acc::AccountNode) = acc.isdebit

parent(group::AccountGroup) = group.parent
subaccounts(group::AccountGroup) = group.subaccounts
subgroups(group::AccountGroup) = group.subgroups

id(acc::AccountType) = account(acc).id

balance(acc) = account(acc).balance

function balance(grp::AccountGroup{P}) where {P<:Position}
    sa = subaccounts(grp)
    sg = subgroups(grp)
    (isempty(sa) ? zero(P) : sum(balance, sa)) + (isempty(sg) ? zero(P) : sum(balance, sg))
end

instrument(::AccountType{P}) where {P<:Position} = instrument(P)

symbol(::AccountType{P}) where {P<:Position} = symbol(P)

currency(::AccountType{P}) where {P<:Position} = currency(P)

amount(acc::AccountType) = amount(balance(acc))

debit!(acc::Account, amt::Position) = (acc.balance += amt)
credit!(acc::Account, amt::Position) = (acc.balance -= amt)

struct Entry{P<:Position}
    debit::AccountInfo{P}
    credit::AccountInfo{P}
end

function post!(entry::Entry, amt::Position)
    debit!(account(entry.debit), amt)
    credit!(account(entry.credit), amt)
    entry
end

# SPJ: we should probably retain the id of the Ledger here
struct Ledger{P<:Position}
    indexes::Dict{AccountId,Int}
    accounts::StructArray{Account{P}}

    function Ledger(accounts::Vector{Account{P}}) where {P<:Position}
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

function example()
    group = AccountGroup(USD(0), AccountCode("0000000"), "Account Group", false)
    assets = AccountGroup(USD(0), AccountCode("1000000"), "Assets", true, group)
    liabilities = AccountGroup(USD(0), AccountCode("2000000"), "Liabilities", false, group)
    cash = AccountInfo(Account(USD(0)), AccountCode("1010000"), "Cash", true, assets)
    payable = AccountInfo(Account(USD(0)), AccountCode("2010000"), "Accounts Payable", false, liabilities)

    entry = Entry(cash, payable)
    group, assets, liabilities, cash, payable, entry
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

AbstractTrees.children(acc::AccountGroup) = vcat(Vector(subgroups(acc)),Vector(subaccounts(acc)))

AbstractTrees.printnode(io::IO, acc::AccountNode) = 
    print(io, "[$(code(acc))] $(name(acc)): $(isdebit(acc) ? balance(acc) : -balance(acc))")

AbstractTrees.children(entry::Entry) = [entry.debit, entry.credit]

AbstractTrees.printnode(io::IO, ::Entry) = print(io, "Entry:")

# AbstractTrees.children(info::AccountInfo) =
#     isempty(subaccounts(info)) ? Vector{AccountInfo}() : subaccounts(info)
# AbstractTrees.printnode(io::IO,info::AccountInfo) =
#     print(io, "$(name(info)) ($(id(info))): $(balance(info))")

# Base.show(io::IO,info::AccountInfo) =
#     isempty(subaccounts(info)) ? printnode(io, info) : print_tree(io, info)

# Base.show(io::IO, e::Entry) =
#     print(io, "Entry:\n", "  Debit: $(e.debit)\n", "  Credit: $(e.credit)")

# function Base.show(io::IO, e::Entry)
#     print(io,
#           "Entry:\n",
#           "  Debit: $(name(e.debit)) ($(id(e.debit))): $(balance(e.debit))\n",
#           "  Credit: $(name(e.credit)) ($(id(e.credit))): $(balance(e.credit))\n")
# end

end # module Ledgers
