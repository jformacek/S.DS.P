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

public class AdmPwdPasswordHistory
{
    public DateTime ValidSince {get; set;}
    public uint EncryptionKeyId {get; set;}
    public string PasswordData {get; set;}

    private string _rawValue;

    public AdmPwdPasswordHistory(string rawValue)
    {
        _rawValue = rawValue;
        string[] data = rawValue.Split(':');
        switch (data.Length)
        {
            case 3:
                //timestamp + keyID + encrypted Pwd
                ValidSince = DateTime.ParseExact(data[0].Replace(".0Z", ""), "yyyyMMddHHmmss", System.Globalization.CultureInfo.InvariantCulture, System.Globalization.DateTimeStyles.AssumeUniversal | System.Globalization.DateTimeStyles.AdjustToUniversal);
                EncryptionKeyId = UInt32.Parse(data[1].Trim());
                PasswordData = data[2].Trim();
                break;
            case 2:
                //timestamp + pwd
                ValidSince = DateTime.ParseExact(data[0].Replace(".0Z", ""), "yyyyMMddHHmmss", System.Globalization.CultureInfo.InvariantCulture, System.Globalization.DateTimeStyles.AssumeUniversal | System.Globalization.DateTimeStyles.AdjustToUniversal);
                EncryptionKeyId = 0;
                PasswordData = data[1].Trim();
                break;
            case 1:
                //just pwd
                ValidSince = DateTime.MinValue;
                EncryptionKeyId = 0;
                PasswordData = data[0];
                break;
        }
    }

    public override string ToString()
    {
        return _rawValue;
    }
}
'@
}

#add attributes that can be used with this transform
$SupportedAttributes = @('ms-Mcs-AdmPwdHistory')

# This is mandatory definition of transform that is expected by transform architecture
$prop=[Ordered]@{
    BinaryInput=$false
    SupportedAttributes=$SupportedAttributes
    OnLoad = $null
    OnSave = $null
}
$codeBlock = new-object PSCustomObject -property $prop
$codeBlock.OnLoad = { 
    param(
    [string[]]$Values
    )
    Process
    {
        foreach($Value in $Values)
        {
            New-Object AdmPwdPasswordHistory($Value)
        }
    }
}
$codeBlock.OnSave = { 
    param(
    [AdmPwdPasswordHistory[]]$Values
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

