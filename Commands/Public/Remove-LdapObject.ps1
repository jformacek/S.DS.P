Function Remove-LdapObject
{
<#
.SYNOPSIS
    Removes existing object from LDAP server

.DESCRIPTION
    Removes an object from LDAP server.
    All proprties of object are ignored and no transforms are performed; only distinguishedName property is used to locate the object.

.OUTPUTS
    Nothing

.EXAMPLE
$Ldap = Get-LdapConnection -LdapServer "mydc.mydomain.com" -EncryptionType Kerberos
Remove-LdapObject -LdapConnection $Ldap -Object "cn=User1,cn=Users,dc=mydomain,dc=com"

Description
-----------
Removes existing user account.

.EXAMPLE
$Ldap = Get-LdapConnection
Find-LdapObject -LdapConnection (Get-LdapConnection) -SearchFilter:"(&(objectClass=organitationalUnit)(adminDescription=ToDelete))" -SearchBase:"dc=myDomain,dc=com" | Remove-LdapObject -UseTreeDelete

Description
-----------
Removes existing subtree using TreeDeleteControl

.LINK
More about System.DirectoryServices.Protocols: http://msdn.microsoft.com/en-us/library/bb332056.aspx

#>
    Param (
        [parameter(Mandatory = $true, ValueFromPipeline=$true)]
        [Object]
            #Either string containing distinguishedName or object with DistinguishedName property
        $Object,
        [parameter()]
        [System.DirectoryServices.Protocols.LdapConnection]
            #Existing LDAPConnection object.
        $LdapConnection = $script:LdapConnection,

        [parameter(Mandatory = $false)]
        [System.DirectoryServices.Protocols.DirectoryControl[]]
            #Additional controls that caller may need to add to request
        $AdditionalControls=@(),

        [parameter(Mandatory = $false)]
        [Switch]
            #Whether or not to use TreeDeleteControl.
        $UseTreeDelete
    )

    begin
    {
        EnsureLdapConnection -LdapConnection $LdapConnection
    }

    Process
    {
        [System.DirectoryServices.Protocols.DeleteRequest]$rqDel=new-object System.DirectoryServices.Protocols.DeleteRequest
        #add additional controls that caller may have passed
        foreach($ctrl in $AdditionalControls) {$rqDel.Controls.Add($ctrl) | Out-Null}

        switch($Object.GetType().Name)
        {
            "String"
            {
                $rqDel.DistinguishedName=$Object
                break;
            }
            'DistinguishedName' {
                $rqDel.DistinguishedName=$Object.ToString()
                break;
            }
            default
            {
                if($null -ne $Object.distinguishedName)
                {
                    $rqDel.DistinguishedName=$Object.distinguishedName.ToString()
                }
                else
                {
                    throw (new-object System.ArgumentException("DistinguishedName must be passed"))
                }
            }
        }
        if($UseTreeDelete) {
            $rqDel.Controls.Add((new-object System.DirectoryServices.Protocols.TreeDeleteControl)) | Out-Null
        }
        $LdapConnection.SendRequest($rqDel) -as [System.DirectoryServices.Protocols.DeleteResponse] | Out-Null
    }
}
