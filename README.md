

---

# Bazzy

**Bazzy** is a Nim-based tool designed to inject shellcode into the Windows `explorer.exe` process or just execute it.  

## Features

- Injects and executes shellcode in the target process.
- Supports creating remote threads for executing injected code.

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

## Disclaimer

This project is intended solely for educational and research purposes. 


## Contributing

Feel free to open issues and submit pull requests if you'd like to contribute.

