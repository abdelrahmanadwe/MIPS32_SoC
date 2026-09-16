#!/bin/bash
if [ -z "$1" ]; then
    echo "Usage: ./run_test.sh <test_name>"
    echo "Available test names: test1, test2, test3, test4, test5, test6, test7, test8, test9, test10, instructions1"
    echo "Example: ./run_test.sh test2"
    exit 1
fi

vsim -c -do "do run.do $1 $2"
