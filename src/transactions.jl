struct Transaction{C<:Cash}
    _entries::Dict{String,Entry{C}}
    _module::Function
end
# Transaction(e::Dict{String,Entry{C}},m::M) where C where M =Transactions{C,M}(e,m)
# const transactions = Dict{String,Transaction}()

function post!(t::Transaction{C},a::Position{C}) where C
    t._module(t._entries,a)
end