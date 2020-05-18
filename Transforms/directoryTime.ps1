[CmdletBinding()]
param (
    [Parameter()]
    [Switch]
    $FullLoad
)

if($FullLoad)
{
}

$prop=[Ordered]@{
    SupportedAttributes=@('createTimestamp','dsCorePropagationData','modifyTimestamp','whenCreated','whenChanged')
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
            [DateTime]::ParseExact($val,'yyyyMMddHHmmss.fZ',[CultureInfo]::InvariantCulture,[System.Globalization.DateTimeStyles]::None)                    }
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
            $Value.ToString('yyyyMMddHHmmss.0Z')
        }
    }
}
$codeBlock
