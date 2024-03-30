function New-LdapAttributeTransformDefinition
{
<#
.SYNOPSIS
    Creates definition of transform. Used by transform implementations.

.OUTPUTS
    Transform definition

.LINK
More about attribute transforms and how to create them: https://github.com/jformacek/S.DS.P

#>
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory, Position=0)]
        [string[]]$SupportedAttributes,
        [switch]
            #Whether supported attributes need to be loaded from/saved to LDAP as binary stream
        $BinaryInput
    )

    process
    {
        [PSCustomObject][Ordered]@{
            BinaryInput=$BinaryInput
            SupportedAttributes=$SupportedAttributes
            OnLoad = $null
            OnSave = $null
        }
    }
}
