[CmdletBinding()]
param (
    [Parameter()]
    [Switch]
    $FullLoad
)

if($FullLoad)
{
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;

public class AdmPwdPassword
{
    public uint EncryptionKeyId {get; set;}
    public string PasswordData {get; private set;}

    public AdmPwdPassword(string rawValue)
    {
        string[] data = rawValue.Split(':');
        switch (data.Length)
        {
            case 2:
                //keyID + encrypted Pwd
                EncryptionKeyId = UInt32.Parse(data[0].Trim());
                PasswordData = data[1].Trim();
                break;
            case 1:
                //just pwd
                EncryptionKeyId = 0;
                PasswordData = data[0];
                break;
        }
    }

    public override string ToString()
    {
        if(EncryptionKeyId==0)
            return PasswordData;
        return string.Format("{0}: {1}", EncryptionKeyId, PasswordData);
    }
}
'@
}

#add attributes that can be used with this transform
$SupportedAttributes = @('ms-Mcs-AdmPwd')

# This is mandatory definition of transform that is expected by transform architecture
$codeBlock= New-LdapAttributeTransformDefinition -SupportedAttributes $SupportedAttributes

$codeBlock.OnLoad = { 
    param(
    [string[]]$Values
    )
    Process
    {
        foreach($Value in $Values)
        {
            try {
                New-Object AdmPwdPassword($Value)
            }
            catch {
                throw;
            }
        }
    }
}
$codeBlock.OnSave = { 
    param(
    [AdmPwdPassword[]]$Values
    )
    
    Process
    {
        foreach($Value in $Values)
        {
            $Value.ToString();
        }
    }
}
$codeBlock

