const BYTE_ADDRESS_MULTIPLIER = 1

const registers = [
     "eax", "ebx",  "ecx",  "edx", 
     "ax",   "bx",   "cx",   "dx",
     "al",   "bl",   "cl",   "dl",
     "ah",   "bh",   "ch",   "dh",
    "edi",  "esi",  "ebp",  "esp",
    "r8d",  "r9d", "r10d", "r11d",
    "r12d", "r13d", "r14d", "r15d",
    "r8w",  "r9w", "r10w", "r11w",
    "r12w", "r13w", "r14w", "r15w",
    "r8b",  "r9b", "r10b", "r11b",
    "r12b", "r13b", "r14b", "r15b",
]

createlabel(name::String) = "$name:"

createsection(name::String) = "section $name"

declareglobal(name::String) = "global $name"

interrupt(name::String) = "\tINT $name"

function addregs(reg1::String, reg2::String)
    if !((reg1 in registers) && (reg2 in registers))
        throw(error("Generator error: Invalid register destination specified."))
    end

    return "\tADD $reg1, $reg2"
end

function addregs(reg1::String, val::Integer)
    if !(reg1 in registers)
        throw(error("Generator error: Invalid register destination specified."))
    end

    return "\tADD $reg1, $val"
end

function subregs(reg1::String, val::Integer)
    if !(reg1 in registers)
        throw(error("Generator error: Invalid register destination specified."))
    end

    return "\tSUB $reg1, $val"
end

function initdata(name::String, size::String, default_value::Integer, amount::Integer = 1)
    if !(size in ["DB", "DW", "DD"])
        throw(error("Generator error: Invalid data size specifier."))
    end
    if amount == 1
        return "\t$name $size $default_value"
    elseif amount > 0
        return "\t$name $size $amount DUP($default_value)"
    end
end

function initdata(name::String, size::String, default_value::Vector{<:Integer})
    if !(size in ["DB", "DW", "DD"])
        throw(error("Generator error: Invalid data size specifier."))
    end
    data_list = join(default_value, ", ")
    return "\t$name $size $data_list"
end

function movtoreg(reg::String, value::Integer)
    if !(reg in registers)
        throw(error("Generator error: Invalid register destination specified."))
    end
    return "\tMOV $reg, $value"
end

function movtoreg(reg::String, value::String; is_address::Bool = false)
    if !(reg in registers)
        throw(error("Generator error: Invalid register destination specified."))
    end
    if is_address
        return "\tMOV $reg, $value"
    else
        return "\tMOV $reg, [$value]"
    end
end

function movtodata(name::String, registersrc::String)
    if !(registersrc in registers)
        throw(error("Generator error: Invalid register destination specified."))
    end

        return "\tMOV [$name], $registersrc"
end

function jump(destination::String, condition::String = "")
    conditions = ["GE", "LE", "E", "L", "G", "NE"]
    if condition == ""
        return "\tJMP $destination"
    end
    if !(condition in conditions)
        throw(error("Generator error: Invalid jump condition."))
    end
    
    return "\tJ$condition $destination"

end

function increg(reg::String)
    if !(reg in registers)
        throw(error("Generator error: Invalid register destination specified."))
    end

    return "\tINC $reg"
end

function decreg(reg::String)
    if !(reg in registers)
        throw(error("Generator error: Invalid register destination specified."))
    end

    return "\tDEC $reg"
end

function compregs(reg1::String, reg2::String)
    if !((reg1 in registers) && (reg2 in registers))
        throw(error("Generator error: Invalid register destination specified."))
    end

    return "\tCMP $reg1, $reg2"
end

function compregs(reg1::String, val::String)
    if !(reg1 in registers)
        throw(error("Generator error: Invalid register destination specified."))
    end

    return "\tCMP $reg1, $val"
end

#returns multiple lines of assembly!!
function writestdout(address::String, size::Integer)::Vector{String}
    out = Vector{String}()

    push!(out, movtoreg("eax", 4))
    push!(out, movtoreg("ebx", 1))
    push!(out, movtoreg("ecx", address; is_address = true))
    push!(out, movtoreg("edx", size))
    push!(out, interrupt("80h"))

    return out
end

timesinstruction(iterations::Integer, instruction::String) = "\ttimes $iterations $instruction"

function generate(transition::Transition, parent::Declaration, superparent::MachineDef)
    lines = Vector{String}()
    push!(lines, createlabel("$(superparent.name.value)_$(parent.name.value)_$(Int(transition.input.value[1]))"))
    push!(lines, movtoreg("r8b", Int(transition.output2.value[1])))
    push!(lines, movtodata("r10d", "r8b"))
    if transition.output3.value == "RIGHT"
        push!(lines, addregs("r10d", BYTE_ADDRESS_MULTIPLIER))
    elseif transition.output3.value == "LEFT"
        push!(lines, subregs("r10d", BYTE_ADDRESS_MULTIPLIER))
    end
    push!(lines, movtoreg("r9b", "r10d"))
    if transition.output1 in superparent.accept.items.values
        push!(lines, jump("_HALT"))
    else
        if transition.output1.prefix.token == nothing
            push!(lines, jump(transition.output1.value.value))
        elseif transition.output1.prefix.token isa Identifier
            push!(lines, jump("$(superparent.name.value)_$(transition.output1.value.value)"))
        end
    end
    return lines
end

function generate(declaration::Declaration, parent::MachineDef)
    lines = Vector{String}()
    push!(lines, createlabel("$(parent.name.value)_$(declaration.name.value)"))
    lines = vcat(lines, writestdout("tape", 1000))
    for transition in declaration.list.values
        push!(lines, compregs("r9b", string(Int(transition.input.value[1]))))
        push!(lines, jump("$(parent.name.value)_$(declaration.name.value)_$(Int(transition.input.value[1]))", "E"))
    end
    push!(lines, jump("_FAIL"))

    for transition in declaration.list.values
        lines = vcat(lines, generate(transition, declaration, parent))
    end

    return lines
end

function generate(machine::MachineDef)
    lines = Vector{String}([createlabel(machine.name.value)])
    start = ""
    start = machine.start.item.value.value
    push!(lines, jump("$(machine.name.value)_$start"))
    for declaration in machine.content.values
        lines = vcat(lines, generate(declaration, machine))
    end
    return lines
end

function generate(ast::Program)
    tape_size = 1000
    initial_position = tape_size >> 1
    
    lines = Vector{String}([createsection(".data")])
    push!(lines, initdata("tape", "DB", 0))
    push!(lines, initdata("", "DB", Int('E'), tape_size))
    push!(lines, initdata("", "DB", 0))
    push!(lines, createsection(".text"))
    push!(lines, declareglobal("_start"))
    push!(lines, createlabel("_start"))
    for (x, ident) in enumerate(ast.main.arguments.values)
        push!(lines, movtoreg("r9b", Int(ident.value[1])))
        push!(lines, movtoreg("r10d", "tape", is_address = true))
        push!(lines, movtoreg("r11d", ((initial_position + x - 1)*BYTE_ADDRESS_MULTIPLIER)))
        push!(lines, addregs("r10d", "r11d"))
        push!(lines, movtodata("r10d", "r9b"))
    end
    push!(lines, movtoreg("r11d", initial_position*BYTE_ADDRESS_MULTIPLIER))
    push!(lines, movtoreg("r10d", "tape"; is_address = true))
    push!(lines, addregs("r10d", "r11d"))
    push!(lines, movtoreg("r9b", "r10d"))
    push!(lines, jump(ast.main.name.value))

    for machine in ast.machines.values
        lines = vcat(lines, generate(machine))
    end

    push!(lines, createlabel("_FAIL"))
    push!(lines, movtoreg("eax", 1))
    push!(lines, movtoreg("ebx", 1))
    push!(lines, interrupt("80h"))
    
    push!(lines, createlabel("_HALT"))
    push!(lines, movtoreg("eax", 1))
    push!(lines, movtoreg("ebx", 0))
    push!(lines, interrupt("80h"))
    return lines
end