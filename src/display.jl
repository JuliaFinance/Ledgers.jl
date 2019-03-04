AT.printnode(x) = AT.printnode(stdout,x)

AT.children(a::Account) = isempty(a._subaccounts) ? Vector{Account}() : a._subaccounts
function AT.printnode(io::IO,a::Account)
    isequal(a,a._parent) ? 
    print(io,a._name) : isempty(a._subaccounts) ? 
    print(io,"$(a._code) $(a._name): ",a._balance) : print(io,"$(a._code) $(a._name)")
end
Base.show(io::IO,a::Account) = isempty(a._subaccounts) ? AT.printnode(io,a) : print_tree(io,a)
Base.show(io::IO,::MIME"text/plain",a::Account) = isempty(a._subaccounts) ? AT.printnode(io,a) : print_tree(io,a)

AT.children(c::Dict{String,Account}) = [p for p in c]
AT.printnode(io::IO,c::Dict{String,Account}) = print(io,"Chart of Accounts:")
Base.show(io::IO,c::Dict{String,Account}) = print_tree(io,c)
Base.show(io::IO,::MIME"text/plain",c::Dict{String,Account}) = print_tree(io,c)

AT.children(p::Pair{String,Account}) = Vector{Account}()
AT.printnode(io::IO,p::Pair{String,Account}) = print(io,"$(p[1]): $(p[2]._name)")
Base.show(io::IO,p::Pair{String,Account}) = print(io,"$(p[1]): $(p[2]._name)")
Base.show(io::IO,::MIME"text/plain",p::Pair{String,Account}) = print(io,"$(p[1]): $(p[2]._name)")

AT.children(e::Entry) = [e._debit,e._credit]
AT.printnode(io::IO,c::Entry) = print(io,"Entry:")
Base.show(io::IO,e::Entry) = print_tree(io,e)
Base.show(io::IO,::MIME"text/plain",e::Entry) = print_tree(io,e)

AT.children(t::Dict{String,Entry}) = [p for p in t]
AT.printnode(io::IO,t::Dict{String,Entry}) = print(io,"Transaction:")
Base.show(io::IO,t::Dict{String,Entry}) = print_tree(io,t)
Base.show(io::IO,::MIME"text/plain",t::Dict{String,Entry}) = print_tree(io,t)

AT.children(p::Pair{String,Entry}) = [p[2]._debit,p[2]._credit]
AT.printnode(io::IO,p::Pair{String,Entry}) = print(io,"Entry:")
Base.show(io::IO,p::Pair{String,Entry}) = print(io,p[2])
Base.show(io::IO,::MIME"text/plain",p::Pair{String,Entry}) = print(io,p[2])

AT.children(t::Transaction) = AT.children(t._entries)
AT.printnode(t::Transaction) = AT.printnode(t._entries)
Base.show(io::IO,t::Transaction) = print_tree(io,t._entries)
Base.show(io::IO,::MIME"text/plain",t::Transaction) = print_tree(io,t._entries)

AT.printnode(io::IO,c::Position{Cash{C},A})  where C where A = print(io,c.amount," ",C())
