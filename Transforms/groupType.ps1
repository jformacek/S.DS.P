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
public enum GroupType: uint
{
    Global = 0x00000002,
    Local = 0x00000004,
    Universal = 0x00000008,
    Security = 0x80000000
}
'@
}

$codeBlock= New-LdapAttributeTransformDefinition -SupportedAttributes @('groupType')

$codeBlock.OnLoad = { 
    param(
    [string[]]$Values
    )
    Process
    {
        [GroupType].GetEnumValues().ForEach({if(([UInt32]$Value -band $_) -eq $_) {"$_"}})
    }
}
$codeBlock.OnSave = { 
    param(
    [GroupType[]]$Values
    )
    
    Process
    {
        $retVal = 0
        $Values.ForEach({ $retVal+=$_})
        $retVal
    }
}
$codeBlock
