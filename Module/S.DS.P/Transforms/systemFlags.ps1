[CmdletBinding()]
param (
    [Parameter()]
    [Switch]
    $FullLoad
)

if($FullLoad)
{
# From [MS-ADTS]/2.2.10
# https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-adts/1e38247d-8234-4273-9de3-bbf313548631
Add-Type @'
using System;
[Flags]
public enum SystemFlags : uint
{
    DISALLOW_DELETE = 0x80000000,
    CONFIG_ALLOW_RENAME = 0x40000000,
    CONFIG_ALLOW_MOVE = 0x20000000,
    CONFIG_ALLOW_LIMITED_MOVE = 0x10000000,
    DOMAIN_DISALLOW_RENAME = 0x8000000,
    DOMAIN_DISALLOW_MOVE = 0x4000000,
    DISALLOW_MOVE_ON_DELETE = 0x2000000,
    ATTR_IS_RDN = 0x20,
    SCHEMA_BASE_OBJECT = 0x10,
    ATTR_IS_OPERATIONAL = 0x8,
    ATTR_IS_CONSTRUCTED = 0x4,
    PARTIAL_SET_MEMBER = 0x2,
    NOT_REPLICATED = 0x1
}
'@
}
$codeBlock= New-LdapAttributeTransformDefinition -SupportedAttributes @('systemFlags')
$codeBlock.OnLoad = { 
    param(
    [string[]]$Values
    )
    Process
    {
        foreach($Value in $Values)
        {
            [SystemFlags].GetEnumValues().ForEach({if(($Value -band $_) -eq $_) {$_}})
        }
    }
}
$codeBlock.OnSave = { 
    param(
    [SystemFlags[]]$Values
    )
    
    Process
    {
        $retVal = 0
        $Values.ForEach({ $retVal = $retVal -bor $_})
        [BitConverter]::ToInt32([BitConverter]::GetBytes($retVal),0)
    }
}
$codeBlock

