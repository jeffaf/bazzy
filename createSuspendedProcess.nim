import winim/lean
import strformat

proc createSuspendedProcess*(lpProcessName: string, dwProcessId: ptr DWORD, hProcess: ptr HANDLE, hThread: ptr HANDLE): bool =
    # Initialize required structures
    var
        wnDir: array[MAX_PATH, CHAR]
        fullPath: array[MAX_PATH, CHAR]
        si: STARTUPINFOA
        pi: PROCESS_INFORMATION

    # Zero initialize structures
    ZeroMemory(addr si, sizeof(STARTUPINFOA).int32)
    ZeroMemory(addr pi, sizeof(PROCESS_INFORMATION).int32)
    ZeroMemory(addr fullPath[0], sizeof(fullPath))

    # Set STARTUPINFO size
    si.cb = sizeof(STARTUPINFOA).DWORD

    # Get Windows directory path
    if GetEnvironmentVariableA("WINDIR", addr wnDir[0], MAX_PATH) == 0:
        echo fmt"[!] GetEnvironmentVariableA Failed With Error: {GetLastError()}"
        return false

    # Construct full path to target executable
    discard lstrcpyA(addr fullPath[0], addr wnDir[0])
    discard lstrcatA(addr fullPath[0], "\\System32\\")
    discard lstrcatA(addr fullPath[0], lpProcessName)

    let finalPath = cast[cstring](addr fullPath[0])
    let attrs = GetFileAttributesA(finalPath)
    if attrs == INVALID_FILE_ATTRIBUTES:
        echo fmt"[!] Target executable not found: {finalPath}"
        return false

    echo fmt"\n\t[i] Running: `{finalPath}` ..."

    # Setup security attributes
    var sa: SECURITY_ATTRIBUTES
    sa.nLength = sizeof(SECURITY_ATTRIBUTES).DWORD
    sa.lpSecurityDescriptor = NULL
    sa.bInheritHandle = TRUE

    # Create the process in suspended state
    if CreateProcessA(
        NULL,                   # No module name (use command line)
        finalPath,              # Command line
        addr sa,                # Process handle is inheritable
        addr sa,                # Thread handle is inheritable
        TRUE,                   # Set handle inheritance
        CREATE_SUSPENDED or     # Creation flags
        NORMAL_PRIORITY_CLASS,
        NULL,                   # Use parent's environment block
        NULL,                   # Use parent's starting directory
        addr si,                # Pointer to STARTUPINFO structure
        addr pi                 # Pointer to PROCESS_INFORMATION structure
    ) == 0:
        echo fmt"[!] CreateProcessA Failed with Error: {GetLastError()}"
        return false

    echo "[+] DONE"

    # Set output parameters
    dwProcessId[] = pi.dwProcessId
    hProcess[] = pi.hProcess
    hThread[] = pi.hThread

    # Verify handle validity
    result = dwProcessId[] != 0 and hProcess[] != 0 and hThread[] != 0

proc resumeThread*(threadHandle: HANDLE): bool =
    result = ResumeThread(threadHandle) != DWORD(-1)

proc terminateProcess*(processHandle: HANDLE, exitCode: UINT = 0): bool =
    let procId = GetProcessId(processHandle)
    if procId == 0:
        return false
    
    # Helper function to check process existence
    proc processExists(pid: DWORD): bool =
        let testHandle = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid)
        if testHandle != 0:
            CloseHandle(testHandle)
            result = true
        else:
            result = false
    
    # Multiple termination attempts with different approaches
    var terminated = false

    # Attempt 1: Original handle
    result = TerminateProcess(processHandle, exitCode) != 0
    if result:
        discard WaitForSingleObject(processHandle, 1000)
        terminated = not processExists(procId)
    
    # Attempt 2: Full access rights
    if not terminated:
        let hProcess1 = OpenProcess(PROCESS_ALL_ACCESS, FALSE, procId)
        if hProcess1 != 0:
            result = TerminateProcess(hProcess1, exitCode) != 0
            discard WaitForSingleObject(hProcess1, 1000)
            CloseHandle(hProcess1)
            terminated = not processExists(procId)
    
    # Attempt 3: Specific access rights
    if not terminated:
        let hProcess2 = OpenProcess(PROCESS_TERMINATE or PROCESS_QUERY_INFORMATION or PROCESS_VM_READ, FALSE, procId)
        if hProcess2 != 0:
            result = TerminateProcess(hProcess2, exitCode) != 0
            discard WaitForSingleObject(hProcess2, 1000)
            CloseHandle(hProcess2)
            terminated = not processExists(procId)
    
    # Attempt 4: Final try with PROCESS_TERMINATE only
    if not terminated:
        let hProcess3 = OpenProcess(PROCESS_TERMINATE, FALSE, procId)
        if hProcess3 != 0:
            result = TerminateProcess(hProcess3, exitCode) != 0
            CloseHandle(hProcess3)
            terminated = not processExists(procId)
    
    # Final verification
    Sleep(2000)  # Allow time for process cleanup
    if processExists(procId):
        echo "[!] Final check: Process is still running"
        result = false
    else:
        echo "[+] Final check: Process is terminated"
        result = true

when isMainModule:
    var
        processId: DWORD
        procHandle: HANDLE
        threadHandle: HANDLE

    # Create suspended notepad process
    let success = createSuspendedProcess(
        "notepad.exe",
        addr processId,
        addr procHandle,
        addr threadHandle
    )
    
    if success:
        echo fmt"""
Process Details:
---------------
PID: {processId}
Process Handle: {procHandle}
Thread Handle: {threadHandle}
"""

        # Allow user to examine suspended process
        echo "\n[*] Process is suspended. Press Enter to resume..."
        discard stdin.readLine()

        # Resume the process
        if resumeThread(threadHandle):
            echo "[+] Process resumed successfully"
        else:
            echo fmt"[!] Failed to resume process. Error: {GetLastError()}"

        # Wait for user input before termination attempt
        echo "\n[*] Press Enter to terminate the process..."
        discard stdin.readLine()

        if terminateProcess(procHandle):
            echo "[+] Process terminated successfully"
        else:
            echo fmt"[!] Failed to terminate process. Error: {GetLastError()}"

        # Cleanup handles
        CloseHandle(threadHandle)
        CloseHandle(procHandle)
    else:
        echo "Failed to create process"