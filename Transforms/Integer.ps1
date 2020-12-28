
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

#add attributes that can be used with this transform
$SupportedAttributes = @('codePage','countryCode','logonCount','msDS-Approx-Immed-Subordinates','ms-DS-KeyVersionNumber','ms-DS-ManagedPasswordInterval')

# This is mandatory definition of transform that is expected by transform architecture
$codeBlock= New-LdapAttributeTransformDefinition -SupportedAttributes $SupportedAttributes

$codeBlock.OnLoad = { 
    param(
    [string[]]$Values
    )
    Process
    {
        foreach($Value in $Values)
        {
            [int]$Value
        }
    }
}
$codeBlock.OnSave = { 
    param(
    [int[]]$Values
    )
    
    Process
    {
        foreach($Value in $Values)
        {
            "$Value"
        }
    }
}
$codeBlock

