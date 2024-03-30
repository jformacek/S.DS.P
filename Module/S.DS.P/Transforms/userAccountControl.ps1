[CmdletBinding()]
param (
    [Parameter()]
    [Switch]
    $FullLoad
)

if($FullLoad)
{
# From [MS-SAMR]/2.2.1.13
# https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-samr/10bf6c8e-34af-4cf9-8dff-6b6330922863
Add-Type @'
using System;
[Flags]
public enum UserAccountControl : uint
{
    UF_SCRIPT = 0x1,
    UF_ACCOUNTDISABLE = 0x2,
    UF_HOMEDIR_REQUIRED = 0x8,
    UF_LOCKOUT = 0x10,
    UF_PASSWD_NOTREQD = 0x20,
    UF_PASSWD_CANT_CHANGE = 0x40,
    UF_ENCRYPTED_TEXT_PASSWORD_ALLOWED = 0x80,
    UF_TEMP_DUPLICATE_ACCOUNT = 0x100,
    UF_NORMAL_ACCOUNT = 0x200,
    UF_INTERDOMAIN_TRUST_ACCOUNT = 0x800,
    UF_WORKSTATION_TRUST_ACCOUNT = 0x1000,
    UF_SERVER_TRUST_ACCOUNT = 0x2000,
    UF_DONT_EXPIRE_PASSWD = 0x10000,
    UF_MNS_LOGON_ACCOUNT = 0x20000,
    UF_SMARTCARD_REQUIRED = 0x40000,
    UF_TRUSTED_FOR_DELEGATION = 0x80000,
    UF_NOT_DELEGATED = 0x100000,
    UF_USE_DES_KEY_ONLY = 0x200000,
    UF_DONT_REQUIRE_PREAUTH = 0x400000,
    UF_PASSWORD_EXPIRED = 0x800000,
    UF_TRUSTED_TO_AUTHENTICATE_FOR_DELEGATION = 0x1000000,
    UF_NO_AUTH_DATA_REQUIRED = 0x2000000,
    UF_PARTIAL_SECRETS_ACCOUNT = 0x4000000,
    UF_USE_AES_KEYS = 0x8000000
}
'@
}
$codeBlock= New-LdapAttributeTransformDefinition -SupportedAttributes @('userAccountControl')

$codeBlock.OnLoad = { 
    param(
    [string[]]$Values
    )
    Process
    {
        foreach($Value in $Values)
        {
            [UserAccountControl].GetEnumValues().ForEach({if(($Value -band $_) -eq $_) {$_}})
        }
    }
}
$codeBlock.OnSave = { 
    param(
    [UserAccountControl[]]$Values
    )
    
    Process
    {
        $retVal = 0
        $Values.ForEach({ $retVal = $retVal -bor $_})
        [BitConverter]::ToInt32([BitConverter]::GetBytes($retVal),0)
    }
}
$codeBlock

