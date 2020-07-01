using Ledgers, Test, Assets
@cash USD

group, assets, liabilities, mycash, payable, entry = Ledgers.example()

@testset "Account creation" begin
    @test id(group) isa AccountId
    @test id(assets) isa AccountId
    @test code(mycash).value === "1010000"
    @test name(payable) === "Accounts Payable"
    @test balance(group) === 0usd
    @test balance(assets) === 0usd
    @test balance(liabilities) === 0usd
end

@testset "Post entry" begin
    amt = 10usd
    post!(entry, amt)
    @test balance(group) === 0usd
    @test balance(assets) === amt
    @test balance(liabilities) === -amt
    @test balance(mycash) === amt
    @test balance(payable) === -amt
end
