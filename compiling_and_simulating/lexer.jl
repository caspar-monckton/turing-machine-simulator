abstract type AbstractToken end

mutable struct Tokeniser
    token_matchers::Vector{Regex}
    tokens::Vector{Type{T} where T<:AbstractToken}
    position::Integer
end

struct Token{TokenType} <: AbstractToken
    value::String
end
            
const Whitespace = Token{:Whitespace}
const Identifier = Token{:Identifier}
const Punctuator = Token{:Punctuator}
const Literal    = Token{:Literal}
const Keyword    = Token{:Keyword}
const EOL        = Token{:EOL}

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
            r"state|recognise|start|accept|machine",
            r":|,|->|end|\)|\(|@",
            r"STAY|LEFT|RIGHT",
            r"(\r\n?|\r?\n)+",
        ],
        [
            Whitespace,
            Identifier,
            Keyword,
            Punctuator,
            Literal,
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