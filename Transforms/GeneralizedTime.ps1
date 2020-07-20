
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

New-Object PSCustomObject -property ([ordered]@{
    SupportedAttributes=@('createTimestamp','dsCorePropagationData','modifyTimestamp','whenCreated','whenChanged')
    OnLoad = { 
        param(
        [object[]]$Values
        )
        Process
        {
            foreach($Value in $Values)
            {
                [DateTime]::ParseExact($value,'yyyyMMddHHmmss.fK',[System.Globalization.CultureInfo]::InvariantCulture,[System.Globalization.DateTimeStyles]::AssumeUniversal)
            }
        }
    }
    OnSave = { 
        param(
        [DateTime[]]$Values
        )
        
        Process
        {
            foreach($Value in $Values)
            {
                $value.ToUniversalTime().ToString('yyyyMMddHHmmss.0Z')
            }
        }
    }
})

<#
#add attributes that can be used with this transform
$SupportedAttributes = @('whenCreated','whenChanged')

# This is mandatory definition of transform that is expected by transform architecture
$prop=[Ordered]@{
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
            [DateTime]::ParseExact($value,'yyyyMMddHHmmss.fK',[System.Globalization.CultureInfo]::InvariantCulture,[System.Globalization.DateTimeStyles]::AssumeUniversal)
        }
    }
}
$codeBlock.OnSave = { 
    param(
    [DateTime[]]$Values
    )
    
    Process
    {
        foreach($Value in $Values)
        {
            $value.ToUniversalTime().ToString('yyyyMMddHHmmss.0Z')
        }
    }
}
$codeBlock
#>
