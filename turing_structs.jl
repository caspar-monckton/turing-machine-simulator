using Random

export Tape, TuringMachine, ishalted, emptytape, write!, stepcomputation!, run!, load!, unload!, reset!

abstract type AbstractTuringMachine end

# Symbols are represented by strings and so don't have to be limited to a single character.
mutable struct Tape
    cwr_right::Vector{String}
    cwr_mid::String
    cwr_left::Vector{String}
    child_machines::Vector{AbstractTuringMachine}
    unbound_memory_sym::String
end

mutable struct TuringMachine <: AbstractTuringMachine
    name::String
    alphabet::Vector{String}
    start_state::String
    current_state::String
    position::Integer
    instruction_set::Dict{Tuple{String, String}, Tuple{String, String, Integer}}
    accepting_states::Vector{String}
    parent_tape::Union{Nothing, Tape}
end

function Base.show(io::IO, machine::TuringMachine)
    rule_strings = join([string(key)*" -> "*string(machine.instruction_set[key]) for key in keys(machine.instruction_set)], "\n")
    accept_string = join(machine.accepting_states, ", ")
    print(io, "'$(machine.name)' (position: $(machine.position), state: $(machine.current_state)):\naccepts: $(accept_string)\n$rule_strings")
end

# Only shows the first character for each symbol.
function Base.show(io::IO, tape::Tape)
    sym_left = [string(i[1]) for i in tape.cwr_left]
    sym_right = [string(i[1]) for i in tape.cwr_right]
    sym_mid = (tape.cwr_mid)[1]

    left = ""
    right = ""

    if length(tape.child_machines) == 0
        left = join(sym_left, "")
        right = join(sym_right, "")
    else
        for m in tape.child_machines
            p = m.position
            if p == 0
                sym_mid = "[$sym_mid]"
            elseif p > 0
                if p > length(tape.cwr_right)
                    push!(sym_right, "[$(tape.unbound_memory_sym[1])]")
                else
                    sym_right[p] = "[$(sym_right[p])]"
                end
            elseif p < 0
                if -p > length(tape.cwr_left)
                    push!(sym_left, "[$(tape.unbound_memory_sym[1])]")
                else
                    sym_left[-p] = "[$(sym_left[-p])]"
                end
            end
        end
        left = join(reverse(sym_left), "")
        right = join(sym_right, "")
    end

    p_tape = " "*left*sym_mid*right*" "
    print(io, "$p_tape")
end

function ishalted(machine::TuringMachine)
    machine.current_state in machine.accepting_states
end

function emptytape(unbound_memory_sym::String = "EMPTY")
    return Tape([], unbound_memory_sym, [], [], unbound_memory_sym)
end

function write!(t::Tape, index::Integer, value::String)
    if index == 0
        t.cwr_mid = value
    elseif index > 0
        if (index <= length(t.cwr_right))
            t.cwr_right[index] = value
        elseif index == length(t.cwr_right) + 1
            push!(t.cwr_right, value)
        else
            throw(error("Tape writing attempted from illegal position."))
        end

    elseif index < 0
        if (-index <= length(t.cwr_left))
            t.cwr_left[-index] = value
        elseif -index == length(t.cwr_left) + 1
            push!(t.cwr_left, value)
        else
            throw(error("Tape writing attempted from illegal position."))
        end
    end
end

function Base.read(t::Tape, index::Integer)
    if index == 0
        return t.cwr_mid
    elseif index > 0
        if (index <= length(t.cwr_right))
            return t.cwr_right[index]
        elseif index == length(t.cwr_right) + 1
            return t.unbound_memory_sym
        else
            throw(error("Tape reading attempted from illegal position."))
        end
    elseif index < 0
        if (-index <= length(t.cwr_left))
            return t.cwr_left[-index]
        elseif -index == length(t.cwr_left) + 1
            return t.unbound_memory_sym
        else
            throw(error("Tape reading attempted from illegal position."))
        end
    end
end

function stepcomputation!(machine::TuringMachine)
    if ishalted(machine)
        return
    end

    tape = machine.parent_tape
    if tape == nothing
        throw(error("Turing machine not bound to tape. Computation not permitted."))
    end

    key = (machine.current_state, read(tape, machine.position))
    #println(key)
    if !(key in keys(machine.instruction_set))
        throw(error("Turing machine encountered unrecognised symbol or state."))
    end

    step_result = machine.instruction_set[key]
    write!(tape, machine.position, step_result[2])
    machine.current_state = step_result[1]
    machine.position += step_result[3]
end

# If two or more Turing machines try to write the same cell, select one at random and have only 
# it execute its instruction.
function stepcomputation!(tape::Tape)
    position_map = Dict()
    for machine in tape.child_machines
        if machine.position in keys(position_map)
            push!(position_map[machine.position], machine)
            r_machine = rand(position_map[machine.position])
            stepcomputation!(r_machine)
        else
            position_map[machine.position] = [machine]
            stepcomputation!(machine)
        end
    end
end

function run!(tape::Tape, iterations::Integer; printing::Bool = true)
    for i in 1:iterations
        stepcomputation!(tape)
        if printing
            println(tape)
        end
    end
end

function load!(tape::Tape, machine::TuringMachine)
    if machine in tape.child_machines
        throw(error("$(machine) already bound to tape."))
    end
    push!(tape.child_machines, machine)
    machine.parent_tape = tape
end

"""
    reset!(machine::TuringMachine)
"""
function reset!(machine::TuringMachine)
    machine.position = 0
    machine.current_state = machine.start_state
    return nothing
end

"""
    reset!(tape::Tape, input::Vector{String} = [tape.unbound_memory_sym]; middle::Integer = 1)
"""
function reset!(tape::Tape, input::Vector{String} = [tape.unbound_memory_sym]; middle::Integer = 1)
    for machine in tape.child_machines
        reset!(machine)
    end

    tape.cwr_mid = input[middle]
    tape.cwr_left = input[begin:middle - 1]
    tape.cwr_right = input[middle + 1:end]
    return nothing
end


"""
    unload!(tape::Tape, machine::TuringMachine)
"""
function unload!(tape::Tape, machine::TuringMachine)
    if !(machine in tape.child_machines)
        throw(error("No TuringMachine $(machine) bound to tape."))
    end
    filter!(x -> x !== machine, tape.child_machines)
    return nothing
end
