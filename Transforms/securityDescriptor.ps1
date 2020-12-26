[CmdletBinding()]
param (
    [Parameter()]
    [Switch]
    $FullLoad
)

if($FullLoad)
{
}

$prop=[Ordered]@{
    BinaryInput=$true
    SupportedAttributes=@('msDS-AllowedToActOnBehalfOfOtherIdentity','ms-DS-GroupMSAMembership','ntSecurityDescriptor')
    OnLoad = $null
    OnSave = $null
}
$codeBlock = new-object PSCustomObject -property $prop
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
