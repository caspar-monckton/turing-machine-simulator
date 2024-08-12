export parseline, compileturingmachine

"""
    parseline(line::String)

Split string separated by ':' and ',' into command and argument list.
"""
function parseline(line::String)
    if line == ""
        return
    end

    initial_split = map(strip, split(line, ":"))
    if length(initial_split) > 2
        throw(error("Only declare one command can be declared per line. Unexpected ':'."))
    end

    line_modules = []
    push!(line_modules, initial_split[1])
    push!(line_modules, map(strip, split(initial_split[2], ",")))

    return line_modules
end

"""
    compileturingmachine(file_path::String)

Interpret file written in .tml (turing machine language) format and load into TuringMachine struct.

# Examples
```
julia> compileturingmachine("busy_beaver4.tml")
'busy_beaver4' (position: 0, state: 0):
accepts: HALT
("1", "1") -> ("2", "0", -1)
("3", "1") -> ("0", "0", 1)
("3", "0") -> ("3", "1", 1)
("0", "0") -> ("1", "1", 1)
("1", "0") -> ("0", "1", -1)
("2", "1") -> ("3", "1", -1)
("0", "EMPTY") -> ("1", "1", 1)
("2", "0") -> ("HALT", "1", -1)
("1", "EMPTY") -> ("0", "1", -1)
("2", "EMPTY") -> ("HALT", "1", -1)
("3", "EMPTY") -> ("3", "1", 1)
("0", "1") -> ("1", "1", -1)
```
"""
function compileturingmachine(file_path::String)
    direction_map = Dict(["LEFT" => -1, "RIGHT" => 1, "STAY" => 0])

    lines = []
    name = ""
    alphabet = ["0", "1", "EMPTY"]
    start_state = ""
    position = 0
    instruction_set = Dict()
    accepting_states = []
    parent_tape = nothing

    open(file_path, "r") do file
        for (lindex, line) in enumerate(eachline(file))
            line_data = parseline(line)
            if line_data == nothing
                continue
            end
            command = line_data[1]
            parameters = line_data[2]
            try
                if command == "name"
                    if length(parameters) > 1
                        throw(error("Name cannot contain ','."))
                    elseif length(parameters) < 1
                        throw(error("Name must not be empty."))
                    end
                    name = parameters[1]
                elseif command == "accepts"
                    if length(parameters) == 0
                        throw(error("Must provide accepting states or leave blank for none."))
                    end
                    accepting_states = parameters
                elseif command == "start"
                    if length(parameters) != 1
                        throw(error("'start' must only contain one state."))
                    end
                    start_state = parameters[1]
                elseif command == "alphabet"
                    if !("EMPTY" in parameters)
                        throw(error("Alphabet must contain the empty word 'EMPTY'."))
                    end
                    alphabet = parameters
                elseif command == "rule"
                    if length(parameters) != 5
                        throw(error("Incorrect number of parameters."))
                    end
                    if !(parameters[5] in keys(direction_map))
                        throw(error("Invalid direction '$(parameter[5])' specified in rule."))
                    end
                    instruction_set[(parameters[1], parameters[2])] = (parameters[3], parameters[4], direction_map[parameters[5]])
                end
            catch e
                println("Line $lindex, $(typeof(e)): $(e.msg)")
            end
        end
    end
    return TuringMachine(name, alphabet, start_state, start_state, position, instruction_set, accepting_states, parent_tape)
end