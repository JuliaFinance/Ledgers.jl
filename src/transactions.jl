struct Transaction{M}
    entries::Dict{String,Entry}
end
Transaction(m,e) = Transaction{m}(e)

function post!(t::Transaction{M},a::Position) where M
    M(t.entries,a)
end