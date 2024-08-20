abstract type Token end

mutable struct Tokeniser
    token_matchers::Vector{Regex}
    tokens::Vector{Type{T} where T<:Token}
    position::Integer
end

#Tokens:
struct Whitespace <: Token
    value::String
end

struct Identifier <: Token
    value::String
end

struct State <: Token
    value::String
end

struct Accept <: Token
    value::String
end

struct Start <: Token
    value::String
end

struct Recognise <: Token
    value::String
end

struct Machine <: Token
    value::String
end

struct Direction <: Token
    value::String
end

struct Map <: Token
    value::String
end

struct LeftParenthesis <: Token
    value::String
end

struct RightParenthesis <: Token
    value::String
end

struct Colon <: Token
    value::String
end

struct Comma <: Token
    value::String
end

struct EOL <: Token
    value::String
end

struct Terminator <: Token
    value::String
end

struct Referencer <: Token
    value::String
end

#AST Nodes:
abstract type ASTNode end

struct MachineRef <: ASTNode
    name::Identifier
end

struct Goto <: ASTNode
    value::Union{MachineRef, Identifier}
end

struct Transition <: ASTNode
    input::Identifier
    output1::State
    output2::Identifier
    output3::Direction
end

struct Declaration <: ASTNode
    name::State
    list::Vector{Transition}
end

struct Accepter <: ASTNode
    items::Vector{Goto}
end

struct Recogniser <: ASTNode
    items::Vector{Identifier}
end

struct Starter <: ASTNode
    item::Goto
end

struct MachineDef <: ASTNode
    name::Identifier
    accept::Accepter
    start::Starter
    recognise::Recogniser
    content::Vector{Declaration}
end

struct MachineCall <: ASTNode
    name::Identifier
    arguments::Vector{Identifier}
end

struct Program <: ASTNode
    machines::Vector{MachineDef}
    main::MachineCall
end

mutable struct TokenStream
    tokens::Vector{Token}
    index::Integer
end

function peek!(tokens::TokenStream)
    return tokens.tokens[tokens.index]
end

function consume!(tokens::TokenStream)
    return tokens.tokens[tokens.index]
    tokens.position += 1
end

function isEOF(tokens::TokenStream)
    return (tokens.position >= length(tokens.tokens))
end

# Lexer

function read_token!(tokeniser::Tokeniser, matchee::String)
    matches = Vector{Token}()
    for i in tokeniser.position:length(matchee)
        submatchee = String(matchee[tokeniser.position:i])
        atleastonematch = false

        for (x, matcher) in enumerate(tokeniser.token_matchers)
            if occursin(matcher, submatchee)
                mc = match(matcher, submatchee)
                if mc !== nothing && mc.match == submatchee
                    push!(matches, tokeniser.tokens[x](mc.match))
                    atleastonematch = true
                end
            end
        end
        
        if !atleastonematch
            if isempty(matches)
                continue
            end
            token = matches[end]
            tokeniser.position += length(token.value)
            println(token)
            return token
        end
    end
    
    if !isempty(matches)
        token = matches[end]
        tokeniser.position += length(token.value)
        return token
    end
    
    throw(error("Lexer error: Invalid token '$(matchee[tokeniser.position])'."))
end

function clean!(tokens::TokenStream, T::(Type{U} where U <: Token)...)
    map(t -> filter!(x -> !(x isa t), tokens.tokens), collect(T))
    return tokens
end

function lex(file_path::String)
    tokeniser = Tokeniser(
        [
            r"(\t| )+",
            r"\w+",
            r"(STAY)|(LEFT)|(RIGHT)",
            r"->",
            r"(state)",
            r"recognise",
            r"start",
            r"accept",
            r"machine",
            r":",
            r",",
            r"end",
            r"@",
            r"\)",
            r"\(",
            r"(\r\n?|\r?\n)+"
        ],
        [
            Whitespace,
            Identifier,
            Direction,
            Map,
            State,
            Recognise,
            Start,
            Accept,
            Machine,
            Colon,
            Comma,
            Terminator,
            Referencer,
            RightParenthesis,
            LeftParenthesis,
            EOL
        ],
        1
    )
    
    tokens = Vector{Token}()

    file_string = open(file_path, "r") do file
        read(file, String)
    end

    println(file_string)
    
    while tokeniser.position <= length(file_string)
        token = read_token!(tokeniser, file_string)
        if token !== nothing
            push!(tokens, token)
        end
    end
    
    return clean!(TokenStream(tokens, 1), Whitespace)
end

# Parser
function parse!(tokens::TokenStream, ::MachineRef)
    name = nothing
    current = peek!(tokens)
    if !(current isa Referencer)
        throw(error("Parser error: Expected '@' at the beginning of machine reference."))
    end
    if current isa Identifier
        name = consume!(tokens)
    else
        throw(error("Parser error: Expected identifier as a machine name instead of '$(typeof(token))'."))
    end
    return MachineRef(signifier, name)
end

function parse!(tokens::TokenStream, ::Goto)
    value = nothing
    current = peek!(tokens)
    if current isa Referencer
        value = parse(tokens, MachineRef)
        current = peek!(tokens)
    elseif current isa Identifier
        value = consume!(tokens)
    else 
        throw(error("Parser error: Goto must either be an Identifier or a MachineRef, not '$(typeof(check))'"))
    end
    return Goto(value)
end

function parse!(tokens::TokenStream, ::Transition)
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
    
    if current isa Map
        consume!(tokens)
        current = peek!(tokens)
    else
        throw(error("Parser error: Expected '->' after input value, not '$(typeof(current))'."))
    end

    if current isa Identifier
        output1 = consume!(tokens)
        current = peek!(tokens)
    else
        throw(error("Parser error: Expected 'Identifier' after '->', not '$(typeof(current))'."))
    end

    if current isa Comma
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

    if current isa Comma
        consume!(tokens)
        current = peek!(tokens)
    else
        throw(error("Parser error: Expected ',' not '$(typeof(current))'."))
    end

    if current isa Direction
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

function parse!(tokens::TokenStream, ::Declaration)
    name = nothing
    list = Vector{Transition}()

    current = peek!(tokens)

    if current isa State
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

    if current isa Colon
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

    if current isa Identifier
        while current isa Identifier
            push!(list, parse!(tokens, Transition))
        end
        current = peek!(tokens)
    else
        throw(error("Parser error: Expected declaration, not'$(typeof(current))'."))
    end

    if current isa Terminator
        consume!(tokens)
        current = peek!(tokens)
    else
        throw(error("Parser error: Expected Terminator: 'END', not '$(typeof(current))'."))
    end

    if current isa EOL
        consume!(tokens)
        current = peek!(tokens)
    end

    return Declaration(name, list)
end

function parse!(tokens::TokenStream, ::Accepter)
    title = nothing
    items = Vector{Goto}()

    current = peek!(tokens)

    if current isa Accept
        title = consume!(tokens)
        current = peek!(tokens)
    else
        throw(error("Parser error: 'Accepter' should start with 'accept' keyword, not '$(typeof(current))'."))
    end

    if current isa Colon
        consume!(tokens)
        current = peek!(tokens)
    else
        throw(error("Parser error: ':' should follow 'accept' keyword, not '$(typeof(current))'."))
    end

    if (current isa Identifier || current isa Referencer)
        while (current isa Identifier || current isa Referencer)
            temp = peek!(tokens)
            push!(items, parse!(tokens, Goto))
            if temp isa Comma
                current = consume!(tokens)
            elseif temp isa EOL
                break
            else
                throw(error("Parser error: Expected 'Comma' between arguments."))
            end
        end
    else
        throw(error("Parser error: Expected 'Goto', not '$(typeof(current))'."))
    end

    if current isa EOL
        consume!(tokens)
        current = peek!(tokens)
    else
        throw(error("Parser error: Expected newline after end of statement, not '$(typeof(current))'."))
    end
    return Accepter(title, items)
end

function parse!(tokens::TokenStream, ::Recogniser)
    title = nothing
    items = Vector{Identifier}()

    current = peek!(tokens)

    if current isa Accept
        title = consume!(tokens)
        current = peek!(tokens)
    else
        throw(error("Parser error: 'Recogniser' should start with 'recognise' keyword, not '$(typeof(current))'."))
    end

    if current isa Colon
        consume!(tokens)
        current = peek!(tokens)
    else
        throw(error("Parser error: ':' should follow 'recognise' keyword, not '$(typeof(current))'."))
    end

    if current isa Identifier
        while current isa Identifier
            temp = peek!(tokens)
            push!(items, consume!(tokens))
            if temp isa Comma
                current = consume!(tokens)
            elseif temp isa EOL
                break
            else
                throw(error("Parser error: Arguments specified incorrectly."))
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
    return Recogniser(title, items)
end

function parse!(tokens::TokenStream, ::Starter)
    title = nothing
    item = nothing

    current = peek!(tokens)

    if current isa Accept
        title = consume!(tokens)
        current = peek!(tokens)
    else
        throw(error("Parser error: 'Starter' should start with 'start' keyword, not '$(typeof(current))'."))
    end

    if current isa Colon
        end_name = consume!(tokens)
        current = peek!(tokens)
    else
        throw(error("Parser error: ':' should follow 'start' keyword, not '$(typeof(current))'."))
    end

    if (current isa Identifier || current isa Referencer)
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
    return Starter(title, item)
end

function parse!(tokens::TokenStream, ::MachineCall)
    name = nothing
    arguments = Vector{Declaration}()

    current = peek!(tokens)

    if current isa Identifier
        name = consume!(tokens)
        current = peek!(tokens)
    else
        throw(error("Parser error: machine call should be an 'Identifier', not '$(typeof(current))'."))
    end

    if current isa Colon
        consume!(tokens)
        current = peek!(tokens)
    else
        throw(error("Parser error: ':' should follow machine name, not '$(typeof(current))'."))
    end

    if (current isa Accept)
        accept = parse!(tokens, Accepter)
        current = peek!(tokens)
    else
        throw(error("Parser error: Expected 'accept' keyword, not '$(typeof(current))'."))
    end

    if (current isa Start)
        start = parse!(tokens, Starter)
        current = peek!(tokens)
    else
        throw(error("Parser error: Expected 'start' keyword, not '$(typeof(current))'."))
    end

    if (current isa Recognise)
        recognise = parse!(tokens, Recogniser)
        current = peek!(tokens)
    else
        throw(error("Parser error: Expected 'recognise' keyword, not '$(typeof(current))'."))
    end

    if current isa EOL
        consume!(tokens)
        current = peek!(tokens)
    end

    if current isa State
        while current isa State
            push!(content, parse!(tokens, Declaration))
            current = peek!(tokens)
        end
    else
        throw(error("Parser error: Expected 'State' keyword, not '$(typeof(current))'."))
    end

    if !(current isa Terminator)
        throw(error("Parser error: Expected 'end' keyword to finish machine scope, not '$(typeof(current))'."))
    end
    return MachineDef(name, accept, start, recognise, content)    
end

function parse!(tokens::TokenStream, ::MachineRef)
    name = nothing
    accept = nothing
    recognise = nothing
    start = nothing
    content = Vector{Declaration}()

    current = peek!(tokens)

    if current isa Machine
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

    if current isa Colon
        consume!(tokens)
        current = peek!(tokens)
    else
        throw(error("Parser error: ':' should follow machine name, not '$(typeof(current))'."))
    end

    if (current isa Accept)
        accept = parse!(tokens, Accepter)
        current = peek!(tokens)
    else
        throw(error("Parser error: Expected 'accept' keyword, not '$(typeof(current))'."))
    end

    if (current isa Start)
        start = parse!(tokens, Starter)
        current = peek!(tokens)
    else
        throw(error("Parser error: Expected 'start' keyword, not '$(typeof(current))'."))
    end

    if (current isa Recognise)
        recognise = parse!(tokens, Recogniser)
        current = peek!(tokens)
    else
        throw(error("Parser error: Expected 'recognise' keyword, not '$(typeof(current))'."))
    end

    if current isa EOL
        consume!(tokens)
        current = peek!(tokens)
    end

    if current isa State
        while current isa State
            push!(content, parse!(tokens, Declaration))
            current = peek!(tokens)
        end
    else
        throw(error("Parser error: Expected 'Identifier' or '@ Identifier', not '$(typeof(current))'."))
    end

    if !(current isa Terminator)
        throw(error("Parser error: Expected 'end' keyword to finish machine scope, not '$(typeof(current))'."))
    end
    return MachineDef(name, accept, start, recognise, content)    
end

tokens = lex("tm_code/new_test.tml")
for token in tokens.tokens
    println(token)
end
ast = parse!(tokens, Program)