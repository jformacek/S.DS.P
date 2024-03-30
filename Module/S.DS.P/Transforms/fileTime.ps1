[CmdletBinding()]
param (
    [Parameter()]
    [Switch]
    $FullLoad
)

$codeBlock= New-LdapAttributeTransformDefinition -SupportedAttributes @('accountExpires','badPasswordTime','lastLogon','lastLogonTimestamp','ms-Mcs-AdmPwdExpirationTime','msDS-UserPasswordExpiryTimeComputed','pwdLastSet')

$codeBlock.OnLoad = { 
    param(
    [string[]]$Values
    )
    Process
    {
        foreach($Value in $Values)
        {
            try {
                [DateTime]::FromFileTimeUtc([long]$Value)
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
    [Object[]]$Values
    )
    
    Process
    {
        foreach($Value in $Values)
        {
            #standard expiration
            if($value -is [datetime]) {
                $Value.ToFileTimeUtc()
            }
            else
            {
                #values that did not transform to DateTime in OnLoad -> return as-is as string
                "$value"
            }
        }
    }
}
$codeBlock
