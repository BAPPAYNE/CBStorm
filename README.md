# CBStorm

CBStorm scans web applications and finds live subdomains using `subfinder` and `httpx`, scans them with `nmap`, performs directory traversal, and saves all data. It resumes most steps based on file presence but is not fully fault-tolerant. It is intended for bug bounty hunters, penetration testers, and network reconnaissance.

## Features

- Uses `subfinder` to discover subdomains from input domains or files.
- Filters live domains using `httpx`.
- Cleans the list by removing `https://` prefixes.
- Performs detailed Nmap scans with scripts and version detection.
- Automatically skips already scanned or excluded domains.
- Supports parallel Nmap jobs.
- Saves all output in a structured format for later analysis.

## Prerequisites

Ensure the following tools are installed and available in your system PATH:

- `subfinder`
- `httpx`
- `nmap`
- `parallel`

Install using `apt`, `brew`, or their respective official sources.

## Usage

```bash
./CBStorm.sh [-o output_dir] [-j jobs] [-e exclude_file] <target_file_or_domain1> [<target_file_or_domain2> ...]
```

## Options

- `-o, --output <dir>`  
  Output directory to store results (default: current directory)

- `-j, --jobs <num>`  
  Number of parallel Nmap jobs (default: 4)

- `-e, --exclude <file>`  
  File containing domains to exclude from Nmap scanning

- `-h, --help`  
  Show usage instructions

## Examples

```bash
./CBStorm.sh -o ./results example.com
./CBStorm.sh -o ./results -j 10 -e exclude.txt scope.txt more_targets.txt
```

## Output Structure

For each target, CBStorm generates the following files in the output directory:

- `subfinder_<target>.all` – All discovered subdomains  
- `subfinder_<target>.live` – Live domains detected by `httpx`  
- `subfinder_<target>.clean` – Live domains with `https://` prefix removed  
- `<target>.nmap/*.nmap` – Nmap results for each live domain

## Notes

- If a file already exists and is non-empty, the step is skipped.
- Domains in the exclude file are not scanned.
- Temporary files used during scanning are deleted afterward.

## License

This script is provided as-is for educational and research purposes.
