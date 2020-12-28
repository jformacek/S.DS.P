
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
$codeBlock= New-LdapAttributeTransformDefinition -SupportedAttributes @('createTimestamp','dsCorePropagationData','modifyTimestamp','whenCreated','whenChanged','msExchWhenMailboxCreated')

$codeBlock.OnLoad = { 
    param(
    [string[]]$Values
    )
    Process
    {
        foreach($Value in $Values)
        {
            [DateTime]::ParseExact($value,'yyyyMMddHHmmss.fK',[System.Globalization.CultureInfo]::InvariantCulture,[System.Globalization.DateTimeStyles]::AssumeUniversal)
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

