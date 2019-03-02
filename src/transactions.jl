struct Transaction{C<:Cash,A<:Real}
    _entries::Dict{String,Entry{C,A}}
    _module::Function
end
# Transaction(e::Dict{String,Entry{C,A}},m::Function) where C where A = Transaction{C,A}(e,m)
# const transactions = Dict{String,Transaction}()

function post!(t::Transaction{C,A},a::Position{C,A}) where C where A
    t._module(t._entries,a)
end