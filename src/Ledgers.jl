module Ledgers

using DelimitedFiles, UUIDs, StructArrays
using AbstractTrees; import AbstractTrees: children, printnode
using Instruments; import Instruments: instrument, symbol, amount
using Assets; using Assets: USD

export Credit, Debit, Account, Ledger, Entry
export balance, credit!, debit!, post!
    instrument, symbol, amount

struct AccountId{Id}
    value::Id
end
Base.show(io::IO, id::Id) where {Id <: AccountId} = print(io, id.value)

mutable struct Account{B <: Position,Id <: AccountId}
    id::Id
    balance::B
end
Account(balance::B) where {B <: Position} = Account(AccountId(uuid4()), balance)

id(account::Account) = account.id
balance(account::Account) = account.balance

instrument(::Account{B}) where {B <: Position} = instrument(B)
symbol(::Account{Position{Instrument{S}}}) where {S} = S

debit!(account::Account,amount::Position) = account.balance += amount
credit!(account::Account,amount::Position) = account.balance -= amount

Base.show(io::IO, account::Account) = print(io, "$(string(id(account))): $(balance(account)).")

struct Entry{D,C}
    debit::D
    credit::C
end

Base.show(io::IO,e::Entry{D,C}) where {D <: Account,C <: Account} = print(io, "Entry:\n", "  Debit: $(e.debit)\n", "  Credit: $(e.credit)")
Base.show(io::IO,::MIME"text/plain",e::Entry{D,C}) where {D <: Account,C <: Account} = print(io, "Entry:\n", "  Debit: $(e.debit)\n", "  Credit: $(e.credit)")

function post!(entry::Entry{D,C}, amount::Position) where {D<:Account,C<:Account}
    debit!(entry.debit, amount)
    credit!(entry.credit, amount)
    entry
end

struct Ledger{B <: Position,Id <: AccountId}
    indexes::Dict{Id,Int}
    accounts::StructArray{Account{B,Id}}
end
function Ledger(accounts::Vector{Account{B,Id}}) where {B <: Position,Id <: AccountId}
    indexes = Dict{Id,Int}()
    for (index, account) in enumerate(accounts)
        indexes[id(account)] = index
    end
    Ledger{B,Id}(
        indexes,
        StructArray(accounts)
    )
end

Base.getindex(ledger::Ledger, ix) = ledger.accounts[ix]

Base.getindex(ledger::Ledger, id::Id) where {Id <: AccountId} = ledger.accounts[ledger.indexes[id]]
Base.getindex(ledger::Ledger, array::AbstractArray{Id,1}) where {Id <: AccountId} = ledger.accounts[broadcast(id->ledger.indexes[id], array)]

function add_account!(ledger::Ledger, account::Account)
    push!(ledger.accounts, account)
    ledger.indexes[id(account)] = length(ledger.accounts)
end

abstract type AccountType end
struct Credit <: AccountType end
struct Debit <: AccountType end
Base.show(io::IO, ::Type{Debit}) = print(io, "Debit")
Base.show(io::IO, ::Type{Credit}) = print(io, "Credit")

struct AccountInfo{AT <: AccountType}
    account::Account
    name::String
    parent::Union{Nothing,AccountInfo}
    subaccounts::Vector{AccountInfo}

    function AccountInfo(::Type{AT}, account, name, parent=nothing) where {AT <: AccountType}
        ag = new{AT}(account, name, parent, Vector{AccountInfo}())
        isnothing(parent) || push!(parent.subaccounts, ag)
        return ag
    end
end

account(info::AccountInfo) = info.account
name(info::AccountInfo) = info.name
parent(info::AccountInfo) = info.parent
subaccounts(info::AccountInfo) = info.subaccounts

id(info::AccountInfo) = id(account(info))
balance(info::AccountInfo{Debit}) = 
    isempty(subaccounts(info)) ? balance(account(info)) : 
    balance(account(info)) + sum(map(info->balance(account(info)), subaccounts(info)))
balance(info::AccountInfo{Credit}) = 
    isempty(subaccounts(info)) ? -balance(account(info)) :
    -balance(account(info)) - sum(map(info->balance(account(info)), subaccounts(info)))

function post!(entry::Entry{D,C}, amount::Position) where {D<:AccountInfo,C<:AccountInfo}
    debit!(entry.debit.account, amount)
    credit!(entry.credit.account, amount)
    entry
end

children(info::AccountInfo) = isempty(subaccounts(info)) ? Vector{AccountInfo}() : subaccounts(info)
printnode(io::IO,info::AccountInfo{AT}) where {AT <: AccountType} = print(io, "$(name(info)) ($(id(info))): $(balance(info))")
Base.show(io::IO,info::AccountInfo) = isempty(subaccounts(info)) ? printnode(io, info) : print_tree(io, info)
Base.show(io::IO,::MIME"text/plain",info::AccountInfo) = isempty(subaccounts(info)) ? printnode(io, info) : print_tree(io, info)

Base.show(io::IO,e::Entry{D,C}) where {D <: AccountInfo,C <: AccountInfo} = print(io,
    "Entry:\n",
    "  Debit: $(name(e.debit)) ($(id(e.debit))): $(balance(e.debit))\n",
    "  Credit: $(name(e.credit)) ($(id(e.credit))): $(balance(e.credit))\n")
Base.show(io::IO,::MIME"text/plain",e::Entry{D,C}) where {D <: AccountInfo,C <: AccountInfo} = print(io,
    "Entry:\n",
    "  Debit: $(name(e.debit)) ($(id(e.debit))): $(balance(e.debit))\n",
    "  Credit: $(name(e.credit)) ($(id(e.credit))): $(balance(e.credit))\n")

function example()
    group = AccountInfo(Credit, Account(AccountId("0000000"), USD(0)), "Account Group")
    assets = AccountInfo(Debit, Account(AccountId("1000000"), USD(0)), "Assets", group)
    liabilities = AccountInfo(Credit, Account(AccountId("2000000"), USD(0)), "Liabilities", group)
    cash = AccountInfo(Debit, Account(AccountId("1010000"), USD(0)), "Cash", assets)
    payable = AccountInfo(Credit, Account(AccountId("2010000"), USD(0)), "Accounts Payable", liabilities)

    entry = Entry(cash, payable)
    return group, assets, liabilities, cash, payable, entry
end


# function account_type(account::Account)

# end

# Base.show(io::IO, account::AccountInfo) = print(io, balance(account))
# Base.show(io::IO, account::Account, ::IsCredit) = print(io, -balance(account))



# struct AccountGroupId{S}
#     id::S
# end
# Base.show(io::IO, id::Id) where {Id<:AccountGroupId} = print(io, id.id)

# struct AccountGroup{AT<:AccountType,GroupId<:AccountGroupId}
#     id::GroupId
#     name::String
#     parent::Union{Nothing,AccountGroup}
#     subaccounts::Vector{Union{AccountGroup,Account}}

#     function AccountGroup(::Type{AT},id::S,name,parent=nothing) where {AT<:AccountType,S}
#         ag = new{AT,AccountGroupId{S}}(AccountGroupId{S}(id),name,parent,Vector{AccountGroup}())
#         isnothing(parent) || push!(parent.subaccounts,ag)
#         return ag
#     end
# end

# function example()
#     group = AccountGroup(Credit,"0000000","Account Group")
#     assets = AccountGroup(Debit,"1000000","Assets",group)
#     liabilities = AccountGroup(Credit,"2000000","Liabilities",group)
#     cash = AccountGroup(Debit,"1010000","Cash",assets)
#     payable = AccountGroup(Credit,"2010000","Accounts Payable",liabilities)

#     # entry = Entry(cash,payable)
#     return group, assets, liabilities, cash, payable#, entry
# end

# AccountGroup(subaccounts) = AccountGroup(AccountGroupId(uuid4()),nothing,subaccounts)

# balance(a::AccountGroup{AT}) where {AT<:AccountType}= sum(balance.(a.subaccounts, AT))



# struct BalanceSheet{P<:Position}
#     asset::Ledger{Debit,P}
#     liability::Ledger{Credit,P}
#     revenue::Ledger{Credit,P}
#     expense::Ledger{Debit,P}
#     equity::Ledger{Credit,P}
# end

# mutable struct AccountGroup{C<:Cash,I<:Instrument,B<:Real}
#     parent::AccountGroup{C,<:Instrument}
#     name::String
#     code::String
#     isdebit::Bool
#     balance::Position{I,B}
#     subaccounts::Vector{AccountGroup{C,<:Instrument}}

#     function AccountGroup{C,I,A}(parent::AccountGroup{C,<:Instrument},name,code,isdebit,balance::Position{I,A}=Position(USD,0.)) where {C,I,A}
#         a = new(parent,name,code,isdebit,balance,Vector{AccountGroup{C,<:Instrument}}())
#         push!(parent.subaccounts,a)
#         return a
#     end

#     function AccountGroup{I,I,A}(name::String,code,balance::Position{I,A}=Position(USD,0.)) where {I,A}
#         a = new()
#         a.parent = a
#         a.name = name
#         a.code = code
#         a.isdebit = true
#         a.balance = balance
#         a.subaccounts = Vector{AccountGroup{I,<:Instrument}}()
#         return a
#     end
# end
# AccountGroup(parent::AccountGroup{C},name,code,isdebit,balance::Position{I,A}=Position(USD,0.)) where {C,I,A} = AccountGroup{C,I,A}(parent,name,code,isdebit,balance)
# AccountGroup(name::String,code,balance::Position{I,A}=Position(USD,0.)) where {I,A} = AccountGroup{I,I,A}(name,code,balance)
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

# parent(a::AccountGroup) = a.parent
# name(a::AccountGroup) = a.name
# isdebit(a::AccountGroup) = a.isdebit
# function balance(a::AccountGroup{C,I,A}) where {C,I,A}
#     isempty(a.subaccounts) && return FX.convert(Position{C,A},a.balance)
#     b = zero(Position{C,A})
#     for account in a.subaccounts
#         if isequal(a.isdebit,account.isdebit)
#             b += balance(account)
#         else
#             b -= balance(account)
#         end
#     end
#     return b::Position{C,A}
# end
# subaccounts(a::AccountGroup) = a.subaccounts

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

# const AT = AbstractTrees
# AT.children(a::AccountGroup) = isempty(a.subaccounts) ? Vector{AccountGroup}() : a.subaccounts
# AT.printnode(io::IO,a::AccountGroup) = print(io,"$(a.name) ($(a.id))")
# Base.show(io::IO,a::AccountGroup) = isempty(a.subaccounts) ? AT.printnode(io,a) : print_tree(io,a)
# Base.show(io::IO,::MIME"text/plain",a::AccountGroup) = isempty(a.subaccounts) ? AT.printnode(io,a) : print_tree(io,a)

# AT.children(c::Dict{String,AccountGroup}) = [p for p in c]
# # AT.printnode(io::IO,c::Dict{String,AccountGroup}) = print(io,"Chart of Accounts:")
# Base.show(io::IO,c::Dict{String,AccountGroup}) = print_tree(io,c)
# Base.show(io::IO,::MIME"text/plain",c::Dict{String,AccountGroup}) = print_tree(io,c)

# AT.children(p::Pair{String,AccountGroup}) = Vector{AccountGroup}()
# AT.printnode(io::IO,p::Pair{String,AccountGroup}) = print(io,"$(p[1]): $(p[2].name)")
# Base.show(io::IO,p::Pair{String,AccountGroup}) = print(io,"$(p[1]): $(p[2].name)")
# Base.show(io::IO,::MIME"text/plain",p::Pair{String,AccountGroup}) = print(io,"$(p[1]): $(p[2].name)")

# AT.children(e::Entry) = [e.debit,e.credit]
# AT.printnode(io::IO,c::Entry) = print(io,"Entry:")
# Base.show(io::IO,e::Entry) = print_tree(io,e)
# Base.show(io::IO,::MIME"text/plain",e::Entry) = print_tree(io,e)

# AT.children(t::Dict{String,Entry}) = [p for p in t]
# AT.printnode(io::IO,t::Dict{String,Entry}) = print(io,"Transaction:")
# Base.show(io::IO,t::Dict{String,Entry}) = print_tree(io,t)
# Base.show(io::IO,::MIME"text/plain",t::Dict{String,Entry}) = print_tree(io,t)

# AT.children(p::Pair{String,Entry}) = [p[2].debit,p[2].credit]
# AT.printnode(io::IO,p::Pair{String,Entry}) = print(io,"Entry:")
# Base.show(io::IO,p::Pair{String,Entry}) = print(io,p[2])
# Base.show(io::IO,::MIME"text/plain",p::Pair{String,Entry}) = print(io,p[2])

# AT.children(t::Transaction) = AT.children(t.entries)
# AT.printnode(t::Transaction) = AT.printnode(t.entries)
# Base.show(io::IO,t::Transaction) = print_tree(io,t.entries)
# Base.show(io::IO,::MIME"text/plain",t::Transaction) = print_tree(io,t.entries)

# AT.printnode(io::IO,c::Position{Cash{C},A})  where C where A = print(io,c.amount," ",C())

end