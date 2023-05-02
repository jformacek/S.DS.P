[CmdletBinding()]
param (
    [Parameter()]
    [Switch]
    $FullLoad
)

if($FullLoad)
{
# From [MS-ADTS]/6.1.6.7.9
# https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-samr/1f8d7ea1-fcc1-4833-839a-f94d67c08fcd
Add-Type @'
using System;
[Flags]
public enum TrustAttributes: uint
{
    TRUST_ATTRIBUTE_NON_TRANSITIVE = 0x00000001,
    TRUST_ATTRIBUTE_UPLEVEL_ONLY = 0x00000002,
    TRUST_ATTRIBUTE_QUARANTINED_DOMAIN = 0x00000004,
    TRUST_ATTRIBUTE_FOREST_TRANSITIVE = 0x00000008,
    TRUST_ATTRIBUTE_CROSS_ORGANIZATION = 0x00000010,
    TRUST_ATTRIBUTE_WITHIN_FOREST = 0x00000020,
    TRUST_ATTRIBUTE_TREAT_AS_EXTERNAL = 0x00000040,
    TRUST_ATTRIBUTE_USES_RC4_ENCRYPTION = 0x00000040,
    TRUST_ATTRIBUTE_CROSS_ORGANIZATION_NO_TGT_DELEGATION = 0x00000200,
    TRUST_ATTRIBUTE_CROSS_ORGANIZATION_ENABLE_TGT_DELEGATION = 0x00000800,
    TRUST_ATTRIBUTE_PIM_TRUST = 0x00000400
}
'@
}

#add attributes that can be processed by this transform
$SupportedAttributes = @('trustAttributes')

# This is mandatory definition of transform that is expected by transform architecture
$codeBlock = New-LdapAttributeTransformDefinition -SupportedAttributes $SupportedAttributes
$codeBlock.OnLoad = { 
    param(
    [string[]]$Values
    )
    Process
    {
        foreach($Value in $Values)
        {
            [TrustAttributes].GetEnumValues().ForEach({if(($Value -band $_) -eq $_) {$_}})
        }
    }
}
$codeBlock.OnSave = { 
    param(
    [TrustAttributes[]]$Values
    )
    
    Process
    {
        $retVal = 0
        $Values.ForEach({ $retVal = $retVal -bor $_})
        [BitConverter]::ToInt32([BitConverter]::GetBytes($retVal),0)
    }
}
$codeBlock
