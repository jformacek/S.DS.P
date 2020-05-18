[CmdletBinding()]
param (
    [Parameter()]
    [Switch]
    $FullLoad
)

if($FullLoad)
{
Add-Type @'
using System;
[Flags]
public enum EncryptionTypes
{
    DES_CBC_CRC = 0x1,
    DES_CBC_MD5 = 0x2,
    RC4_HMAC_MD5 = 0x4,
    AES128_CTS_HMAC_SHA1_96 = 0x8,
    AES256_CTS_HMAC_SHA1_96 = 0x10
}
'@
}

$prop=[Ordered]@{
    SupportedAttributes=@('msDS-SupportedEncryptionTypes')
    OnLoad = $null
    OnSave = $null
}
$codeBlock = new-object PSCustomObject -property $prop
$codeBlock.OnLoad = { 
    param(
    [object[]]$Values
    )
    Process
    {
        foreach($Value in $Values)
        {
            [EncryptionTypes].GetEnumValues().ForEach({if(($Value -band $_) -eq $_) {"$_"}})
        }
    }
}
$codeBlock.OnSave = { 
    param(
    [object[]]$Values
    )
    
    Process
    {
        $retVal = 0
        $Values.ForEach({ [EncryptionTypes]$val=$_; $retVal+=$val})
        $retVal
    }
}
$codeBlock
