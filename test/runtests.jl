using Ledgers
import Test; using Test: @testset, @test
using Assets: USD

function example(withnumbers=true)
    if withnumbers
        group = AccountGroup(Account{USD}, name="Account Group", number="0000000")
        assets = AccountGroup(Account{USD}, name="Assets", number="1000000", parent=group)
        liabilities = AccountGroup(Account{USD}, name="Liabilities", number="2000000", parent=group, isdebit=false)
        cash = Account(USD, name="Cash", number="1010000", parent=assets)
        payable = Account(USD, name="Accounts Payable", number="2010000", parent=liabilities, isdebit=false)
    else
        group = AccountGroup(Account{USD}, name="Account Group")
        assets = AccountGroup(Account{USD}, name="Assets", parent=group)
        liabilities = AccountGroup(Account{USD}, name="Liabilities", parent=group, isdebit=false)
        cash = Account(USD, name="Cash", parent=assets)
        payable = Account(USD, name="Accounts Payable", parent=liabilities, isdebit=false)
    end    
    entry = Entry(cash, payable)
    group, assets, liabilities, cash, payable, entry
end

group, assets, liabilities, cash, payable, entry = example()

@testset "Account creation" begin
    @test id(group) isa AccountId
    @test id(assets) isa AccountId
    @test cash.number.value === "1010000"
    @test payable.name === "Accounts Payable"
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