[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]
    [ValidateSet('Load','Save')]
    $Action,
    [Parameter(Mandatory=$false)]
    [string]
    $AttributeName = 'ms-Mcs-AdmPwdExpirationTime'
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
            Process
            {
                foreach($Value in $Values)
                {
                    [DateTime]::FromFileTimeUtc([long]::Parse($Value))
                }
            }
        }
        $codeBlock
        break;
    }
    "Save"
    {
        $codeBlock.Transform = { 
            param(
            [DateTime[]]$Values
            )
            
            Process
            {
                foreach($Value in $Values)
                {
                    $Value.ToFileTimeUtc()
                }

            }
        }
        $codeBlock
        break;
    }
}