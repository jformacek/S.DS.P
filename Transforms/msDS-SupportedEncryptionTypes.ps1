[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]
    [ValidateSet('Load','Save')]
    $Action
)


Add-Type @'
using System;
[Flags]
public enum EncryptionTypes
{
    DES_CBC_CRC = 0x1,
    DES_CBC_MD5 = 0x2,
    RC4_HMAC_MD5 = 0x4,
    AES128_CTS_HMAC_SHA1_96 = 0x8,
    AES256_CTS_HMAC_SHA1_96 = 0x10
}
'@

$prop=[Ordered]@{[string]'Action'=$Action;'Attribute'='msDS-SupportedEncryptionTypes';[string]'Transform' = $null}
$codeBlock = new-object PSCustomObject -property $prop

switch($Action)
{
    "Load"
    {
        $codeBlock.Transform = { 
            param(
            [int[]]$Values
            )
            foreach($Value in $Values)
            {
                [EncryptionTypes].GetEnumValues().ForEach({if(($Value -band $_) -eq $_) {"$_"}})
            }
        }
        $codeBlock
        break;
    }
    "Save"
    {
        $codeBlock.Transform = { 
            param(
            [System.String[]]$Values
            )
            
            
            $retVal = 0
            $Values | ForEach-Object{ $val =$_; [EncryptionTypes].GetEnumValues() | ForEach-Object{ if($val -eq "$_") {$retVal+=$_}}}
            $retVal
        }
        $codeBlock
        break;
    }
}