struct Transaction
    _entries::Dict{String,Entry}
    _module::Function
end

function post!(t::Transaction,a::Position)
    t._module(t._entries,a)
end