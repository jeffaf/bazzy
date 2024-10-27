Here's the updated README.md that includes the new CLI features:

```markdown
# Bazzy
**Bazzy** is a Nim-based tool designed to inject shellcode into Windows processes. It can target either the `explorer.exe` process by default or inject into a specified process in a suspended state.

## Features
- Injects and executes shellcode in target processes
- Supports creating remote threads for executing injected code
- Command-line interface with multiple options:
  - Custom base64 encoded shellcode payload
  - Target process selection
  - Default injection into explorer.exe
- Process creation in suspended state for safer injection
- Support for both direct process injection and suspended process injection

## Requirements
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
   nim c -r bazzy.nim
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

# Use custom payload and inject into specific process
bazzy -p "your_base64_payload" -t "notepad.exe"

# Use default payload but inject into specific process
bazzy -t "notepad.exe"
```

### Command Line Options
- `-h, --help`: Show help information
- `-p, --payload <base64>`: Specify base64 encoded shellcode payload
- `-t, --target <process>`: Specify target process name (default: explorer.exe)

## Disclaimer
This project is intended solely for educational and research purposes. 

## Contributing
Feel free to open issues and submit pull requests if you'd like to contribute.

## Credits & Thanks
Inspired by the following projects:
- https://github.com/sh3d0ww01f/nim_shellloader/
- https://github.com/byt3bl33d3r/OffensiveNim
- https://maldevacademy.com
```
