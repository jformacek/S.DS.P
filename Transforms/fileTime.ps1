[CmdletBinding()]
param (
    [Parameter()]
    [Switch]
    $FullLoad
)

$prop=[Ordered]@{
    SupportedAttributes=@('badPasswordTime','lastLogon','lastLogonTimestamp','ms-Mcs-AdmPwdExpirationTime','msDS-UserPasswordExpiryTimeComputed','pwdLastSet')
    OnLoad = $null
    OnSave = $null
}
$codeBlock = new-object PSCustomObject -property $prop
$codeBlock.OnLoad = { 
    param(
    [long[]]$Values
    )
    Process
    {
        foreach($Value in $Values)
        {
            [DateTime]::FromFileTimeUtc($Value)
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
            $Value.ToFileTimeUtc()
        }
    }
}
$codeBlock
