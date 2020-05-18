[CmdletBinding()]
param (
    [Parameter()]
    [Switch]
    $FullLoad
)

$prop=[Ordered]@{
    SupportedAttributes=@('objectSid')
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
            $retVal
        }
    }
}
$codeBlock
