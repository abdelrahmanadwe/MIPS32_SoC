# run.do
# Check if argument is provided
if {$argc < 1} {
    echo "Error: Please specify the test name (e.g. test1, test2, test3, test4, test5, test6, test7, test8, test9, instructions1)"
    quit -f
}

set test_name [string tolower $1]

# Map simple test names to their actual file paths
set mem_file ""
if {$test_name == "test1"} {
    set mem_file "Tests/test1/Test1.mem"
} elseif {$test_name == "test2"} {
    set mem_file "Tests/test2/Test2.mem"
} elseif {$test_name == "test3"} {
    set mem_file "Tests/test3/Test3_v3.mem"
} elseif {$test_name == "test4"} {
    set mem_file "Tests/test4/Test4_v2.mem"
} elseif {$test_name == "test5"} {
    set mem_file "Tests/test5/Test5.mem"
} elseif {$test_name == "test6"} {
    set mem_file "Tests/test6/Test6_mul_div_v2.mem"
} elseif {$test_name == "test7"} {
    set mem_file "Tests/test7/Test7_BP.mem"
} elseif {$test_name == "test8"} {
    set mem_file "Tests/test8/Test8_Exception.inst.mem"
} elseif {$test_name == "test9"} {
    set mem_file "Tests/test9/Test9_Soc.mem"
} elseif {$test_name == "test10"} {
    set mem_file "Tests/test10/Test10_MemOps.mem"
} elseif {$test_name == "instructions1"} {
    set mem_file "Tests/instructions1/instructions1.mem"
} else {
    # Fallback: assume the argument is a path or name
    set mem_file $test_name
}

echo "Running test: $test_name using $mem_file"

# Compile the design
vlog rtl/*.v rtl/*.sv tb/*.v

set top_tb "Pipelined_MIPS_Microprocessor_tb"
if {$argc >= 2} {
    set top_tb $2
}

# Start the simulation with the dynamic memory file plusarg
vsim -c -voptargs="+acc" $top_tb +MEM_FILE=$mem_file

# Run simulation to completion
run -all

# Exit
quit -f
