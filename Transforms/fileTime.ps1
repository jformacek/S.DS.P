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
            try {
                [DateTime]::FromFileTimeUtc($Value)
            }
            catch {
                #value outside of range for filetime
                #such as in https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-adts/f9e9b7e2-c7ac-4db6-ba38-71d9696981e9
                $Value
            }
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
