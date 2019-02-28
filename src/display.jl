AT.printnode(x) = AT.printnode(stdout,x)

AT.children(a::Account{C}) where C = isempty(a.subaccounts) ? Vector{Account{C}}() : a.subaccounts

function AT.printnode(io::IO,a::Account{C}) where C
    isequal(a,a.parent) ? 
    print(io,a.name) : isempty(a.subaccounts) ? 
    print(io,"$(a.code) $(a.name): ",balance(a)) : print(io,"$(a.code) $(a.name)")
end

AT.children(c::Dict{String,Account}) = [p for p in c]
AT.printnode(io::IO,c::Dict{String,Account}) = print(io,"Chart of Accounts:")
Base.show(io::IO,::MIME"text/plain",c::Dict{String,Account}) = print_tree(io,c)

AT.children(p::Pair{String,Account}) = Vector{Account}()
AT.printnode(io::IO,p::Pair{String,Account}) = print(io,"$(p[1]): $(p[2].name)")
Base.show(io::IO,::MIME"text/plain",p::Pair{String,Account}) = print(io,"$(p[1]): $(p[2].name)")

Base.show(io::IO,::MIME"text/plain",a::Account{C}) where C = isempty(a.subaccounts) ? AT.printnode(io,a) : print_tree(io,a)

AT.children(e::Entry{C}) where C = [e.debit,e.credit,e.amount]
AT.printnode(io::IO,c::Entry{C}) where C = print(io,"Entry")
Base.show(io::IO,::MIME"text/plain",e::Entry{C}) where C = print_tree(io,e)

AT.printnode(io::IO,c::Position{Cash{C}}) where C = print(io,c.amount," ",C())
Base.show(io::IO,::MIME"text/plain",c::Position{Cash{C}}) where C = print(io,c.amount," ",C())
