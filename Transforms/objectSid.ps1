[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]
    [ValidateSet('Load','Save')]
    $Action,
    [Parameter(Mandatory=$false)]
    [string]
    $AttributeName = 'objectSid'
)

# Add any types that are used by transforms
# CSharp types added via Add-Type are supported

#define variables necessary to create a transform

$prop=[Ordered]@{[string]'Action'=$Action;'Attribute'=$AttributeName;[string]'Transform' = $null}
$codeBlock = new-object PSCustomObject -property $prop

switch($Action)
{
    "Load"
    {
        $codeBlock.Transform = { 
            param(
            [Object[]]$Values
            )
            Process
            {
                foreach($Value in $Values)
                {
                    New-Object System.Security.Principal.SecurityIdentifier($Value,0)
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
            [system.security.principal.securityidentifier[]]$Values
            )
            Process
            {
                foreach($sid in $Values)
                {
                    $retVal=new-object system.byte[]($sid.BinaryLength)
                    $sid.GetBinaryForm($retVal,0)
                    $retVal
                }
            }
        }
        $codeBlock
        break;
    }
}