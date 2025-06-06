# CBStorm
CBStorm scans web application and finds live subdomains using subfinder and httpx, scans all subdomains using nmap, performs directory traversal and saves all data. It resumes most steps based on file presence, but it's not foolproof.It is intended for bug bounty hunters, penetration testers, and network reconnaissance.

## Features

- Uses `subfinder` to find subdomains from input domains or files.
- Filters live domains using `httpx`.
- Cleans and prepares a list of domains by removing `https://` prefix.
- Performs detailed Nmap scans on live subdomains.
- Automatically skips domains that were already scanned.
- Supports excluding specific domains from scanning.
- Allows configurable parallel jobs for Nmap.

## Prerequisites

Ensure the following tools are installed and available in your PATH:

- subfinder
- httpx
- nmap
- parallel

You can install them using package managers like `apt`, `brew`, or download from official repositories.

## Usage

```bash
./CBStorm.sh [-o output_dir] [-j jobs] [-e exclude_file] <target_file_or_domain1> [<target_file_or_domain2> ...]
```
## Options

    `-o, --output <dir>`: Output directory to store results (default is current directory).

    `-j, --jobs <num>`: Number of parallel Nmap jobs (default is 4).

    `-e, --exclude <file>`: File containing domains to exclude from Nmap scanning.

    `-h, --help`: Show usage instructions.

## Examples

```bash
./CBStorm.sh -o ./results example.com
./CBStorm.sh -o ./results -j 10 -e exclude.txt scope.txt more_targets.txt
```

## Output Structure

Each target produces the following output files in the specified directory:

    `subfinder_<target>.all`: All discovered subdomains.

    `subfinder_<target>.live`: Live domains (based on HTTP response).

    `subfinder_<target>.clean`: Cleaned domain list (no https://).

    `<target>.nmap/*.nmap`: Nmap scan results for each live domain.

## Notes

    Domains already scanned or listed in the exclude file will be skipped automatically.

    If any step has already completed (with output file present and non-empty), it will not be repeated.

    Temporary files are cleaned up after use.

## License

This script is provided as-is for educational and research purposes.
