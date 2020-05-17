# From [MS-SAMR]/2.2.1.11
# https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-samr/1f8d7ea1-fcc1-4833-839a-f94d67c08fcd
Add-Type @'
using System;
[Flags]
public enum GroupType
{
    Global = 0x00000002,
    Local = 0x00000004,
    Universal = 0x00000008,
    Security = unchecked((int)0x80000000)
}
'@

'Load','Save' | ForEach-Object {
    $TransformName = 'groupType'
    $SupportedAttributes = @('groupType')
    $Action = $_

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
            $codeBlock.Transform = { 
                param(
                [int[]]$Values
                )
                Process
                {
                    foreach($Value in $Values)
                    {
                        [GroupType].GetEnumValues().ForEach({if(($Value -band $_) -eq $_) {"$_"}})
                    }
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
                
                Process
                {
                    $retVal = 0
                    $Values | ForEach-Object{ $val =$_; [GroupType].GetEnumValues() | ForEach-Object{ if($val -eq "$_") {$retVal+=$_}}}
                    $retVal
                }
            }
            $codeBlock
            break;
        }
    }
}
