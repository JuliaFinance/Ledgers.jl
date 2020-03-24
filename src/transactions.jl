struct Transaction{M}
    _entries::Dict{String,Entry}
end
Transaction(m,e) = Transaction{m}(e)

function post!(t::Transaction{M},a::Position) where M
    M(t._entries,a)
end