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
                New-Object System.Guid(,$value)
            }
        }
        $codeBlock
        break;
    }
    "Save"
    {
        $codeBlock.Transform = { 
            param(
            [Guid[]]$Values
            )
            
            foreach($value in $values)
            {
                $value.ToByteArray()
            }
        }
        $codeBlock
        break;
    }
}