include("TuringMachines.jl")
using .TuringMachines

"""
Command that user can invoke by name to achieve functionality via a callback function.
"""
struct Command
    name::String
    documentation::String
    callback::Function
end

"""
    about(command::Command)

Print the documentation for 'command'.
"""
function about(command::Command)
    println(command.documentation)
end

function main()
    commands = Dict()
    tapes = Tape[]
    machines = TuringMachine[]

    function help_f() 
        for command_name in keys(commands)
            println(command_name)
        end
    end

    function help_f(command_name::String)
        println("$(command_name): $(commands[command_name].documentation)")
    end

    help = Command(
            "help", 
            """
            List commands available to user. 

            Use cases:
            \thelp [command_name]: Print detailed information about [command_name] if it exists.
            """, 
            help_f
    )

    function quit_f()
        print("Quitting...")
        exit()
    end

    quit = Command("quit", """Exit the environment loop.""", quit_f)

    function load_f(object_type::String, field_parameters::String)
        if object_type == "-m"
            m = compileturingmachine(field_parameters)
            push!(machines, m)
        elseif object_type == "-t"
            if field_parameters == "-e"
                push!(tapes, emptytape())
            end
        end
    end

    load = Command("load",
                    """
                    Load turing machine or tape into the current environment.

                    Use cases:
                    \tload -m [turing_machine_file_path]: Load turing machine specified by .tml file specified at file path given.
                    \tload -t -e: Load an empty tape into the current environment.
                    """, 
                    load_f
            )
    
    function view_f(region::String)
        if region == "-env"
            println("Turing Machines: ")
            for (x, machine) in enumerate(machines)
                println("$x: $machine")
                println("")
            end
            println("Tapes: ")
            for (x, tape) in enumerate(tapes)
                println("$x: $tape")
                println("")
            end
        end
    end

    view = Command("view", 
                    """
                    View something in the environment or the entire environment.

                    Use cases:
                    \t view -env: Print all turing machines and tapes currently loaded into the environment.
                    """, 
                    view_f
    )

    function run_f(index::String, step::String = "1", printing::String = "-p")
        i = parse(Int, index)
        iterations = parse(Int, step)

        for it in 1:iterations
            stepcomputation!(tapes[i])
            if printing == "-p"
                println(tapes[i])
            elseif !(printing == "-b")
                throw(error("Invalid argument supplied to 'printing' parameter."))
            end
        end
    end

    run = Command("run", 
                    """
                    Run tape at specified index for specified number of iterations.

                    Use cases:
                    \trun [index] [iterations]: run tape at [index] for [iterations] and print the state of the tape after each iteration.
                    \trun [index] [iterations] -b: run tape as above but do not print state of tape after each iteration.
                    """, run_f
    )

    function bind_f(tape_index::String, machine_index::String)

        mi = parse(Int, machine_index)
        ti = parse(Int, tape_index)

        load!(tapes[ti], machines[ti])
    end

    bind = Command("bind", 
                    """
                    Bind turing machine to tape.

                    Use cases:
                    \tbind [tape index] [machine index]: Bind the [tape index]th tape with the [machine index]th machine.
                    """, bind_f
    )

    function unbind_f(tape_index::String, machine_index::String)
        mi = parse(Int, machine_index)
        ti = parse(Int, tape_index)
        
        unload!(tapes[ti], machines[ti])
    end

    unbind = Command("unbind", 
                    """
                    Remove turing machine from tape.

                    Use cases:
                    \tunbind [tape index] [machine index]: Unbind the [tape index]th tape from the [machine index]th machine.
                    """, unbind_f)


    function remove_f(object_type::String, index::String)
        i = parse(Int, index)
        if object_type == "-t"
            for m in filter((x -> (x.parent_tape == tapes[i])), [m for m in machines])
                unbind!(m)
            end
            deleteat!(tapes, i)
        elseif object_type == "-m"
            t = machines[i].parent_tape
            unload(t, machines[i])
            deleteat!(machines, i)
        else
            throw(error("Object type not recognised."))
        end
    end

    remove = Command("remove", 
                    """
                    Remove object from the current environment.

                    Use cases:
                    \tremove -m [index]: Remove machine at [index].
                    \tremove -t [index]: Remove tape at [index].
                    """, remove_f)

    commands[help.name] = help
    commands[quit.name] = quit
    commands[load.name] = load
    commands[view.name] = view
    commands[run.name] = run
    commands[bind.name] = bind
    commands[unbind.name] = unbind
    commands[remove.name] = remove

    while true
        print(">> ")
        (command_name, args...) = [String(i) for i in split(readline(), " ")]

        try 
            (commands[command_name].callback)(args...)
        catch e
            if isa(e, KeyError)
                println("Invalid command. Try 'help' to see list of available commands.")
            elseif isa(e, MethodError) || isa(e, ArgumentError)
                println("Invalid arguments. Try 'help $command_name' for information on how to use $command_name.")
            else
                throw(e)
            end
        end
    end
end

main()