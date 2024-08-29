#module TuringMachineCompiler

export compiletml

include("lexer.jl")
include("parser.jl")
include("generator.jl")

function compiletml(source::String, destination::String)
    tokens = lex(source)
    ast = parse!(tokens, Program)
    prindentln(ast)
    asm = generate(ast)

    open(destination, "w") do file
        for line in asm
            write(file, line*"\n")
        end
    end
end

#end

compiletml("tm_code/t1.tml", "test1.asm")