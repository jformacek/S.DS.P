[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]
    [ValidateSet('Load','Save')]
    $Action
)

# Add any types that are used by transforms
# CSharp types added via Add-Type are supported

#define variables necessary to create a transform

# This is mandatory definition of transform that is expected by transform architecture
$prop=[Ordered]@{[string]'Action'=$Action;'Attribute'='objectGuid';[string]'Transform' = $null}
$codeBlock = new-object PSCustomObject -property $prop

switch($Action)
{
    "Load"
    {
        $codeBlock.Transform = { 
            param(
            [object[]]$Values
            )
            foreach($Value in $Values)
            {
                #implement a transform
                #input values will always come as an array of objects - cast as needed
            }
        }
        $codeBlock
        break;
    }
    "Save"
    {
        $codeBlock.Transform = { 
            param(
            [Object[]]$Values
            )
            
            #implement a transform used when saving attribute value
            #input value type here depends on what comes from Load-time transform - update parameter type as needed
        }
        $codeBlock
        break;
    }
}