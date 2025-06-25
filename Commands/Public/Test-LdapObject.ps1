Function Test-LdapObject
{
<#
.SYNOPSIS
    

.DESCRIPTION
    
.OUTPUTS
    Nothing

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
        if($null -ne $Object)
        {
            #we support pipelining of strings or DistinguishedName types, or objects containing distinguishedName property - string or DistinguishedName
            switch($Object.GetType().Name) {
                "String"
                {
                    $dn = $Object
                    break;
                }
                'DistinguishedName' {
                    $dn=$Object.ToString()
                    break;
                }
                default
                {
                    if($null -ne $Object.distinguishedName)
                    {
                        #covers both string and DistinguishedName types
                        $dn=$Object.distinguishedName.ToString()
                    }
                }
            }
        }

        if([string]::IsNullOrEmpty($dn)) {
            throw (new-object System.ArgumentException("Distinguished name not present on input object"))
        }
        Find-LdapObject -LdapConnection $LdapConnection -SearchBase $dn -searchFilter '(objectClass=*)' -searchScope Base -PropertiesToLoad '1.1'
    }
}
