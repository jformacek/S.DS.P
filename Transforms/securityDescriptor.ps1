[CmdletBinding()]
param (
    [Parameter()]
    [Switch]
    $FullLoad
)

if($FullLoad)
{
}
$codeBlock= New-LdapAttributeTransformDefinition -SupportedAttributes @('msDS-AllowedToActOnBehalfOfOtherIdentity','msDS-GroupMSAMembership','ntSecurityDescriptor', 'msExchMailboxSecurityDescriptor') -BinaryInput

$codeBlock.OnLoad = { 
    param(
    [byte[][]]$Values
    )
    Process
    {
        foreach($Value in $Values)
        {
            $dacl = new-object System.DirectoryServices.ActiveDirectorySecurity
            $dacl.SetSecurityDescriptorBinaryForm($value)
            $dacl
        }
    }
}
$codeBlock.OnSave = { 
    param(
    [System.DirectoryServices.ActiveDirectorySecurity[]]$Values
    )
    
    Process
    {
        foreach($Value in $Values)
        {
            ,($Value.GetSecurityDescriptorBinaryForm())
        }
    }
}
$codeBlock
