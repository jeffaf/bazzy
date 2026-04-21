
# Bazzy
**Bazzy** is a tool designed to inject shellcode into Windows processes or execute it directly. It can target either the `explorer.exe` process by default, inject into a newly spawned suspended process, or execute shellcode directly without process injection.

## Features
- Multiple execution modes:
  - Direct shellcode execution (callback-based)
  - Remote thread injection into explorer.exe
  - Suspended process creation and injection via `CreateRemoteThread`
- Command-line interface with multiple options:
  - Custom base64 encoded shellcode payload
  - Suspended target process selection from `%WINDIR%\System32`
  - Direct shellcode execution mode

## Requirements
- **Windows**: Bazzy uses Windows APIs via Winim and is intended to run on Windows.
- **Nim**: [Nim Programming Language](https://nim-lang.org/)
- **Winim Library**: Provides Nim bindings for the Windows API. Install it using:
  ```bash
  nimble install winim
  ```

## Installation
1. **Clone the Repository**:
   ```bash
   git clone https://github.com/jeffaf/bazzy.git
   cd bazzy
   ```
2. **Install Dependencies**:
   Ensure you have the `winim` package installed:
   ```bash
   nimble install winim
   ```
3. **Build the Project**:
   ```bash
   nim c bazzy.nim
   ```

## Usage
Bazzy can be used in several ways:

```bash
# Show help and available options
bazzy -h

# Use default payload and inject into explorer.exe
bazzy

# Use custom payload and inject into explorer.exe
bazzy -p "your_base64_payload"

# Use custom payload and inject into a suspended process
bazzy -p "your_base64_payload" -t "notepad.exe"

# Execute shellcode directly without process injection
bazzy -p "your_base64_payload" -e

# Use default payload but inject into newly spawned suspended process
bazzy -t "notepad.exe"
```

### Execution Modes
- **Direct Execution** (`-e`): Executes shellcode in the current process via `EnumSystemGeoID` callback
- **Targeted Injection** (`-t`): Creates a suspended process in `%WINDIR%\System32\` and injects via `CreateRemoteThread`
- **Default Injection**: Injects into the running `explorer.exe` process via `CreateRemoteThread`

### Command Line Options
- `-h, --help`: Show help information
- `-p, --payload <base64>`: Specify base64 encoded shellcode payload
- `-t, --target <process>`: Specify target process name (spawned from `System32`)
- `-e, --execute`: Execute shellcode directly without process injection

## Disclaimer
This project is intended solely for educational and research purposes.

## Contributing
Feel free to open issues and submit pull requests if you'd like to contribute.

## Credits & Thanks
Inspired by the following projects:
- https://github.com/sh3d0ww01f/nim_shellloader/
- https://github.com/byt3bl33d3r/OffensiveNim
- https://maldevacademy.com
