[CmdletBinding()]
param (
    [Parameter()]
    [Switch]
    $FullLoad
)
#see https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-adts/f3adda9f-89e1-4340-a3f2-1f0a6249f1f8
$codeBlock= New-LdapAttributeTransformDefinition -SupportedAttributes @('userPassword')

$codeBlock.OnSave = { 
    param(
    [string[]]$Values
    )
    
    Process
    {
        foreach($Value in $Values)
        {
            ,"$value"
        }
    }
}
$codeBlock
