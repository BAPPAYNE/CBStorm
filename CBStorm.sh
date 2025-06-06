#!/bin/bash

# Display usage instructions
usage() {
    echo "Usage: $0 [-o output_dir] [-j jobs] [-e exclude_file] <target_file_or_domain1> [<target_file_or_domain2> ...]"
    echo "Options:"
    echo "  -o, --output <dir>      Directory to store output files"
    echo "  -j, --jobs <num>        Number of parallel Nmap jobs (default: 4)"
    echo "  -e, --exclude <file>    File listing domains to skip from Nmap scanning"
    echo "Example:"
    echo "  $0 -o ./results -j 8 -e exclude.txt example.com scopes.txt"
    exit 1
}

# Basic domain validation (not bulletproof, but enough)
is_valid_domain() {
    local domain="$1"
    [[ "$domain" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*[a-zA-Z0-9]$ ]] && 
    [[ ! "$domain" =~ ^- ]] && 
    [[ ! "$domain" =~ : ]] && return 0 || return 1
}

# Make sure required tools are installed
for tool in subfinder httpx nmap parallel; do
    command -v $tool >/dev/null 2>&1 || { echo "Error: $tool is not installed."; exit 1; }
done

# Defaults
output_dir="."
parallel_jobs=4
exclude_file=""
targets=()

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -o|--output)
            [ -n "$2" ] || { echo "Error: Missing output directory."; usage; }
            output_dir="$2"
            shift 2
            ;;
        -j|--jobs)
            [[ "$2" =~ ^[0-9]+$ ]] || { echo "Error: Jobs must be a number."; usage; }
            parallel_jobs="$2"
            shift 2
            ;;
        -e|--exclude)
            [ -f "$2" ] || { echo "Error: Exclude file not found."; usage; }
            exclude_file="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            targets+=("$1")
            shift
            ;;
    esac
done

# Require at least one target
[ ${#targets[@]} -eq 0 ] && { echo "Error: No targets provided."; usage; }

# Make sure output directory exists
mkdir -p "$output_dir" || { echo "Error: Couldn't create output directory."; exit 1; }

# Process each target
for target in "${targets[@]}"; do
    if [ -f "$target" ]; then
        target_file="$target"
        base_name=$(basename "$target" | cut -d. -f1)
        echo "Loaded target file: $target_file"
    else
        if ! is_valid_domain "$target"; then
            echo "Warning: '$target' doesn't look like a valid domain. Skipping..."
            continue
        fi
        base_name=$(echo "$target" | tr -C 'a-zA-Z0-9' '_' | sed 's/__*/_/g')
        target_file=$(mktemp)
        echo "$target" > "$target_file"
        echo "Processing domain: $target"
    fi

    # Run subfinder
    sub_out="$output_dir/subfinder_${base_name}.all"
    if [ -s "$sub_out" ]; then
        echo "Subfinder output exists: $sub_out. Skipping subfinder."
    else
        echo "Running subfinder on $target_file..."
        subfinder -dL "$target_file" -o "$sub_out" -v || {
            echo "Subfinder failed. Skipping $target."
            [ ! -f "$target" ] && rm -f "$target_file"
            continue
        }

        [ -s "$sub_out" ] || {
            echo "No subdomains found for $target. Skipping..."
            [ ! -f "$target" ] && rm -f "$target_file"
            continue
        }
    fi

    # Run httpx
    httpx_out="$output_dir/subfinder_${base_name}.live"
    if [ -s "$httpx_out" ]; then
        echo "Httpx output exists: $httpx_out. Skipping httpx."
    else
        echo "Running httpx to check live subdomains..."
        httpx -l "$sub_out" -mc 100,300,401,403,501 -v -o "$httpx_out" || {
            echo "Httpx failed. Skipping $target."
            [ ! -f "$target" ] && rm -f "$target_file"
            continue
        }

        [ -s "$httpx_out" ] || {
            echo "No live subdomains found. Skipping..."
            [ ! -f "$target" ] && rm -f "$target_file"
            continue
        }
    fi

    # Strip https:// for clean Nmap input
    clean_out="$output_dir/subfinder_${base_name}.clean"
    if [ -s "$clean_out" ]; then
        echo "Cleaned output exists: $clean_out. Skipping cleanup."
    else
        echo "Removing 'https://' from live domains..."
        sed 's|https://||g' "$httpx_out" > "$clean_out"
    fi

    # Prepare Nmap output directory
    nmap_dir="$output_dir/${base_name}.nmap"
    mkdir -p "$nmap_dir"

    # Prepare temp list for new domains to scan
    temp_list=$(mktemp)
    while IFS= read -r domain; do
        [ -z "$domain" ] && continue
        nmap_file="$nmap_dir/${domain}.nmap"
        [ -s "$nmap_file" ] && continue
        if [ -n "$exclude_file" ] && grep -Fxq "$domain" "$exclude_file"; then
            echo "Skipping $domain (in exclude list)"
            continue
        fi
        echo "$domain" >> "$temp_list"
    done < "$clean_out"

    # Run Nmap scans
    if [ -s "$temp_list" ]; then
        echo "Running Nmap scans on new targets (jobs: $parallel_jobs)..."
        cat "$temp_list" | parallel -j "$parallel_jobs" --halt never \
            "nmap {} -sS -sC -A --script=vuln -oN '$nmap_dir/{}.nmap' && echo 'Finished: {}' || echo 'Nmap failed: {}'" 2>/dev/null
    else
        echo "No new domains left to scan."
    fi

    rm -f "$temp_list"
    [ ! -f "$target" ] && rm -f "$target_file"

    echo "Done with $target"
    echo "Files saved in: $output_dir"
    echo "  - All subdomains: subfinder_${base_name}.all"
    echo "  - Live domains:   subfinder_${base_name}.live"
    echo "  - Cleaned:        subfinder_${base_name}.clean"
    echo "  - Nmap results:   ${base_name}.nmap/"
    echo "--------------------------------------------"
done

echo "All targets processed."
