
[CmdletBinding()]
param (
    [Parameter()]
    [Switch]
    $FullLoad
)

if($FullLoad)
{
# Add any types that are used by transforms
# CSharp types added via Add-Type are supported
}

#add attributes that can be used with this transform
$SupportedAttributes = @('IsCriticalSystemObject')

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
    [object[]]$Values
    )
    Process
    {
        foreach($Value in $Values)
        {
            [Convert]::ToBoolean($value)
        }
    }
}
$codeBlock.OnSave = { 
    param(
    [bool[]]$Values
    )
    
    Process
    {
        foreach($Value in $Values)
        {
            "$Value".ToUpper()
        }
    }
}
$codeBlock

