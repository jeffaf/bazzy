# Helper tool to clean and validate base64 strings for Windows usage, run independently from bazzy. 
import os, base64, strutils, parseopt

proc cleanBase64(input: string): string =
  # Remove quotes, newlines, and spaces
  result = input.multiReplace({
    "'": "",
    "\"": "",
    "\n": "",
    "\r": "",
    " ": ""
  })

proc validateBase64(b64str: string): bool =
  try:
    # Check padding
    let padding = b64str.len mod 4
    let paddedStr = if padding > 0: b64str & repeat('=', 4 - padding)
                   else: b64str
    
    # Try decode
    discard decode(paddedStr)
    result = true
  except:
    result = false

proc processFile(filepath: string): string =
  try:
    result = cleanBase64(readFile(filepath))
  except IOError:
    echo "Error: Could not read file: ", filepath
    quit(1)

proc showHelp() =
  echo """
Base64 Helper - Clean and validate base64 shellcode for Windows usage

Usage:
  b64_helper [options]

Options:
  -h, --help            Show this help message
  -f, --file <path>     Input file containing base64 string
  -s, --string <base64> Base64 string directly
  -o, --output <path>   Output file (optional)

Examples:
  b64_helper -f shellcode.b64 -o clean.txt
  b64_helper -s '/EiD5PDow...' -o clean.txt
  b64_helper -s '/EiD5PDow...'
"""
  quit(0)

proc main() =
  var 
    inputStr = ""
    outputFile = ""
    hasInput = false
    p = initOptParser()
  
  while true:
    p.next()
    case p.kind
    of cmdEnd: break
    of cmdShortOption, cmdLongOption:
      case p.key.toLowerAscii()
      of "help", "h":
        showHelp()
      of "file", "f":
        p.next()  # Move to the value
        if p.kind == cmdArgument:  # Make sure we have a value
          let filepath = p.key
          if fileExists(filepath):
            inputStr = processFile(filepath)
            hasInput = true
          else:
            echo "Error: File not found: ", filepath
            quit(1)
      of "string", "s":
        p.next()  # Move to the value
        if p.kind == cmdArgument:  # Make sure we have a value
          inputStr = p.key
          hasInput = true
      of "output", "o":
        p.next()  # Move to the value
        if p.kind == cmdArgument:  # Make sure we have a value
          outputFile = p.key
      else:
        echo "Unknown option: ", p.key
        showHelp()
    of cmdArgument:
      echo "Unexpected argument: ", p.key
      showHelp()

  if not hasInput:
    echo "Error: No input provided"
    showHelp()

  # Clean and validate the base64
  let cleanedStr = cleanBase64(inputStr)
  
  if not validateBase64(cleanedStr):
    echo "Error: Invalid base64 string after cleaning"
    quit(1)

  # Output handling
  if outputFile != "":
    try:
      writeFile(outputFile, cleanedStr)
      echo "Cleaned base64 written to ", outputFile
    except IOError:
      echo "Error: Could not write to file: ", outputFile
      quit(1)
  else:
    echo "\nCleaned base64 (ready for windows):"
    echo "-".repeat(50)
    echo cleanedStr
    echo "-".repeat(50)

when isMainModule:
  main()