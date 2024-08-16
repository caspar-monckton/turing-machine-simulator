mutable struct Tokeniser
    token_matchers::Vector{Regex}
    tokens::Vector{String}
    position::Int
end

function read_token!(tokeniser::Tokeniser, matchee::String)
    matches = Vector{Tuple{String, Int}}()
    for i in tokeniser.position:length(matchee)
        submatchee = String(matchee[tokeniser.position:i])
        atleastonematch = false

        for (x, matcher) in enumerate(tokeniser.token_matchers)
            if occursin(matcher, submatchee)
                mc = match(matcher, submatchee)
                if mc !== nothing && mc.match == submatchee
                    push!(matches, (mc.match, x))
                    atleastonematch = true
                end
            end
        end
        
        if !atleastonematch
            if isempty(matches)
                continue
            end
            token = matches[end]
            tokeniser.position += length(token[1])
            println(token)
            return token
        end
    end
    
    if !isempty(matches)
        token = matches[end]
        tokeniser.position += length(token[1])
        return token
    end
    
    throw(error("invalid token '$(matchee[tokeniser.position])'."))
end

function lex(file_path::String)
    tokeniser = Tokeniser(
        [
            r"\t| ",
            r"\w+",
            r"[0-9]",
            r"UMS",
            r"STAY",
            r"LEFT",
            r"RIGHT",
            r"->",
            r"state",
            r"recognise",
            r"start",
            r"accept",
            r"from",
            r"machine",
            r":",
            r",",
            r"end",
            r"@",
            r"\)",
            r"\(",
            r"\r?\n"
        ],
        [
            "WHITESPACE",
            "IDENTIFIER",
            "NUMERAL",
            "UMS",
            "STAY",
            "LEFT",
            "RIGHT",
            "MAP",
            "STATE",
            "RECOGNISE",
            "START",
            "ACCEPT",
            "FROM",
            "MACHINE",
            "COLON",
            "COMMA",
            "END",
            "REFERENCE",
            "RIGHT_PARENTHESIS",
            "LEFT_PARENTHESIS",
            "EOL"
        ],
        1
    )
    
    tokens = Vector{Tuple{String, Int}}()

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
    
    return tokens
end

function parse(tokens)
    # Transition

end

tokens = lex("tm_code/new_test.tml")
for token in tokens
    println(token)
end
