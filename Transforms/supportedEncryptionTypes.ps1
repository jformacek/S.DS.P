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

'Load','Save' | ForEach-Object {
    $TransformName = 'supportedEncryptionTypes'
    #add attributes that can be used with this transform
    $SupportedAttributes = @('msDS-SupportedEncryptionTypes')
    $Action = $_
    # This is mandatory definition of transform that is expected by transform architecture
    $prop=[Ordered]@{
        Name=$TransformName
        Action=$Action
        SupportedAttributes=$SupportedAttributes
        Transform = $null
    }
    $codeBlock = new-object PSCustomObject -property $prop
    switch($Action)
    {
        "Load"
        {
            #transform that executes when loading attribute from LDAP server
            $codeBlock.Transform = { 
                param(
                [object[]]$Values
                )
                Process
                {
                    foreach($Value in $Values)
                    {
                        [EncryptionTypes].GetEnumValues().ForEach({if(($Value -band $_) -eq $_) {"$_"}})
                    }
                }
            }
            $codeBlock
            break;
        }
        "Save"
        {
            #transform that executes when loading attribute from LDAP server
            $codeBlock.Transform = { 
                param(
                [object[]]$Values
                )
                
                Process
                {
                    foreach($Value in $Values)
                    {
                        $retVal = 0
                        $Values | ForEach-Object{ $val = $_; [EncryptionTypes].GetEnumValues() | ForEach-Object{ if($val -eq "$_") {$retVal+=$_}}}
                        $retVal
                    }
                }
            }
            $codeBlock
            break;
        }
    }
}
