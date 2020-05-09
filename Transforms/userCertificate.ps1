[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]
    [ValidateSet('Load','Save')]
    $Action,
    [Parameter(Mandatory=$false)]
    [string]
    $AttributeName = 'userCertificate'
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
            [byte[][]]$Values
            )
            Process
            {
                foreach($Value in $Values)
                {
                    new-object System.Security.Cryptography.X509Certificates.X509Certificate2(,$Value)
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
            [System.Security.Cryptography.X509Certificates.X509Certificate2[]]$Values
            )
            
            Process
            {
                foreach($Value in $Values)
                {
                    $Value.RawData
                }

            }
        }
        $codeBlock
        break;
    }
}