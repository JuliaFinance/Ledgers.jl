module GeneralLedgers

import ISOCurrencies.Currencies: Currency, USD

# There should be three types of accounts:
# 1. GeneralLedger - Has no parent. Has children. Cannot post journal entries directly.
# 2. AccountGroup - Has a parent. Has children. Cannot post journal entries directly.
# 3. LedgerAccount - Has a parent. Has no children. Can post journal entries directly.

# What about "Modules"?

# - Financial Reports
# - Audit Controls
# - Inventory Management
# - Invoice / Customer / Purchase Order / Vendor / Receipts Management

# Account types
# - Balance Sheet
# - Income Statement
# - Retained Earnings

abstract type Ledger end 
abstract type Account end

struct GeneralLedger <: Ledger
    name::String
    currency::Currency
    children::Dict{String,Union{Ledger,Account}}

    GeneralLedger(name::String,currency::Currency,children=Dict{String,Union{Ledger,Account}}()) = new(name,currency,children)
end

struct AccountGroup <: Ledger
    parent::Ledger
    name::String
    code::String
    children::Dict{String,Union{Ledger,Account}}

    function AccountGroup(parent,name,code)
        haskey(parent.children,code) && error("Account code $(code) already exists.")
        account = new(parent,name,code,Dict{String,Union{Ledger,Account}}())
        parent.children[code] = account
        return account
    end
end

struct DebitAccount <: Account
    parent::Ledger
    name::String
    code::String

    function DebitAccount(parent,name,code)
        haskey(parent.children,code) && error("Account code $(code) already exists.")
        account = new(parent,name,code)
        parent.children[code] = account
        return account
    end
end

struct CreditAccount <: Account
    parent::Ledger
    name::String
    code::String

    function CreditAccount(parent,name,code)
        haskey(parent.children,code) && error("Account code $(code) already exists.")
        account = new(parent,name,code)
        parent.children[code] = account
        return account
    end
end

include("show.jl")

function example()
    ledger = GeneralLedger("NewCo",USD)
    assets = DebitAccount(ledger,"Assets","1")
    liabilities = CreditAccount(ledger,"Liabilities","2")
    return ledger
end

end # module
