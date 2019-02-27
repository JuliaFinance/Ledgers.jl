function example()
    ledger = GeneralLedger("NewCo","0000000")
    assets = DebitGroup(ledger,"Assets","1000000")
    liabilities = CreditGroup(ledger,"Liabilities","2000000")
    cash = DebitAccount(assets,"Cash","1010000")
    payable = CreditAccount(liabilities,"Accounts Payable","2010000")

    entry = Entry(cash,payable,Position(FI.USD,10.))
    return ledger, assets, liabilities, cash, payable, entry
end