
[CmdletBinding()]
param (
    [Parameter()]
    [Switch]
    $FullLoad
)

$prop=[Ordered]@{
    SupportedAttributes=@('msDS-ReplAttributeMetaData')
    OnLoad = $null
    OnSave = $null
}

$codeBlock = new-object PSCustomObject -property $prop

$codeBlock.OnLoad = { 
    param(
    [object[]]$Values
    )
    Process
    {
        foreach($Value in $Values)
        {
            [xml]$Value
        }
    }
}
$codeBlock.OnSave = { 
    param(
    [object[]]$Values
    )
    
    Process
    {
        foreach($Value in $Values)
        {
            $Value.InnerXml
        }
    }
}

$codeBlock

