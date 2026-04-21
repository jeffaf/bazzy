# Bazzy

**Bazzy** is a Nim shellcode loader for Windows. It offers four execution modes: remote thread injection into `explorer.exe` (default), remote thread injection into a freshly spawned suspended process, Early Bird APC injection, and direct callback-based execution without injection.

## Features
- Multiple execution modes:
  - Remote thread injection into `explorer.exe` (default)
  - Suspended process creation and injection via `CreateRemoteThread`
  - Early Bird APC injection via `QueueUserAPC` against a suspended primary thread
  - Direct shellcode execution via `EnumSystemGeoID` callback (no injection)
- Accepts custom base64-encoded shellcode, with a baked-in x64 demo payload as fallback
- Suspended target selection from `%WINDIR%\System32`

## Requirements
- **Windows** (x64 for the default payload)
- **Nim**: [Nim Programming Language](https://nim-lang.org/)
- **Winim**: Windows API bindings for Nim
  ```bash
  nimble install winim
  ```

## Installation
```bash
git clone https://github.com/jeffaf/bazzy.git
cd bazzy
nim c bazzy.nim
```

## Usage
```bash
# Show help
bazzy -h

# Default: inject the baked-in payload into explorer.exe
bazzy

# Inject a custom payload into explorer.exe
bazzy -p "your_base64_payload"

# Spawn a suspended target and inject via CreateRemoteThread
bazzy -p "your_base64_payload" -t "notepad.exe"

# Early Bird APC injection (defaults to notepad.exe target)
bazzy -p "your_base64_payload" -a

# Early Bird APC injection into a specific suspended target
bazzy -p "your_base64_payload" -a -t "calc.exe"

# Execute shellcode directly in bazzy's own process (no injection)
bazzy -p "your_base64_payload" -e
```

The baked-in default payload is an x64 `msfvenom` reverse shell stub — replace it in `bazzy.nim` or pass your own via `-p` before using against any real target.

### Execution Modes
- **Default** (no flag): Injects into the running `explorer.exe` via `OpenProcess` + `VirtualAllocEx` + `WriteProcessMemory` + `CreateRemoteThread`
- **Suspended Target** (`-t`): Spawns `%WINDIR%\System32\<process>` with `CREATE_SUSPENDED`, injects via `CreateRemoteThread`, then resumes the primary thread
- **Early Bird APC** (`-a`): Spawns a suspended target, queues the shellcode as a user-mode APC on its primary thread via `QueueUserAPC`, then resumes. `NtTestAlert` fires during process initialization and runs the shellcode before most user-mode EDR hooks are installed. Defaults to `notepad.exe` if `-t` is omitted.
- **Direct Execution** (`-e`): Runs shellcode in bazzy's own process via `EnumSystemGeoID` callback — no injection

### Command Line Options
- `-h, --help`: Show help
- `-p, --payload <base64>`: Base64-encoded shellcode payload
- `-t, --target <process>`: Spawn `<process>` from `%WINDIR%\System32` as a suspended target
- `-e, --execute`: Execute shellcode directly (no injection)
- `-a, --apc`: Early Bird APC injection (uses `-t` target, defaults to `notepad.exe`)

## Disclaimer
For educational and authorized security research only. Use exclusively on systems you own or have explicit permission to test.

## Contributing
Issues and pull requests welcome.

## Credits
Inspired by:
- [sh3d0ww01f/nim_shellloader](https://github.com/sh3d0ww01f/nim_shellloader/)
- [byt3bl33d3r/OffensiveNim](https://github.com/byt3bl33d3r/OffensiveNim)
- [MalDev Academy](https://maldevacademy.com)
