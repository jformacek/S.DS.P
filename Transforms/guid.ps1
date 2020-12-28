[CmdletBinding()]
param (
    [Parameter()]
    [Switch]
    $FullLoad
)

if($FullLoad)
{
}

$codeBlock= New-LdapAttributeTransformDefinition -SupportedAttributes @('objectGuid','mS-DS-ConsistencyGuid','msExchMailboxGuid','msExchPoliciesExcluded') -BinaryInput

$codeBlock.OnLoad = { 
    param(
    [byte[][]]$Values
    )
    Process
    {
        foreach($Value in $Values)
        {
            New-Object System.Guid(,$Value)
        }
    }
}
$codeBlock.OnSave = { 
    param(
    [Guid[]]$Values
    )
    
    Process
    {
        foreach($value in $values)
        {
            ,($value.ToByteArray())
        }
    }
}
$codeBlock
