abstract type AbstractToken end

mutable struct Tokeniser
    token_matchers::Vector{Regex}
    tokens::Vector{Type{T} where T<:AbstractToken}
    position::Integer
end

struct ParametricToken{TokenType, TokenKind} <: AbstractToken
    value::String
end

struct BasicToken{TokenType} <: AbstractToken
    value::String
end
 
const Whitespace    = BasicToken{:Whitespace}
const Identifier    = BasicToken{:Identifier}
const EOL           = BasicToken{:EOL}
const Punctuator{T} = ParametricToken{:Punctuator, T}
const Literal{T}    = ParametricToken{:Literal, T}
const Keyword{T}    = ParametricToken{:Keyword, T}


mutable struct TokenStream
    tokens::Vector{AbstractToken}
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
    matches = Vector{AbstractToken}()
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

function clean!(tokens::TokenStream, T::(Type{U} where U <: AbstractToken)...)
    map(t -> filter!(x -> !(x isa t), tokens.tokens), collect(T))
    return tokens
end

function lex(file_path::String)
    tokeniser = Tokeniser(
        [
            r"(\t| )+",
            r"\w+",
            r"state",
            r"recognise",
            r"start",
            r"accept",
            r"machine",
            r":",
            r",",
            r"->",
            r"end",
            r"\)",
            r"\(",
            r"@",
            r"STAY",
            r"LEFT",
            r"RIGHT",
            r"(\r\n?[ \t]*|\r?\n[ \t]*)+",
        ],
        [
            Whitespace,
            Identifier,
            Keyword{:state},
            Keyword{:recognise},
            Keyword{:start},
            Keyword{:accept},
            Keyword{:machine},
            Punctuator{:colon},
            Punctuator{:comma},
            Punctuator{:map},
            Punctuator{:end},
            Punctuator{:rightparentheis},
            Punctuator{:leftparenthesis},
            Punctuator{:referenceindicator},
            Literal{:STAY},
            Literal{:LEFT},
            Literal{:RIGHT},
            EOL
        ],
        1
    )
    
    tokens = Vector{AbstractToken}()

    file_string = open(file_path, "r") do file
        read(file, String)
    end
    
    while tokeniser.position <= length(file_string)
        token = read_token!(tokeniser, file_string)
        if token !== nothing
            push!(tokens, token)
        end
    end
    
    return clean!(TokenStream(tokens, 1), Whitespace)
end