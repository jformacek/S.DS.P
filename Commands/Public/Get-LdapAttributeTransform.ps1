Function Get-LdapAttributeTransform
{
<#
.SYNOPSIS
    Lists registered attribute transform logic

.OUTPUTS
    List of registered transforms

.LINK
More about System.DirectoryServices.Protocols: http://msdn.microsoft.com/en-us/library/bb332056.aspx
More about attribute transforms and how to create them: https://github.com/jformacek/S.DS.P

#>
    [CmdletBinding()]
    param (
        [Parameter()]
        [Switch]
            #Lists all tranforms available
        $ListAvailable
    )
    if($ListAvailable)
    {
        $TransformList = Get-ChildItem -Path "$PSScriptRoot\Transforms\*.ps1" -ErrorAction SilentlyContinue
        foreach($transformFile in $TransformList)
        {
            $transform = (& $transformFile.FullName)
            $transform = $transform | Add-Member -MemberType NoteProperty -Name 'TransformName' -Value ([System.IO.Path]::GetFileNameWithoutExtension($transformFile.FullName)) -PassThru
            $transform | Select-Object TransformName,SupportedAttributes
        }
    }
    else {
        foreach($attrName in ($script:RegisteredTransforms.Keys | Sort-object))
        {
            [PSCustomObject]([Ordered]@{
                AttributeName = $attrName
                TransformName = $script:RegisteredTransforms[$attrName].Name
            })
        }
    }
}
