#!/bin/bash

# Script Name: detect_cores.sh
# Description: Identifies efficiency cores (E-cores) and performance cores (P-cores) using lscpu --json output.
# Requirements: lscpu, jq

# Check if 'jq' is installed
if ! command -v jq &> /dev/null; then
    echo "Error: 'jq' is required but not installed."
    echo "Install 'jq' using your package manager, e.g., 'sudo apt install jq'"
    exit 1
fi

# Execute lscpu with the --json option and store the output
lscpu_output=$(lscpu -e=CPU,NODE,SOCKET,CORE,MAXMHZ -J)

# Process the JSON output using 'jq'
parsed_output=$(echo "$lscpu_output" | jq '
    # Group CPUs by their CORE numbers
    .cpus | group_by(.core) |
    # Map each group to an object containing core details
    map({
        core: .[0].core | tonumber,
        cpus: [.[].cpu | tonumber],
        max_mhz: (.[0]["max mhz"] | if . == null or . == "" then null else (. | tonumber) end)
    }) |
    # Separate into E-cores and P-cores based on the number of CPUs per core
    {
        "E-cores": map(select(.cpus | length == 1)),
        "P-cores": map(select(.cpus | length > 1))
    }
')

# Output the result in a formatted JSON
echo "$parsed_output" | jq .
