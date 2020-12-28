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

#add attributes that can be processed by this transform
$SupportedAttributes = @()

# This is mandatory definition of transform that is expected by transform architecture
$codeBlock = New-LdapAttributeTransformDefinition -SupportedAttributes $SupportedAttributes
$codeBlock.OnLoad = { 
    param(
    [object[]]$Values
    )
    Process
    {
        foreach($Value in $Values)
        {
            #implement a transform
            #input values will always come as an array of objects - cast as needed
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
            #implement a transform used when saving attribute value
            #input value type here depends on what comes from Load-time transform - update parameter type as needed
        }
    }
}
$codeBlock
