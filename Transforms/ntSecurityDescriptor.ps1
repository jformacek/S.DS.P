[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]
    [ValidateSet('Load','Save')]
    $Action,
    [Parameter(Mandatory=$false)]
    [string]
    $AttributeName = 'ntSecurityDescriptor'
)

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
            foreach($value in $Values)
            {
                $dacl = new-object System.DirectoryServices.ActiveDirectorySecurity
                $dacl.SetSecurityDescriptorBinaryForm($value)
                $dacl
            }
        }
        $codeBlock
        break;
    }
    "Save"
    {
        $codeBlock.Transform = { 
            param(
            [System.DirectoryServices.ActiveDirectorySecurity]$Values
            )
            $Values.GetSecurityDescriptorBinaryForm()
        }
        $codeBlock
        break;
    }
}