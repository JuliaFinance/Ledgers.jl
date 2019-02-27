AbstractTrees.printnode(x) = AbstractTrees.printnode(stdout,x)

AbstractTrees.children(a::Account) = isnothing(a.subaccounts) ? Vector{Account}() : a.subaccounts
# AbstractTrees.children(a::Account) = _children(a,accounttype(a))
# _children(a::Account,::GeneralLedger) = isnothing(a.subaccounts) ? Vector{Account}() : [a.subaccounts;[a.chart]]
# _children(a::Account,::Any) = isnothing(a.subaccounts) ? Vector{Account}() : a.subaccounts

AbstractTrees.printnode(io::IO,a::Account) = _printnode(io,a,accounttype(a))
_printnode(io::IO,a::Account,::GeneralLedger{C}) where C = print(io,a.name)
_printnode(io::IO,a::Account,::Union{DebitGroup,CreditGroup}) = print(io,"$(a.code) $(a.name)")
_printnode(io::IO,a::Account,::Union{DebitAccount,CreditAccount}) = print(io,"$(a.code) $(a.name): ",balance(a))

AbstractTrees.printnode(io::IO,c::Dict{String,Account}) = print(io,"Chart of Accounts:")

Base.show(io::IO,a::Account) = _show(io,a,accounttype(a))
_show(io::IO,a::Account,::Union{GeneralLedger,DebitGroup,CreditGroup}) = print_tree(io,a)
_show(io::IO,a::Account,t::Union{DebitAccount,CreditAccount}) = _printnode(io,a,t)

Base.show(io::IO,a::DebitGroup{C}) where C = print(io,"DebitGroup{",C(),"}")
Base.show(io::IO,a::CreditGroup{C}) where C = print(io,"CreditGroup{",C(),"}")
Base.show(io::IO,a::DebitAccount{C}) where C = print(io,"DebitAccount{",C(),"}")
Base.show(io::IO,a::CreditAccount{C}) where C = print(io,"CreditAccount{",C(),"}")

AbstractTrees.children(e::Entry) = [e.debit,e.credit,e.amount]
AbstractTrees.printnode(io::IO,c::Entry) = print(io,"Entry")
AbstractTrees.printnode(io::IO,c::Position{Cash{C}}) where C = print(io,c.amount," ",C())

Base.show(io::IO,c::Position{Cash{C}}) where C = print(io,c.amount," ",C())
Base.show(io::IO,e::Entry) = print_tree(io,e)

