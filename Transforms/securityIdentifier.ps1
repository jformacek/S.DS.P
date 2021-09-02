[CmdletBinding()]
param (
    [Parameter()]
    [Switch]
    $FullLoad
)
$codeBlock= New-LdapAttributeTransformDefinition -SupportedAttributes @('objectSid','tokenGroups','tokenGroupsGlobalAndUniversal','tokenGroupsNoGCAcceptable','sidHistory') -BinaryInput

$codeBlock.OnLoad = { 
    param(
    [byte[][]]$Values
    )
    Process
    {
        foreach($Value in $Values)
        {
            New-Object System.Security.Principal.SecurityIdentifier($Value,0)
        }
    }
}
$codeBlock.OnSave = { 
    param(
    [system.security.principal.securityidentifier[]]$Values
    )
    
    Process
    {
        foreach($sid in $Values)
        {
            $retVal=new-object system.byte[]($sid.BinaryLength)
            $sid.GetBinaryForm($retVal,0)
            ,($retVal)
        }
    }
}
$codeBlock
