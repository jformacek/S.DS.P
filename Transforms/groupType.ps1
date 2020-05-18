[CmdletBinding()]
param (
    [Parameter()]
    [Switch]
    $FullLoad
)
if($FullLoad)
{
# From [MS-SAMR]/2.2.1.11
# https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-samr/1f8d7ea1-fcc1-4833-839a-f94d67c08fcd
Add-Type @'
using System;
[Flags]
public enum GroupType
{
    Global = 0x00000002,
    Local = 0x00000004,
    Universal = 0x00000008,
    Security = unchecked((int)0x80000000)
}
'@
}

$prop=[Ordered]@{
    SupportedAttributes=@('groupType')
    OnLoad = $null
    OnSave = $null
}
$codeBlock = new-object PSCustomObject -property $prop
$codeBlock.OnLoad = { 
    param(
    [int[]]$Values
    )
    Process
    {
        [GroupType].GetEnumValues().ForEach({if(($Value -band $_) -eq $_) {"$_"}})
    }
}
$codeBlock.OnSave = { 
    param(
    [System.String[]]$Values
    )
    
    Process
    {
        $retVal = 0
        $Values.ForEach({ [GroupType]$val=$_; $retVal+=$val})
        $retVal
    }
}
$codeBlock
