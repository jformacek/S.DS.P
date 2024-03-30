[CmdletBinding()]
param (
    [Parameter()]
    [Switch]
    $FullLoad
)
$codeBlock= New-LdapAttributeTransformDefinition -SupportedAttributes @('unicodePwd') -BinaryInput

$codeBlock.OnSave = { 
    param(
    [string[]]$Values
    )
    
    Process
    {
        foreach($Value in $Values)
        {
            ,([System.Text.Encoding]::Unicode.GetBytes("`"$Value`"") -as [byte[]])                    }
    }
}
$codeBlock
