Function Unregister-LdapAttributeTransform
{
<#
.SYNOPSIS

    Unregisters previously registered attribute transform logic

.DESCRIPTION

    Unregisters attribute transform. Attribute transforms transform attributes from simple types provided by LDAP server to more complex types. Transforms work on attribute level and do not have acces to values of other attributes.
    Transforms must be constructed using specific logic, see existing transforms and template on GitHub

.EXAMPLE

$Ldap = Get-LdapConnection -LdapServer "mydc.mydomain.com" -EncryptionType Kerberos
#get list of available transforms
Get-LdapAttributeTransform -ListAvailable
#register necessary transforms
Register-LdapAttributeTransform -Name Guid -AttributeName objectGuid
#Now objectGuid property on returned object is Guid rather than raw byte array
Find-LdapObject -LdapConnection $Ldap -SearchBase "cn=User1,cn=Users,dc=mydomain,dc=com" -SearchScope Base -PropertiesToLoad 'cn',objectGuid

#we no longer need the transform, let's unregister
Unregister-LdapAttributeTransform -AttributeName objectGuid
Find-LdapObject -LdapConnection $Ldap -SearchBase "cn=User1,cn=Users,dc=mydomain,dc=com" -SearchScope Base -PropertiesToLoad 'cn',objectGuid -BinaryProperties 'objectGuid'
#now objectGuid property of returned object contains raw byte array

Description
----------
This example registers transform that converts raw byte array in objectGuid property into instance of System.Guid
After command completes, returned object(s) will have instance of System.Guid in objectGuid property
Then the transform is unregistered, so subsequent calls do not use it

.LINK

More about System.DirectoryServices.Protocols: http://msdn.microsoft.com/en-us/library/bb332056.aspx
More about attribute transforms and how to create them: https://github.com/jformacek/S.DS.P/tree/master/Module/Transforms

#>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName, Position=0)]
        [string]
            #Name of the attribute to unregister transform from
        $AttributeName
    )

    Process
    {
        if($script:RegisteredTransforms.Keys -contains $AttributeName)
        {
            $script:RegisteredTransforms.Remove($AttributeName)
        }
    }
}
