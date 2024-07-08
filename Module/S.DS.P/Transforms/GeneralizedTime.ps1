
[CmdletBinding()]
param (
    [Parameter()]
    [Switch]
    $FullLoad
)

if($FullLoad)
{
# Add any types that are used by transforms
# CSharp types added via Add-Type are supported
}
$codeBlock= New-LdapAttributeTransformDefinition -SupportedAttributes @('createTimestamp','dsCorePropagationData','modifyTimestamp','whenCreated','whenChanged','msExchWhenMailboxCreated','expirationTime', 'ms-DS-local-Effective-Recycle-Time')

$codeBlock.OnLoad = { 
    param(
    [string[]]$Values
    )
    Process
    {
        foreach($Value in $Values)
        {
            if($value.Length -eq 13)
            {
                #omSyntax 23 - see https://learn.microsoft.com/en-us/windows/win32/adschema/s-string-utc-time 
                [DateTime]::ParseExact($value,'yyMMddHHmmssZ',[System.Globalization.CultureInfo]::InvariantCulture,[System.Globalization.DateTimeStyles]::AssumeUniversal)
                continue;
            }
            if($value.length -ge 17)
            {
                #omSyntax 24 - see https://learn.microsoft.com/en-us/windows/win32/adschema/s-string-generalized-time
                [DateTime]::ParseExact($value,'yyyyMMddHHmmss.fK',[System.Globalization.CultureInfo]::InvariantCulture,[System.Globalization.DateTimeStyles]::AssumeUniversal)
                continue;
            }
        }
    }
}

$codeBlock.OnSave = { 
    param(
    [DateTime[]]$Values
    )
    
    Process
    {
        foreach($Value in $Values)
        {
            $value.ToUniversalTime().ToString('yyyyMMddHHmmss.0Z')
        }
    }
}

$codeBlock

