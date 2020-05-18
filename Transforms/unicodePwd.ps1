[CmdletBinding()]
param (
    [Parameter()]
    [Switch]
    $FullLoad
)

$prop=[Ordered]@{
    SupportedAttributes=@('unicodePwd')
    OnLoad = $null
    OnSave = $null
}
$codeBlock = new-object PSCustomObject -property $prop
$codeBlock.OnSave = { 
    param(
    [string[]]$Values
    )
    
    Process
    {
        foreach($Value in $Values)
        {
            ,([System.Text.Encoding]::Unicode.GetBytes("`"$Value`"") -as [byte[]])                    }
    }
}
$codeBlock
