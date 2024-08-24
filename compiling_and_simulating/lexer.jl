abstract type Token end

mutable struct Tokeniser
    token_matchers::Vector{Regex}
    tokens::Vector{Type{T} where T<:Token}
    position::Integer
end

struct BasicToken{T} <: Token
    value::String
end

const Whitespace = BasicToken{:Whitespace}
const Identifier = BasicToken{:Identifier}
const Direction = BasicToken{:Direction}
const Map = BasicToken{:Map}
const State = BasicToken{:State}
const Recognise = BasicToken{:Recognise}
const Start = BasicToken{:Start}
const Accept = BasicToken{:Accept}
const Machine = BasicToken{:Machine}
const Colon = BasicToken{:Colon}
const Comma = BasicToken{:Comma}
const EOL = BasicToken{:EOL}
const Terminator = BasicToken{:Terminator}
const Referencer = BasicToken{:Referencer}
const LeftParenthesis = BasicToken{:LeftParenthesis}
const RightParenthesis = BasicToken{:RightParenthesis}

mutable struct TokenStream
    tokens::Vector{Token}
    position::Integer
end

function peek!(tokens::TokenStream)
    return tokens.tokens[tokens.position]
end

function consume!(tokens::TokenStream)
    tokens.position += 1
    return tokens.tokens[tokens.position - 1]
end

function isEOF(tokens::TokenStream)
    return (tokens.position >= length(tokens.tokens))
end

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