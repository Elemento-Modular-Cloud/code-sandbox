#!/bin/bash

# Script Name: detect_cores.sh
# Description: Identifies efficiency cores (E-cores) and performance cores (P-cores) using lscpu.
# Requirements: lscpu, jq (optional, only if --json output is desired)

# Function to display usage information
usage() {
    echo "Usage: $0 [--json]"
    echo "Options:"
    echo "  --json    Output the result in JSON format."
    exit 1
}

# Parse command-line arguments
OUTPUT_JSON=false
if [[ "$1" == "--json" ]]; then
    OUTPUT_JSON=true
    shift
elif [[ "$1" != "" ]]; then
    usage
fi

# Check if 'lscpu' supports '--json' option
if lscpu --help | grep -q '\--json'; then
    LSCU_HAS_JSON=true
else
    LSCU_HAS_JSON=false
fi

# If JSON output is requested but 'jq' is not installed, exit with an error
if $OUTPUT_JSON && ! command -v jq &> /dev/null; then
    echo "Error: 'jq' is required for JSON output but is not installed."
    echo "Install 'jq' using your package manager, e.g., 'sudo apt install jq'"
    exit 1
fi

# Function to process lscpu output with --json option
process_lscpu_json() {
    # Execute lscpu with the --json option
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

    # Output the result
    if $OUTPUT_JSON; then
        echo "$parsed_output" | jq .
    else
        echo "Efficiency Cores (E-cores):"
        echo "$parsed_output" | jq -r '.["E-cores"][] | "Core \(.core): CPUs \(.cpus | @sh), Max MHz: \(.max_mhz)"'
        echo
        echo "Performance Cores (P-cores):"
        echo "$parsed_output" | jq -r '.["P-cores"][] | "Core \(.core): CPUs \(.cpus | @sh), Max MHz: \(.max_mhz)"'
    fi
}

# Function to process lscpu output without --json option
process_lscpu_text() {
    # Execute lscpu without the --json option
    lscpu_output=$(lscpu -e=CPU,NODE,SOCKET,CORE,MAXMHZ)

    # Read the output into an array, skipping the header
    mapfile -t lines < <(echo "$lscpu_output" | tail -n +2)

    declare -A core_map
    declare -A core_freq

    # Process each line
    for line in "${lines[@]}"; do
        read -r cpu node socket core max_mhz <<< "$line"

        # Remove any leading or trailing whitespace
        core="${core//[[:blank:]]/}"
        cpu="${cpu//[[:blank:]]/}"
        max_mhz="${max_mhz//[[:blank:]]/}"

        # Append CPU to the core's CPU list
        core_map["$core"]+="$cpu "

        # Store the max MHz for the core
        if [[ -z "${core_freq[$core]}" && "$max_mhz" != "-" ]]; then
            core_freq["$core"]="$max_mhz"
        fi
    done

    # Separate cores into E-cores and P-cores
    e_cores=()
    p_cores=()
    for core in "${!core_map[@]}"; do
        # Get CPUs associated with the core
        cpus=(${core_map[$core]})
        max_mhz="${core_freq[$core]:-null}"

        # Create core info string
        core_info="Core $core: CPUs (${cpus[*]}), Max MHz: $max_mhz"

        if [[ ${#cpus[@]} -eq 1 ]]; then
            e_cores+=("$core_info")
        else
            p_cores+=("$core_info")
        fi
    done

    # Output the result
    if $OUTPUT_JSON; then
        # Construct JSON output
        json_output=$(jq -n --argjson e_cores "$(printf '%s\n' "${e_cores[@]}" | jq -R . | jq -s .)" \
                           --argjson p_cores "$(printf '%s\n' "${p_cores[@]}" | jq -R . | jq -s .)" \
                           '{ "E-cores": $e_cores, "P-cores": $p_cores }')
        echo "$json_output" | jq .
    else
        echo "Efficiency Cores (E-cores):"
        printf '%s\n' "${e_cores[@]}"
        echo
        echo "Performance Cores (P-cores):"
        printf '%s\n' "${p_cores[@]}"
    fi
}

# Main logic
if $LSCU_HAS_JSON; then
    process_lscpu_json
else
    process_lscpu_text
fi
