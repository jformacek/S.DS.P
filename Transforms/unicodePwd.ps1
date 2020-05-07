[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]
    [ValidateSet('Load','Save')]
    $Action,
    [Parameter(Mandatory=$false)]
    [string]
    $AttributeName = 'unicodePwd'
)

# Add any types that are used by transforms
# CSharp types added via Add-Type are supported

#define variables necessary to create a transform

# This is mandatory definition of transform that is expected by transform architecture
$prop=[Ordered]@{[string]'Action'=$Action;'Attribute'=$AttributeName;[string]'Transform' = $null}
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
                #we intentionally do not do any transform here as password is not readable fro AD
                $value
            }
        }
        $codeBlock
        break;
    }
    "Save"
    {
        $codeBlock.Transform = { 
            param(
            [string[]]$Values
            )
            
            foreach($Value in $Values)
            {
                ,([System.Text.Encoding]::Unicode.GetBytes("`"$Value`"") -as [byte[]])
            }

        }
        $codeBlock
        break;
    }
}