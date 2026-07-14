#!/bin/sh

# This script is run on the emulator to run the tests

# Get list of all binaries in pwd for later iteration (only include binaries)
BINARIES=$(find . -maxdepth 1 -type f ! -name "*.so" ! -name "android_test_driver.sh")

TOTAL=0
PASS=0
SKIP=0
FAIL=0

# Run each binary, measure time and return value (PASS or FAIL). Print stdout and stderr only after a failure
for BINARY in $BINARIES; do
    TOTAL=$((TOTAL + 1))
    
    START_TIME=$(date +%s)
    # Busybox date does not support %N, so we can't get milliseconds this way
    #START_TIME_MS=$((START_TIME * 1000 + $(date +%N) / 1000000))
    
    OUTPUT=$("$BINARY" 2>&1)
    EXIT_CODE=$?
    
    END_TIME=$(date +%s)
    #END_TIME_MS=$((END_TIME * 1000 + $(date +%N) / 1000000))
    #ELAPSED_TIME=$((END_TIME_MS - START_TIME_MS))
    ELAPSED_TIME=$((END_TIME - START_TIME))
    
    BINARY_NAME=$(basename "$BINARY")
    
    if [ $EXIT_CODE -eq 0 ]; then
        PASS=$((PASS + 1))
        echo "PASSED ($EXIT_CODE): $BINARY_NAME (${ELAPSED_TIME}s)"
    elif [ $EXIT_CODE -eq 77 ]; then
        SKIP=$((SKIP + 1))
        echo "SKIPPED: $BINARY_NAME"
    else
        FAIL=$((FAIL + 1))
        echo "FAILED ($EXIT_CODE): $BINARY_NAME (${ELAPSED_TIME}s)"
        if [ -z "$OUTPUT" ]; then
            echo "No output written to stdout."
        else
            echo "Output:"
            echo "$OUTPUT"
        fi
    fi
done

if [ $TOTAL -eq 0 ]; then
    echo "No tests found. Exiting."
    exit 1
fi

PERCENTAGE=$(((PASS + SKIP) * 100 / TOTAL))
echo "$PERCENTAGE% Passed. Total: $TOTAL, Passed: $PASS, Skipped: $SKIP, Failed: $FAIL"
echo "Finished running tests. Exiting."

# Exit with corresponding return value
if [ $FAIL -eq 0 ]; then
    exit 0
else
    exit 1
fi
