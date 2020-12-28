[CmdletBinding()]
param (
    [Parameter()]
    [Switch]
    $FullLoad
)

if($FullLoad)
{
# From [MS-ADTS]/2.2.9
# https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-adts/7c1cdf82-1ecc-4834-827e-d26ff95fb207
Add-Type @'
using System;
[Flags]
public enum SearchFlags
{
    ATTINDEX =          0x1,
    PDNTATTINDEX =      0x2,
    ANR =               0x4,
    PRESERVEONDELETE =  0x8,
    COPY =              0x10,
    TUPLEINDEX =        0x20,
    SUBTREEATTINDEX =   0x40,
    CONFIDENTIAL =      0x80,
    NEVERVALUEAUDIT =   0x100,
    RODCFilteredAttribute = 0x200,
    EXTENDEDLINKTRACKING =  0x400,
    BASEONLY =              0x800,
    PARTITIONSECRET =       0x1000,
}
'@
}
$codeBlock= New-LdapAttributeTransformDefinition -SupportedAttributes @('searchFlags')

$codeBlock.OnLoad = { 
    param(
    [string[]]$Values
    )
    Process
    {
        foreach($Value in $Values)
        {
            [SearchFlags].GetEnumValues().ForEach({if((([int32]$Value) -band $_) -eq $_) {"$_"}})
        }
    }
}
$codeBlock.OnSave = { 
    param(
    [SearchFlags[]]$Values
    )
    
    Process
    {
        $retVal = 0
        $Values.ForEach({ $retVal+=$_})
        $retVal
 
    }
}
$codeBlock

