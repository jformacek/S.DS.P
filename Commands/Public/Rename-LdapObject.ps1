Function Rename-LdapObject
{
<#
.SYNOPSIS
    Changes RDN of existing object or moves the object to a different subtree (or both at the same time)

.DESCRIPTION
    Performs only rename of object.
    All properties of object are ignored and no transforms are performed.
    Only distinguishedName property is used to locate the object.

.OUTPUTS
    Nothing

.EXAMPLE
$Ldap = Get-LdapConnection -LdapServer "mydc.mydomain.com" -EncryptionType Kerberos
Rename-LdapObject -LdapConnection $Ldap -Object "cn=User1,cn=Users,dc=mydomain,dc=com" -NewName 'cn=User2'

Decription
----------
This command changes CN of User1 object to User2. Notice that 'cn=' is part of new name. This is required by protocol, when you do not provide it, you will receive NamingViolation error.

.EXAMPLE
$Ldap = Get-LdapConnection
Rename-LdapObject -LdapConnection $Ldap -Object "cn=User1,cn=Users,dc=mydomain,dc=com" -NewName "cn=User1" -NewParent "ou=CompanyUsers,dc=mydomain,dc=com"

Description
-----------
This command Moves the User1 object to different OU. Notice the newName parameter - it's the same as old name as we do not rename the object a new name is required parameter for protocol.

.LINK
More about System.DirectoryServices.Protocols: http://msdn.microsoft.com/en-us/library/bb332056.aspx

#>

    Param (
        [parameter(Mandatory = $true, ValueFromPipeline=$true)]
        [Object]
            #Either string containing distinguishedName
            #Or object with DistinguishedName property
        $Object,

        [parameter()]
        [System.DirectoryServices.Protocols.LdapConnection]
            #Existing LDAPConnection object.
        $LdapConnection = $script:LdapConnection,

        [parameter(Mandatory = $true)]
            #New name of object
        [String]
        $NewName,

        [parameter(Mandatory = $false)]
            #DN of new parent
        [String]
        $NewParent,

            #whether to delete original RDN
        [Switch]
        $KeepOldRdn,

        [parameter(Mandatory = $false)]
        [System.DirectoryServices.Protocols.DirectoryControl[]]
            #Additional controls that caller may need to add to request
        $AdditionalControls=@()
    )

    begin
    {
        EnsureLdapConnection -LdapConnection $LdapConnection
    }
    Process
    {
        [System.DirectoryServices.Protocols.ModifyDNRequest]$rqModDN=new-object System.DirectoryServices.Protocols.ModifyDNRequest
        switch($Object.GetType().Name)
        {
            "String"
            {
                $rqModDN.DistinguishedName=$Object
            }
            default
            {
                if($Object.distinguishedName)
                {
                    $rqModDN.DistinguishedName=$Object.distinguishedName
                }
                else
                {
                    throw (new-object System.ArgumentException("DistinguishedName must be passed"))
                }
            }
        }
        $rqModDn.NewName = $NewName
        if(-not [string]::IsNullOrEmpty($NewParent)) {$rqModDN.NewParentDistinguishedName = $NewParent}
        $rqModDN.DeleteOldRdn = (-not $KeepOldRdn)
        $LdapConnection.SendRequest($rqModDN) -as [System.DirectoryServices.Protocols.ModifyDNResponse] | Out-Null
    }
}
