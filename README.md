# Welcome to the Turing Machine Compiler and Simulator

This project is written in Julia, and will require Julia to be installed in order to run. You can learn about julia here: https://julialang.org.

## Turing Machine Compiler

Converts a custom turing machine language into 32 bit x86 assembly targeted for NASM on Linux. You run the only exported method which is "compiletml" with an input file and specify an output file name. This will save the relevant assembly code to the destination specified which can then further be compiled to an elf or similar using NASM https://www.nasm.us.

Tape is 1000 bytes long and null terminated at both ends to ensure that the machine doesn't eat up ram. It is therefore important that the language of the machine doesn't contain the null character, or ascii 0 otherwise it may continue to eat up ram.

### Usage

All code is located in the turingmachine_compiler directory, and you can include it into a julia REPL session as follows:

```julia

julia> include("path/to/TuringCompiler.jl")
Main.TuringMachineCompiler

julia> using .TuringMachineCompiler

julia> compiletml("path/to/turingmachine.tml", "turingmachine.asm")

julia>
```

And then to assemble, you can use

```shell
$ nasm -f elf -o turingmachine.o turingmachine.asm
$ ld -m elf_i386 -o turingmachine turingmachine.o
```

And finally to run with gdb, I like to use something along the lines of

```shell
$ gdb turingmachine
$ (gdb) break _start
$ (gdb) run
$ (gdb) si
```

And then you can just keep stepping through the program. Additionally, using

```shell
$ (gdb) layout asm
```

is also interesting so you can see the assembly code that is being executed.

## Turing Machine Language (TML)

You can find the formal language specification in the turing_machine_language_CFG file as well as the following example:

```

machine writepattern:
    accept: q4
    start: q1
    recognise: E, 0, 1


    state q1:
        0 -> q2, 0, RIGHT
        1 -> q1, 1, RIGHT
        E -> @moveright, 1, RIGHT
    end

    state q2:
        0 -> q3, 0, RIGHT
        1 -> q1, 1, RIGHT
        E -> @moveright, 1, LEFT
    end

    state q3:
        0 -> @moveleft, 0, RIGHT
        1 -> q1, 1, RIGHT
        E -> @moveright, 1, LEFT
    end
end

machine moveright:
    accept: q4
    start: q1
    recognise: E, 0, 1

    state q1:
        0 -> q1, 0, RIGHT
        1 -> q1, 1, RIGHT
        E -> q4, 1, LEFT
    end
end

machine moveleft:
    accept: q4
    start: q1
    recognise: E, 0, 1

    state q1:
        0 -> q1, 0, LEFT
        1 -> q1, 1, LEFT
        E -> q4, 1, RIGHT
    end
end

writepattern(0, 0, 0)
```

Machines are declared with the 'machine' keyword. You can declare as many machines as you want, but there can only be one call which must happen after all the declarations have been made, kind of like a main function. You should define the accepting state(s), starting state, and language using the appropriate keywords (in that order). Then you can list as many state transitions as you like. Make sure to enclose the transitions of each state between

```
    :
        ...
    end
```

blocks. A transition is of the form `<input letter> -> <output letter>, <output state>, <direction>`. When specifying an output state, you may also reference a separate turing machine definition using the '@' symbol before the name of the machine. This will move the program execution into that machine.

When you call a machine, you may specify an input which is given by listing the characters separated by commas. Note that by default the tape is initialised to all 'E' characters. The turing machine will start at the leftmost character specified in the input.
