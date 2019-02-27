AT.printnode(x) = AT.printnode(stdout,x)

AT.children(a::Account{C}) where C = isempty(a.subaccounts) ? Vector{Account{C}}() : a.subaccounts

function AT.printnode(io::IO,a::Account{C}) where C
    isequal(a,a.parent) ? 
    print(io,a.name) : isempty(a.subaccounts) ? 
    print(io,"$(a.code) $(a.name): ",balance(a)) : print(io,"$(a.code) $(a.name)")
end

AT.printnode(io::IO,c::Dict{String,Account{C}}) where C = print(io,"Chart of Accounts:")

Base.show(io::IO,a::Account{C}) where C = isempty(a.subaccounts) ? AT.printnode(io,a) : print_tree(io,a)

AT.children(e::Entry{C}) where C = [e.debit,e.credit,e.amount]
AT.printnode(io::IO,c::Entry{C}) where C = print(io,"Entry")
AT.printnode(io::IO,c::Position{Cash{C}}) where C = print(io,c.amount," ",C())

Base.show(io::IO,c::Position{Cash{C}}) where C = print(io,c.amount," ",C())
Base.show(io::IO,e::Entry{C}) where C = print_tree(io,e)
