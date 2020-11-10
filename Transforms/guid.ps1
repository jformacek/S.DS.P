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
    SupportedAttributes=@('objectGuid','mS-DS-ConsistencyGuid','msExchMailboxGuid','msExchPoliciesExcluded')
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
