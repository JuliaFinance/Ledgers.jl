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

export Identifier, AccountId, AccountType, AccountNumber
export LedgerAccount, Ledger, Entry, Account, AccountGroup, ledgeraccount, add_account!
export id, balance, credit!, debit!, post!, instrument, currency, symbol, amount

abstract type Identifier end

struct AccountId <: Identifier
    value::UUID
end

AccountId() = AccountId(uuid4())

struct AccountNumber
    value::String
end

AccountNumber() = AccountNumber("")

abstract type AccountType{P <: Position} end

mutable struct LedgerAccount{P <: Position} <: AccountType{P}
    id::AccountId
    balance::P
end

function LedgerAccount(balance::P; ledger=nothing) where {P<:Position}
    ledger === nothing && return LedgerAccount{P}(AccountId(), balance)
    acc = LedgerAccount{P}(AccountId(), balance)
    push!(ledger.accounts,acc)
    acc
end

LedgerAccount(::Type{P}=Assets.USD; ledger=nothing) where {P<:Position} = 
    LedgerAccount(P(0),ledger=ledger)

ledgeraccount(acc::LedgerAccount) = acc

struct LedgerId <: Identifier
    value::UUID
end

struct Account{P <: Position} <: AccountType{P}
    account::LedgerAccount{P}
    number::AccountNumber
    name::String
    isdebit::Bool
    iscontra::Bool
end

function Account(::Type{P}, number::AccountNumber, name, isdebit=true; parent=nothing, ledger=nothing) where {P <: Position}
    account = LedgerAccount(P,ledger=ledger)
    parent === nothing && return Account{P}(account, number, name, isdebit, false)
    acc = Account{P}(account, number, name, isdebit, parent.isdebit !== isdebit)
    push!(parent.accounts, acc)
    acc
end

Account(::Type{P}=Assets.USD, number::String="",name::String="Default Account";ledger=nothing) where {P<:Position} =
    Account(P,AccountNumber(number),name,ledger=ledger)

ledgeraccount(acc::Account) = acc.account

LedgerId() = LedgerId(uuid4())

struct Ledger{P <: Position}
    id::LedgerId
    indexes::Dict{AccountId,Int}
    accounts::StructArray{LedgerAccount{P}}
end

function Ledger(accounts::Vector{Account{P}}; id=LedgerId()) where {P <: Position}
    indexes = Dict{AccountId,Int}()
    for (index, account) in enumerate(accounts)
        indexes[account.id] = index
    end
    Ledger{P}(id, indexes, StructArray(ledgeraccount.(accounts)))
end

Ledger(::Type{P}=Assets.USD) where {P<:Position} = Ledger(Vector{Account{P}}())

function add_account!(ledger::Ledger, acc)
    push!(ledger.accounts, ledgeraccount(acc))
    ledger.indexes[id(acc)] = length(ledger.accounts)
    ledger
end

struct AccountGroup{P <: Position}
    id::AccountId
    number::AccountNumber
    name::String
    isdebit::Bool
    iscontra::Bool
    accounts::StructArray{Account{P}}
    subgroups::StructArray{AccountGroup{P}}
end

function AccountGroup(
        ::Type{P},
        number,
        name,
        isdebit=true;
        id=AccountId(),
        accounts=StructArray(Vector{Account{P}}()),
        subgroups=StructArray(Vector{AccountGroup{P}}()),
        parent=nothing
    ) where {P <: Position}
    if parent === nothing
        return AccountGroup{P}(id, number, name, isdebit, false, accounts, subgroups)
    else
        acc = AccountGroup{P}(id, number, name, isdebit, parent.isdebit !== isdebit, accounts, subgroups)
        push!(parent.subgroups, acc)
        return acc
    end
end

add_account!(grp::AccountGroup, acc::AccountType) = push!(grp.accounts, acc)

add_account!(grp::AccountGroup, acc::AccountGroup) = push!(grp.subgroups, acc)

struct Entry{P <: Position}
    debit::Account{P}
    credit::Account{P}
end

id(acc::AccountType) = ledgeraccount(acc).id

id(acc::AccountGroup) = acc.id

balance(acc) = ledgeraccount(acc).balance

function balance(group::AccountGroup{P}) where {P <: Position}
    btot = zero(P)
    for acc in group.accounts.account
        btot += balance(acc)
    end
    for grp in group.subgroups
        btot += balance(grp)
    end
    btot
end

Instruments.symbol(::AccountType{P}) where {I,P <: Position{I}} = symbol(I)

Instruments.currency(::AccountType{P}) where {I,P <: Position{I}} = currency(I)

Instruments.instrument(::AccountType{P}) where {I,P <: Position{I}} = I

Instruments.position(::AccountType{P}) where {P <: Position} = P

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
    ledger.accounts[broadcast(id->ledger.indexes[id], array)]

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
#         haskey(chartofaccounts,a.number) && error("AccountGroup with number $(a.number) already exists.")
#         chartofaccounts[a.number] = a
#         return a
# end

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

Base.show(io::IO, id::Identifier) = print(io, id.value)

Base.show(io::IO, number::AccountNumber) = print(io, number.value)

Base.show(io::IO, acc::LedgerAccount) = print(io, "$(string(id(acc))): $(balance(acc))")

Base.show(io::IO, acc::AccountGroup) = print_tree(io, acc)

Base.show(io::IO, entry::Entry) = print_tree(io, entry)

Base.show(io::IO, ledger::Ledger) = print_tree(io,ledger)

Base.show(io::IO, a::Vector{<:AccountType}) = print_tree(io,a)

AbstractTrees.children(acc::Ledger) = Vector(acc.accounts)

AbstractTrees.printnode(io::IO, acc::Ledger{P}) where {P<:Position} =
    print(io, "$(symbol(P)) Ledger: [$(acc.id)]")

AbstractTrees.children(acc::AccountGroup) = vcat(Vector(acc.subgroups), Vector(acc.accounts))

function AbstractTrees.printnode(io::IO, acc::AccountGroup)
    print(io,
        isempty(acc.number.value) ? "" : "[$(acc.number)] ",
        "$(acc.name): $(acc.isdebit ? balance(acc) : -balance(acc))"
    )
end

AbstractTrees.printnode(io::IO, b::Vector{<:AccountType}) =
    isempty(b) ? print(io, "Accounts: None") : print(io, "Accounts:")

AbstractTrees.children(b::Vector{<:AccountType}) = b

AbstractTrees.children(entry::Entry) = [entry.debit, entry.credit]

AbstractTrees.printnode(io::IO, ::Entry) = print(io, "Entry:")

end # module Ledgers
