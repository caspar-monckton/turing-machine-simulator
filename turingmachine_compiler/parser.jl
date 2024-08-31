abstract type ASTNode end

# Union{Nothing, S} messes with the multiple dispatch. 
# MaybeToken is just a way of forcing the compiler to use the method with Union{Nothing, S} in its 
# signature.
struct MaybeToken{S <: AbstractToken}
    token::Union{Nothing, S}
end

struct NodeList{T <:Union{AbstractToken, ASTNode}, D <: AbstractToken}
    values::Vector{T}
end

# Technically these are parser tree nodes because they still contain all the syntactical information.
struct Goto <: ASTNode
    prefix::MaybeToken{Punctuator{:referenceindicator}}
    value::Identifier
end

struct Transition <: ASTNode
    input::Identifier
    map::Punctuator{:map}
    output1::Goto
    comma1::Punctuator{:comma}
    output2::Identifier
    comma2::Punctuator{:comma}
    output3::Literal
end

struct Declaration <: ASTNode
    keyword::Keyword{:state}
    name::Identifier
    delimiter::Punctuator{:colon}
    eol1::EOL
    list::NodeList{Transition, EOL}
    eol2::MaybeToken{EOL}
    final::Punctuator{:end}
end

struct Accepter <: ASTNode
    keyword::Keyword{:accept}
    delimiter::Punctuator{:colon}
    items::NodeList{Goto, Punctuator{:comma}}
    eol::EOL
end

struct Recogniser <: ASTNode
    keyword::Keyword{:recognise}
    delimiter::Punctuator{:colon}
    items::NodeList{Identifier, Punctuator{:comma}}
    eol::EOL
end

struct Starter <: ASTNode
    keyword::Keyword{:start}
    delimiter::Punctuator{:colon}
    item::Goto
    eol::EOL
end

struct MachineDef <: ASTNode
    keyword::Keyword{:machine}
    name::Identifier
    delimiter::Punctuator{:colon}
    eol1::MaybeToken{EOL}
    accept::Accepter
    start::Starter
    recognise::Recogniser
    content::NodeList{Declaration, EOL}
    eol2::MaybeToken{EOL}
    final::Punctuator{:end}
end

struct MachineCall <: ASTNode
    name::Identifier
    open::Punctuator{:leftparenthesis}
    arguments::NodeList{Identifier, Punctuator{:comma}}
    close::Punctuator{:rightparentheis}
end

struct Program <: ASTNode
    machines::NodeList{MachineDef, EOL}
    main::MachineCall
    eol::MaybeToken{EOL}
end

function getfirsttoken(T)
    if T <: AbstractToken
        return T
    end
    field_name = fieldnames(T)[1]
    field = fieldtype(T, field_name)
    if T <: ASTNode
        if field <: MaybeToken
            return Union{field.parameters[1], fieldtype(T, fieldnames(T)[2])}
        end
        return getfirsttoken(field)
    end
    return field
end

function parse!(tokens::TokenStream, T::Type{S}) where S <: ASTNode
    fields = [(field, fieldtype(T, field)) for field in fieldnames(T)]
    field_names = Vector{Any}(undef, length(fields))
    for (x, field) in enumerate(fields)
        test = parse!(tokens, field[2])
        field_names[x] = test
    end
    return T(field_names...)
end

function parse!(tokens::TokenStream, T::Type{NodeList{D, S}}) where {D <: Union{AbstractToken, ASTNode}, S <: AbstractToken}
    eltype, delimtype = T.parameters[1], T.parameters[2]
    vector = Vector{eltype}([])
    current = peek!(tokens)
    while current isa getfirsttoken(eltype)
        push!(vector, parse!(tokens, eltype))
        current = peek!(tokens)
        if !(current isa delimtype)
            break
        end
        consume!(tokens)
        current = peek!(tokens)
    end
    return NodeList{eltype, delimtype}(vector)
end

function parse!(tokens::TokenStream, T::(Type{S})) where S <: AbstractToken
    current = peek!(tokens)
    if current isa S
        consume!(tokens)
        return current
    end
    throw(error("Parser Error: Expected '$S', not '$current'."))
end

function parse!(tokens::TokenStream, T::Type{MaybeToken{S}}) where S <: AbstractToken
    if isEOF(tokens)
        return MaybeToken{S}(nothing)
    end
    current = peek!(tokens)   
    if current isa S
        return MaybeToken{S}(parse!(tokens, S))
    end
    return MaybeToken{S}(nothing)
end
