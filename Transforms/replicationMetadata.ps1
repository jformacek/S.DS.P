
[CmdletBinding()]
param (
    [Parameter()]
    [Switch]
    $FullLoad
)

$prop=[Ordered]@{
    SupportedAttributes=@('msDS-ReplAttributeMetaData','msDS-ReplValueMetaData','msDS-NCReplCursors','msDS-NCReplInboundNeighbors')
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

