function example()
    ledger = Account("NewCo","0000000")
    assets = Account(ledger,"Assets","1000000",true)
    liabilities = Account(ledger,"Liabilities","2000000",false)
    cash = Account(assets,"Cash","1010000",true)
    payable = Account(liabilities,"Accounts Payable","2010000",false)

    entry = Entry(cash,payable)
    return ledger, assets, liabilities, cash, payable, entry
end