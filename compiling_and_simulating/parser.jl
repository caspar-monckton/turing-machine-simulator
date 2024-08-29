abstract type ASTNode end

abstract type UnaryNode{T <: Union{Token, ASTNode, Vector{Token}, Vector{ASTNode}}} <: ASTNode end
abstract type BinaryNode{T, S <: Union{Token, ASTNode, Vector{Token}, Vector{ASTNode}}} <: ASTNode end

struct MachineRef{T} <: UnaryNode{T}
    name::Identifier
end

struct Goto{T} <: UnaryNode
    value::Union{MachineRef, Identifier}
end

struct Transition <: ASTNode
    input::Identifier
    output1::Goto
    output2::Identifier
    output3::Literal
end

struct Declaration <: BinaryNode
    name::Identifier
    list::Vector{Transition}
end

struct Accepter <: UnaryNode
    items::Vector{Goto}
end

struct Recogniser <: UnaryNode
    items::Vector{Identifier}
end

struct Starter <: UnaryNode
    item::Goto
end

struct MachineDef <: ASTNode
    name::Identifier
    accept::Accepter
    start::Starter
    recognise::Recogniser
    content::Vector{Declaration}
end

struct MachineCall <: BinaryNode
    name::Identifier
    arguments::Vector{Identifier}
end

struct Program <: BinaryNode
    machines::Vector{MachineDef}
    main::MachineCall
end

function prindentln(element::Any, indent_level::Integer = 1)
    indent = "\t"^indent_level
    println("$indent$element")
end

function prindentln(node::ASTNode, indent_level::Integer = 1)
    fields = fieldnames(typeof(node))
    for field in fields
        if getfield(node, field) isa Vector
            prindentln(field, indent_level + 1)
            for element in getfield(node, field)
                prindentln(element, indent_level + 2)
            end
        else
            prindentln(field, indent_level + 1)
            prindentln((getfield(node, field)), indent_level + 2)
        end
    end
end

# Parser
function parse!(tokens::TokenStream, ::Type{T} where T <: MachineRef)
    name = nothing
    current = peek!(tokens)
    if current isa Punctuator && current.value == "@"
        consume!(tokens)
        current = peek!(tokens)
    else
        throw(error("Parser error: Expected '@' at the beginning of machine reference."))
    end
    if current isa Identifier
        name = consume!(tokens)
    else
        throw(error("Parser error: Expected identifier as a machine name instead of '$(typeof(current))'."))
    end
    return MachineRef(name)
end

function parse!(tokens::TokenStream, ::Type{T} where T <: Goto)
    value = nothing
    current = peek!(tokens)
    if current isa Punctuator && current.value == "@"
        value = parse!(tokens, MachineRef)
        current = peek!(tokens)
    elseif current isa Identifier
        value = consume!(tokens)
    else 
        throw(error("Parser error: Goto must either be an Identifier or a MachineRef, not '$(typeof(current))'"))
    end
    return Goto(value)
end

function parse!(tokens::TokenStream, ::Type{T} where T <: Transition)
    input = nothing
    output1 = nothing
    output2 = nothing
    output3 = nothing
     
    current = peek!(tokens)
    if current isa Identifier
        input = consume!(tokens)
        current = peek!(tokens)
    else
        throw(error("Parser error: 'Transition' must start with an 'Identifier', not '$(typeof(current))'."))
    end
    
    if current isa Punctuator && current.value == "->"
        consume!(tokens)
        current = peek!(tokens)
    else
        throw(error("Parser error: Expected '->' after input value, not '$(typeof(current))'."))
    end

    if current isa Identifier || (current isa Punctuator && current.value == "@")
        output1 = parse!(tokens, Goto)
        current = peek!(tokens)
    else
        throw(error("Parser error: Expected 'Identifier' after '->', not '$(typeof(current))'."))
    end

    if current isa Punctuator && current.value == ","
        consume!(tokens)
        current = peek!(tokens)
    else
        throw(error("Parser error: Expected ',' not '$(typeof(current))'."))
    end

    if current isa Identifier
        output2 = consume!(tokens)
        current = peek!(tokens)
    else
        throw(error("Parser error: Expected 'Identifier', not '$(typeof(current))'."))
    end

    if current isa Punctuator && current.value == ","
        consume!(tokens)
        current = peek!(tokens)
    else
        throw(error("Parser error: Expected ',' not '$(typeof(current))'."))
    end

    if current isa Literal
        output3 = consume!(tokens)
        current = peek!(tokens)
    else
        throw(error("Parser error: Expected 'Direction', not '$(typeof(current))'."))
    end
    
    if current isa EOL
        consume!(tokens)
        current = peek!(tokens)
    else
        throw(error("Parser error: 'Transition' must end with a newline character, not '$(typeof(current))'."))
    end

    return Transition(input, output1, output2, output3)
end

function parse!(tokens::TokenStream, ::Type{T} where T <: Declaration)
    name = nothing
    list = Vector{Transition}()

    current = peek!(tokens)

    if current isa Keyword && current.value == "state"
        consume!(tokens)
        current = peek!(tokens)
    else
        throw(error("Parser error: Expected 'state' keyword, not '$(typeof(current))'."))
    end

    if current isa Identifier
        name = consume!(tokens)
        current = peek!(tokens)
    else
        throw(error("Parser error: state name must be 'Identifier', not '$(typeof(current))'."))
    end

    if current isa Punctuator && current.value == ":"
        consume!(tokens)
        current = peek!(tokens)
    else
        throw(error("Parser error: Expected ':', not '$(typeof(current))'."))
    end

    if current isa EOL
        consume!(tokens)
        current = peek!(tokens)
    else
        throw(error("Parser error: Expected newline after ':', not '$(typeof(current))'."))
    end

    if current isa Identifier || (current isa Punctuator && current.value == "@")
        while current isa Identifier || (current isa Punctuator && current.value == "@")
            push!(list, parse!(tokens, Transition))
            current = peek!(tokens)
        end
        current = peek!(tokens)
    else
        throw(error("Parser error: Expected declaration, not'$(typeof(current))'."))
    end

    if current isa Punctuator && current.value == "end"
        consume!(tokens)
        current = peek!(tokens)
    else
        throw(error("Parser error: Expected Terminator: 'end', not '$(typeof(current))'."))
    end

    if current isa EOL
        consume!(tokens)
        current = peek!(tokens)
    end

    return Declaration(name, list)
end

function parse!(tokens::TokenStream, ::Type{T} where T <: Accepter)
    title = nothing
    items = Vector{Goto}()

    current = peek!(tokens)

    if current isa Keyword && current.value == "accept"
        title = consume!(tokens)
        current = peek!(tokens)
    else
        throw(error("Parser error: 'Accepter' should start with 'accept' keyword, not '$(typeof(current))'."))
    end

    if current isa Punctuator && current.value == ":"
        consume!(tokens)
        current = peek!(tokens)
    else
        throw(error("Parser error: ':' should follow 'accept' keyword, not '$(typeof(current))'."))
    end

    if (current isa Identifier || (current isa Punctuator && current.value == "@"))
        while (current isa Identifier || (current isa Punctuator && current.value == "@"))
            current = peek!(tokens)
            push!(items, parse!(tokens, Goto))
            current = peek!(tokens)
            if current isa Punctuator && current.value == ","
                consume!(tokens)
                current = peek!(tokens)
            elseif current isa EOL
               break
            else
                throw(error("Parser error: Expected 'Comma' between arguments."))
            end
        end
    else
        throw(error("Parser error: Expected 'Goto', not '$(typeof(current))'."))
    end

    current = peek!(tokens)
    if current isa EOL
        consume!(tokens)
        current = peek!(tokens)
    else
        throw(error("Parser error: Expected newline after end of statement, not '$(typeof(current))'."))
    end
    return Accepter(items)
end

function parse!(tokens::TokenStream, ::Type{T} where T <: Recogniser)
    title = nothing
    items = Vector{Identifier}()

    current = peek!(tokens)

    if current isa Keyword && current.value == "recognise"
        title = consume!(tokens)
        current = peek!(tokens)
    else
        throw(error("Parser error: 'Recogniser' should start with 'recognise' keyword, not '$(typeof(current))'."))
    end

    if current isa Punctuator && current.value == ":"
        consume!(tokens)
        current = peek!(tokens)
    else
        throw(error("Parser error: ':' should follow 'recognise' keyword, not '$(typeof(current))'."))
    end

    if current isa Identifier
        while current isa Identifier
            current = peek!(tokens)
            push!(items, consume!(tokens))
            current = peek!(tokens)
            if current isa Punctuator && current.value == ","
                consume!(tokens)
                current = peek!(tokens)
            elseif current isa EOL
               break
            else
                throw(error("Parser error: Expected 'Comma' between arguments."))
            end
        end
    else
        throw(error("Parser error: Expected 'State', not '$(typeof(current))'."))
    end

    if current isa EOL
        consume!(tokens)
        current = peek!(tokens)
    else
        throw(error("Parser error: Expected newline after end of statement, not '$(typeof(current))'."))
    end
    return Recogniser(items)
end

function parse!(tokens::TokenStream, ::Type{T} where T <: Starter)
    title = nothing
    item = nothing

    current = peek!(tokens)

    if current isa Keyword && current.value == "start"
        title = consume!(tokens)
        current = peek!(tokens)
    else
        throw(error("Parser error: 'Starter' should start with 'start' keyword, not '$(typeof(current))'."))
    end

    if current isa Punctuator && current.value == ":"
        end_name = consume!(tokens)
        current = peek!(tokens)
    else
        throw(error("Parser error: ':' should follow 'start' keyword, not '$(typeof(current))'."))
    end

    if (current isa Identifier || (current isa Punctuator && current.value == "@"))
        item = parse!(tokens, Goto)
        current = peek!(tokens)
    else
        throw(error("Parser error: Expected 'State', not '$(typeof(current))'."))
    end

    if current isa EOL
        final = consume!(tokens)
        current = peek!(tokens)
    else
        throw(error("Parser error: Expected newline after end of statement, not '$(typeof(current))'."))
    end
    return Starter(item)
end

function parse!(tokens::TokenStream, ::Type{T} where T <: MachineCall)
    name = nothing
    arguments = Vector{Identifier}()

    current = peek!(tokens)

    if current isa Identifier
        name = consume!(tokens)
        current = peek!(tokens)
    else
        throw(error("Parser error: machine call should be an 'Identifier', not '$(typeof(current))'."))
    end

    if current isa Punctuator && current.value == "("
        consume!(tokens)
        current = peek!(tokens)
    else
        throw(error("Parser error: '(' should follow machine name, not '$(typeof(current))'."))
    end

    if current isa Identifier
        while current isa Identifier
            push!(arguments, consume!(tokens))
            current = peek!(tokens)
            if current isa Punctuator && current.value == ","
                consume!(tokens)
                current = peek!(tokens)
            else
                break
            end
        end
    elseif !(current isa Punctuator && current.value == ")")
        throw(error("Parser error: Expected 'Identifier' as argument, not '$(typeof(current))'."))
    end

    if current isa Punctuator && current.value == ")"
        consume!(tokens)
    else
        throw(error("Parser error: ')' should follow machine name, not '$(typeof(current))'."))
    end

    return MachineCall(name, arguments)    
end

function parse!(tokens::TokenStream, ::Type{T} where T <: MachineDef)
    name = nothing
    accept = nothing
    recognise = nothing
    start = nothing
    content = Vector{Declaration}()

    current = peek!(tokens)
    if current isa Keyword && current.value == "machine"
        consume!(tokens)
        current = peek!(tokens)
    else
        throw(error("Parser error: 'MachineDef' should start with 'machine' keyword, not '$(typeof(current))'."))
    end

    if current isa Identifier
        name = consume!(tokens)
        current = peek!(tokens)
    else
        throw(error("Parser error: machine name should be an 'Identifier', not '$(typeof(current))'."))
    end

    if current isa Punctuator && current.value == ":"
        consume!(tokens)
        current = peek!(tokens)
    else
        throw(error("Parser error: ':' should follow machine name, not '$(typeof(current))'."))
    end

    if current isa EOL
        consume!(tokens)
        current = peek!(tokens)
    end

    if (current isa Keyword && current.value == "accept")
        accept = parse!(tokens, Accepter)
        current = peek!(tokens)
    else
        throw(error("Parser error: Expected 'accept' keyword, not '$(typeof(current))'."))
    end

    if (current isa Keyword && current.value == "start")
        start = parse!(tokens, Starter)
        current = peek!(tokens)
    else
        throw(error("Parser error: Expected 'start' keyword, not '$(typeof(current))'."))
    end

    if (current isa Keyword && current.value == "recognise")
        recognise = parse!(tokens, Recogniser)
        current = peek!(tokens)
    else
        throw(error("Parser error: Expected 'recognise' keyword, not '$(typeof(current))'."))
    end

    if current isa EOL
        consume!(tokens)
        current = peek!(tokens)
    end

    if (current isa Keyword && current.value == "state")
        while (current isa Keyword && current.value == "state")
            push!(content, parse!(tokens, Declaration))
            current = peek!(tokens)
            if current isa EOL
                consume!(tokens)
                current = peek!(tokens)
            end
        end
    else
        throw(error("Parser error: Expected 'Identifier' or '@ Identifier', not '$(typeof(current))'."))
    end

    if current isa Punctuator && current.value == "end"
        consume!(tokens)
        current = peek!(tokens)
    else
        throw(error("Parser error: Expected 'end' keyword to finish machine scope, not '$(typeof(current))'."))
    end
    if current isa EOL
        consume!(tokens)
        current = peek!(tokens)
    end
    return MachineDef(name, accept, start, recognise, content)    
end

function parse!(tokens::TokenStream, ::Type{T} where T <: Program)
    machines = Vector{MachineDef}()
    main = nothing

    current = peek!(tokens)
    if current isa Keyword && current.value == "machine"
        while (current isa Keyword && current.value == "machine")
            push!(machines, parse!(tokens, MachineDef))
            current = peek!(tokens)
        end
    else
        throw(error("Parser error: Expected 'machine' keyword to start machine scope, not '$(typeof(current))'."))
    end

    if current isa Identifier
        main = parse!(tokens, MachineCall)
    else
        throw(error("Parser error: Expected 'Identifier' for main call, not '$(typeof(current))'."))
    end
    return Program(machines, main)
end