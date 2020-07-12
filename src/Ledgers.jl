"""
Ledgers

This package provides support for general financial ledgers

See README.md for the full documentation

Copyright 2019-2020, Eric Forgy, Scott P. Jones and other contributors

Licensed under MIT License, see LICENSE.md
"""
module Ledgers

using UUIDs, StructArrays, AbstractTrees
import Instruments
using Instruments: Position
# Although importing Instruments is enough to extend the methods below, we still import
# them explicitly so we can use them like `Ledgers.position` instead of `Instruments.position`.
# Unfortunately, `Base` also exports `position`.
import Instruments: instrument, currency, symbol, position, amount

export Identifier, AccountId, AccountType, AccountWrapper, AccountNumber
export LedgerAccount, Ledger, Entry, Account, AccountGroup, ledgeraccount, add_account
export id, balance, credit!, debit!, post!
# Although the methods below are exported by Instruments, we export them explicitly 
# because we do not expect users to use `Instruments` directly.
export instrument, currency, symbol, position, amount

abstract type Identifier end

struct AccountId <: Identifier
    value::UUID
end

AccountId() = AccountId(uuid4())

struct AccountNumber
    value::String
end

AccountNumber() = AccountNumber("")

Base.convert(::Type{AccountNumber}, value::String) = AccountNumber(value)

abstract type AccountType{P <: Position} end

abstract type AccountWrapper{P <: Position} <: AccountType{P} end

account(acc::AccountType) = acc

account(acc::AccountWrapper) = acc.account

mutable struct LedgerAccount{P <: Position} <: AccountType{P}
    id::AccountId
    balance::P
end

function LedgerAccount(balance::P; ledger=nothing) where {P <: Position}
    ledger === nothing && return LedgerAccount{P}(AccountId(), balance)
    acc = LedgerAccount{P}(AccountId(), balance)
    push!(ledger.accounts, acc)
    acc
end

LedgerAccount(::Type{P}; ledger=nothing) where {P <: Position} =
    LedgerAccount(P(0), ledger=ledger)

ledgeraccount(acc::LedgerAccount) = acc

ledgeraccount(acc::AccountType) = account(acc).account

struct LedgerId <: Identifier
    value::UUID
end

LedgerId() = LedgerId(uuid4())

struct Account{P <: Position} <: AccountType{P}
    account::LedgerAccount{P}
    number::AccountNumber
    name::String
    isdebit::Bool
end

struct Ledger{P <: Position}
    id::LedgerId
    indexes::Dict{AccountId,Int}
    accounts::StructArray{LedgerAccount{P}}
end

function Ledger(accounts::Vector{LedgerAccount{P}}; id=LedgerId()) where {P <: Position}
    indexes = Dict{AccountId,Int}()
    for (index, account) in enumerate(accounts)
        indexes[account.id] = index
    end
    Ledger{P}(id, indexes, StructArray(ledgeraccount.(accounts)))
end

Ledger(::Type{P}) where {P <: Position} = Ledger(Vector{LedgerAccount{P}}())

function add_account(ledger::Ledger{P}, acc::LedgerAccount{P}) where {P <: Position}
    push!(ledger.accounts, ledgeraccount(acc))
    ledger.indexes[id(acc)] = length(ledger.accounts)
    ledger
end

struct AccountGroup{A <: AccountType}
    id::AccountId
    number::AccountNumber
    name::String
    isdebit::Bool
    indexes::Dict{AccountId,Int}
    accounts::StructArray{A}
    subgroups::StructArray{AccountGroup{A}}
end

function AccountGroup(
        ::Type{A};
        name::String="$(symbol(A)) Accounts",
        number="",
        isdebit=true,
        id=AccountId(),
        parent::Union{Nothing,AccountGroup{A}}=nothing
    ) where {A <: AccountType}
    indexes = Dict{AccountId,Int}()
    accounts = StructArray(Vector{A}())
    subgroups = StructArray(Vector{AccountGroup{A}}())
    if parent === nothing
        return AccountGroup{A}(id, number, name, isdebit, indexes, accounts, subgroups)
    else
        acc = AccountGroup{A}(id, number, name, isdebit, indexes, accounts, subgroups)
        push!(parent.subgroups, acc)
        return acc
    end
end

function Account(
        ::Type{P};
        name::String="$(symbol(P)) Account",
        number="",
        isdebit=true,
        parent::Union{Nothing,<:AccountGroup}=nothing,
        ledger::Union{Nothing,<:Ledger}=nothing
    ) where {P <: Position}
    account = LedgerAccount(P, ledger=ledger)
    parent === nothing && 
        return Account{P}(account, number, name, isdebit)
    acc = Account{P}(account, number, name, isdebit)
    add_account(parent, acc)
    acc
end

function add_account(grp::AccountGroup{A}, acc::A) where {A <: AccountType}
    push!(grp.accounts, acc)
    grp.indexes[id(acc)] = length(grp.accounts)
    grp
end

function add_account(grp::AccountGroup{A}, acc::AccountGroup{A}) where {A <: AccountType}
    push!(grp.subgroups, acc)
    grp
end

struct Entry{A <: AccountType}
    debit::A
    credit::A
end

id(acc::AccountType) = ledgeraccount(acc).id

id(acc::AccountGroup) = acc.id

balance(acc::AccountType) = ledgeraccount(acc).balance

function balance(group::AccountGroup{<:AccountType{P}}) where {P <: Position}
    btot = zero(P)
    for acc in group.accounts.account
        btot += balance(acc)
    end
    for grp in group.subgroups
        btot += balance(grp)
    end
    btot
end

Instruments.symbol(::Type{A}) where {P, A<:AccountType{P}} = symbol(P)

Instruments.currency(::Type{A}) where {P, A<:AccountType{P}} = currency(P)

Instruments.instrument(::Type{A}) where {P, A<:AccountType{P}} = instrument(P)

Instruments.position(::Type{A}) where {P, A<:AccountType{P}} = P

Instruments.amount(acc::AccountType) = amount(balance(acc))

debit!(acc::LedgerAccount, amt::Position) = (acc.balance += amt)

credit!(acc::LedgerAccount, amt::Position) = (acc.balance -= amt)

function post!(entry::Entry, amt::Position)
    debit!(ledgeraccount(entry.debit), amt)
    credit!(ledgeraccount(entry.credit), amt)
    entry
end

Base.getindex(ledger::Ledger, ix) = ledger.accounts[ix]

Base.getindex(ledger::Ledger, id::AccountId) =
    ledger.accounts[ledger.indexes[id]]

Base.getindex(ledger::Ledger, array::AbstractVector{<:AccountId}) =
    ledger.accounts[broadcast(id -> ledger.indexes[id], array)]

Base.getindex(grp::AccountGroup, ix) = grp.accounts.accounts[ix]

Base.getindex(grp::AccountGroup, id::AccountId) =
    grp.accounts.accounts[grp.indexes[id]]

Base.getindex(grp::AccountGroup, array::AbstractVector{<:AccountId}) =
    grp.accounts[broadcast(id -> grp.indexes[id], array)]

# struct EntityId <: Identifier
#     value::UUID
# end

# EntityId() = EntityId(uuid4())

# struct Entity
#     id::EntityId
#     name::String
#     ledgers::Dict{Type{<:Position},Ledger{<:AccountType}}
# end

# const chartofaccounts = Dict{String,AccountGroup{<:Cash}}()

# iscontra(a::AccountGroup) = !isequal(a,a.parent) && !isequal(a.parent,getledger(a)) && !isequal(a.parent.isdebit,a.isdebit)

# function loadchart(ledgername,ledgercode,csvfile)
#     data, headers = readdlm(csvfile,',',String,header=true)
#     nrow,ncol = size(data)

#     ledger = add(AccountGroup(ledgername,ledgercode))
#     for i = 1:nrow
#         row = data[i,:]
#         number = row[1]
#         name = row[2]
#         parent = chartofaccounts[row[3]]
#         isdebit = isequal(row[4],"Debit")
#         add(AccountGroup(parent,name,number,isdebit))
#     end
#     return ledger
# end

# function trim(a::AccountGroup,newparent::AccountGroup=AccountGroup(a.parent.name,a.parent.number))
#     newaccount = isequal(a,a.parent) ? newparent : AccountGroup(newparent,a.name,a.number,a.isdebit,a.balance)
#     for subaccount in a.accounts
#         balance(subaccount).amount > 0. && trim(subaccount,newaccount)
#     end
#     return newaccount
# end

function _print_account(io::IO, acc)
    iobuff = IOBuffer()
    hasproperty(acc,:number) && isa(acc.number,AccountNumber) && !isempty(acc.number.value) && print(iobuff,"[$(acc.number)] ")
    print(iobuff,acc.name,": ")
    if hasproperty(acc,:isdebit) && !acc.isdebit
        print(iobuff,-balance(acc))
    else
        print(iobuff,balance(acc))
    end
    print(io,String(take!(iobuff)))
end

Base.show(io::IO, id::Identifier) = print(io, id.value)

Base.show(io::IO, number::AccountNumber) = print(io, number.value)

Base.show(io::IO, acc::LedgerAccount) = print(io, "$(string(id(acc))): $(balance(acc))")

Base.show(io::IO, acc::AccountType) = _print_account(io, acc)

Base.show(io::IO, acc::AccountGroup) = print_tree(io, acc)

Base.show(io::IO, entry::Entry) = print_tree(io, entry)

Base.show(io::IO, ledger::Ledger) = print_tree(io, ledger)

Base.show(io::IO, a::Vector{<:AccountType}) = print_tree(io, a)

AbstractTrees.printnode(io::IO, acc::Ledger{P}) where {P <: Position} =
    print(io, "$(symbol(P)) Ledger: [$(acc.id)]")

AbstractTrees.children(acc::Ledger) = Vector(acc.accounts)

AbstractTrees.printnode(io::IO, acc::AccountGroup) = _print_account(io, acc)

AbstractTrees.children(acc::AccountGroup) = vcat(Vector(acc.subgroups), Vector(acc.accounts))

AbstractTrees.printnode(io::IO, b::Vector{<:AccountType}) =
    isempty(b) ? print(io, "Accounts: None") : print(io, "Accounts:")

AbstractTrees.children(b::Vector{<:AccountType}) = b

AbstractTrees.children(entry::Entry) = [entry.debit, entry.credit]

AbstractTrees.printnode(io::IO, ::Entry) = print(io, "Entry:")

end # module Ledgers
