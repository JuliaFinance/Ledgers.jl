function Base.show(io::IO,gl::GeneralLedger)
    iobuff = IOBuffer()
    print(iobuff,"GeneralLedger: $(gl.name)\n")
    print(iobuff,"Currency: $(gl.currency)\n")
    print(iobuff,"Accounts:\n")
    for (key,child) in gl.children
        print(iobuff,"  $(child.name) ($(child.code))\n")
    end
    print(io,String(take!(iobuff)))
end

function Base.show(io::IO,acct::AccountGroup)
    iobuff = IOBuffer()
    print(iobuff,"AccountGroup: $(acct.name) ($(acct.code))\n")
    print(iobuff,"SubAccounts:\n")
    for (key,child) in acct.children
        print(iobuff,"  $(child.name) ($(child.code))\n")
    end
    print(io,String(take!(iobuff)))
end

Base.show(io::IO,acct::DebitAccount) = print(io,"DebitAccount: $(acct.name) ($(acct.code))\n")

Base.show(io::IO,acct::CreditAccount) = print(io,"CreditAccount: $(acct.name) ($(acct.code))\n")