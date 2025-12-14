#!/bin/bash

# Save the current directory
ORIGINAL_DIR=$(pwd)

# Change to ~/Agent directory
cd ~/Agent || exit 1

# Run cursor-agent --resume
cursor-agent --resume

# Save the exit code
EXIT_CODE=$?

# Return to the original directory
cd "$ORIGINAL_DIR" || exit 1

# Exit with the same code as cursor-agent
exit $EXIT_CODE
