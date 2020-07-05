using Ledgers, Test
using Assets: USD

function example()
    group = AccountGroup(USD, AccountCode("0000000"), "Account Group", true)
    assets = AccountGroup(USD, AccountCode("1000000"), "Assets", true, parent=group)
    liabilities = AccountGroup(USD, AccountCode("2000000"), "Liabilities", false, parent=group)
    cash = AccountInfo(Account(0USD), AccountCode("1010000"), "Cash", true, parent=assets)
    payable = AccountInfo(Account(0USD), AccountCode("2010000"), "Accounts Payable", false, parent=liabilities)

    entry = Entry(cash, payable)
    group, assets, liabilities, cash, payable, entry
end

group, assets, liabilities, cash, payable, entry = example()

@testset "Account creation" begin
    @test id(group) isa AccountId
    @test id(assets) isa AccountId
    @test code(cash).value === "1010000"
    @test name(payable) === "Accounts Payable"
    @test iscontra(assets) === false
    @test iscontra(liabilities) === true
    @test balance(group) === 0USD
    @test balance(assets) === 0USD
    @test balance(liabilities) === 0USD
end

@testset "Post entry" begin
    amt = 10USD
    post!(entry, amt)
    @test balance(group) === 0USD
    @test balance(assets) === amt
    @test balance(liabilities) === -amt
    @test balance(cash) === amt
    @test balance(payable) === -amt
end