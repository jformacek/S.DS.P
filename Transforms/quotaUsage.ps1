
[CmdletBinding()]
param (
    [Parameter()]
    [Switch]
    $FullLoad
)

$codeBlock=[PSCustomObject][Ordered]@{
    SupportedAttributes=@('msDS-TopQuotaUsage')
    OnLoad = $null
    OnSave = $null
}

$codeBlock.OnLoad = { 
    param(
    [string[]]$Values
    )
    Process
    {
        foreach($Value in $Values)
        {
            [xml]$Value.SubString(0,$Value.Length-2)
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

