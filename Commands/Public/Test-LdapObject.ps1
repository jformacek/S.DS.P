Function Test-LdapObject
{
<#
.SYNOPSIS
    Checks existence of LDAP object by distinguished name.

.DESCRIPTION
    This function checks if an LDAP object exists by its distinguished name.
    It can accept a string, DistinguishedName object, or an object with a distinguishedName property.
    If the object is found, it returns $true; otherwise, it returns $false.
    
.OUTPUTS
    True or False, depending on whether the LDAP object was found

.EXAMPLE

.LINK
More about System.DirectoryServices.Protocols: http://msdn.microsoft.com/en-us/library/bb332056.aspx

#>
    Param (
        [parameter(Mandatory = $true, ValueFromPipeline=$true)]
        [Object]
            #Object to test existence of
        $Object,

        [parameter()]
        [System.DirectoryServices.Protocols.LdapConnection]
            #Existing LDAPConnection object.
        $LdapConnection = $script:LdapConnection

    )

    begin
    {
        EnsureLdapConnection -LdapConnection $LdapConnection
    }

    Process
    {
        $dn = $objet | GetDnFromInput
        
        try {
            $result = Find-LdapObject `
                -LdapConnection $LdapConnection `
                -SearchBase $dn `
                -searchFilter '(objectClass=*)' `
                -searchScope Base `
                -PropertiesToLoad '1.1' `
                -ErrorAction Stop | Out-Null
            
            #some LDAP servrs return null if object is not found, others throw an exception
            return ($null -ne $result)
        }
        catch [System.DirectoryServices.Protocols.DirectoryOperationException] {
            if($_.Exception.Response.ResultCode -eq  [System.DirectoryServices.Protocols.ResultCode]::NoSuchObject)
            {
                return $false
            }
            else
            {
                throw
            }
        }
    }
}
