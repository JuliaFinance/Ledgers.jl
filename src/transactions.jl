struct Transaction
    _entries::Dict{String,Entry}
    _module::Function
end
# Transaction(e::Dict{String,Entry{C,A}},m::Function) where C where A = Transaction{C,A}(e,m)
# const transactions = Dict{String,Transaction}()

function post!(t::Transaction,a::Position)
    t._module(t._entries,a)
end