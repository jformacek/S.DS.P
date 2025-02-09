Function Edit-LdapObject
{
<#
.SYNOPSIS
    Modifies existing object in LDAP server

.DESCRIPTION
    Modifies existing object in LDAP server.
    Optionally performs attribute transforms registered for Save action before saving changes

.OUTPUTS
    Nothing

.EXAMPLE
$obj =  [PSCustomObject]@{distinguishedName=$null; employeeNumber=$null}
$obj.DistinguishedName = "cn=user1,cn=users,dc=mydomain,dc=com"
$obj.employeeNumber = "12345"

$Ldap = Get-LdapConnection -LdapServer "mydc.mydomain.com" -EncryptionType Kerberos
Edit-LdapObject -LdapConnection $Ldap -Object $obj

Description
-----------
Modifies existing user account in domain.

.EXAMPLE
$conn = Get-LdapConnection -LdapServer "mydc.mydomain.com" -EncryptionType Kerberos
$dse = Get-RootDSE -LdapConnection $conn
$User = Find-LdapObject -LdapConnection $conn -searchFilter '(&(objectClass=user)(objectCategory=organizationalPerson)(sAMAccountName=myUser1))' -searchBase $dse.defaultNamingContext
$Group = Find-LdapObject -LdapConnection $conn -searchFilter '(&(objectClass=group)(objectCategory=group)(cn=myGroup1))' -searchBase $dse.defaultNamingContext -AdditionalProperties @('member')
$Group.member=@($User.distinguishedName)
Edit-LdapObject -LdapConnection $conn -Object $Group -Mode Add

Description
-----------
Finds user account in LDAP server and adds it to group

.EXAMPLE
#get connection and sotre in session variable
Get-LdapConnection -LdapServer "mydc.mydomain.com"
#get root DSE object
$dse = Get-RootDse
#do work
Find-LdapObject `
    -searchFilter '(&(objeectClass=user)(objectCategory=organizationalPerson)(l=Prague))' `
    -searchBase $dse.defaultNamingContext `
    -PropertiesToLoad 'adminDescription' `
| foreach-object{$_.adminDescription = 'Prague'; $_} `
| Edit-LdapObject -IncludedProps 'adminDescription' -Passthrough `
| Find-LdapObject -searchFilter '(objectClass=*)' -searchScope Base -PropertiesToLoad 'adminDescription'

Description
-----------
This sample demontrates pipeline capabilities of various commands by updating an attribute value on many objects and reading updated objects from server

.LINK
More about System.DirectoryServices.Protocols: http://msdn.microsoft.com/en-us/library/bb332056.aspx

#>
    Param (
        [parameter(Mandatory = $true, ValueFromPipeline=$true)]
        [PSObject]
            #Source object to copy properties from
        $Object,

        [parameter()]
        [String[]]
            #Properties to ignore on source object. If not specified, no props are ignored
        $IgnoredProps=@(),

        [parameter()]
        [String[]]
            #Properties to include on source object. If not specified, all props are included
        $IncludedProps=@(),

        [parameter(Mandatory = $false)]
        [String[]]
            #List of properties that we want to handle as byte stream.
            #Note: Those properties must also be present in IncludedProps parameter. Properties not listed here are handled as strings
            #Default: empty list, which means that all properties are handled as strings
        $BinaryProps=@(),

        [parameter()]
        [System.DirectoryServices.Protocols.LdapConnection]
            #Existing LDAPConnection object.
        $LdapConnection = $script:LdapConnection,

        [parameter(Mandatory=$false)]
        [System.DirectoryServices.Protocols.DirectoryAttributeOperation]
            #Mode of operation
            #Replace: Replaces attribute values on target
            #Add: Adds attribute values to existing values on target
            #Delete: Removes atribute values from existing values on target
        $Mode=[System.DirectoryServices.Protocols.DirectoryAttributeOperation]::Replace,

        [parameter(Mandatory = $false)]
        [System.DirectoryServices.Protocols.DirectoryControl[]]
            #Additional controls that caller may need to add to request
        $AdditionalControls=@(),

        [parameter(Mandatory = $false)]
        [timespan]
            #Time before request times out.
            #Default: [TimeSpan]::Zero, which means that no specific timeout provided
        $Timeout = [TimeSpan]::Zero,

        [switch]
            #When turned on, command does not allow permissive modify and returns error if adding value to cllection taht's already there, or deleting value that's not there
            #when not specified, permisisve modify is enabled on the request
            $NoPermissiveModify,

        [Switch]
            #When turned on, command returns modified object to pipeline
            #This is useful when different types of modifications need to be done on single object
        $Passthrough
    )

    begin
    {
        EnsureLdapConnection -LdapConnection $LdapConnection
    }

    Process
    {
        if([string]::IsNullOrEmpty($Object.DistinguishedName)) {
            throw (new-object System.ArgumentException("Input object missing DistinguishedName property"))
        }

        [System.DirectoryServices.Protocols.ModifyRequest]$rqMod=new-object System.DirectoryServices.Protocols.ModifyRequest
        $rqMod.DistinguishedName=$Object.DistinguishedName.ToString()
        #only add perfmissive modify control if allowed
        if($NoPermissiveModify -eq $false) {
            $permissiveModifyRqc = new-object System.DirectoryServices.Protocols.PermissiveModifyControl
            $permissiveModifyRqc.IsCritical = $false
            $rqMod.Controls.Add($permissiveModifyRqc) | Out-Null
        }

        #add additional controls that caller may have passed
        foreach($ctrl in $AdditionalControls) {$rqMod.Controls.Add($ctrl) | Out-Null}

        foreach($prop in (Get-Member -InputObject $Object -MemberType NoteProperty)) {
            if($prop.Name -eq "distinguishedName") {continue} #Dn is always ignored
            if($IgnoredProps -contains $prop.Name) {continue}
            if(($IncludedProps.Count -gt 0) -and ($IncludedProps -notcontains $prop.Name)) {continue}
            [System.DirectoryServices.Protocols.DirectoryAttribute]$propMod=new-object System.DirectoryServices.Protocols.DirectoryAttributeModification
            $transform = $script:RegisteredTransforms[$prop.Name]
            $binaryInput = ($null -ne $transform -and $transform.BinaryInput -eq $true) -or ($prop.Name -in $BinaryProps)
            $propMod.Name=$prop.Name

            if($null -ne $transform -and $null -ne $transform.OnSave) {
                #transform defined -> transform to form accepted by directory
                $attrVal = @(& $transform.OnSave -Values $Object.($prop.Name))
            }
            else {
                #no transform defined - take value as-is
                $attrVal = $Object.($prop.Name)
            }

            if($null -ne $attrVal) {
                #we're modifying property
                if($attrVal.Count -gt 0) {
                    $propMod.Operation=$Mode
                    if($binaryInput)  {
                        foreach($val in $attrVal) {
                            $propMod.Add([byte[]]$val) | Out-Null
                        }
                    } else {
                        $propMod.AddRange([string[]]($attrVal))
                    }
                    $rqMod.Modifications.Add($propMod) | Out-Null
                }
            } else {
                #source object has no value for property - we're removing value on target
                $propMod.Operation=[System.DirectoryServices.Protocols.DirectoryAttributeOperation]::Delete
                $rqMod.Modifications.Add($propMod) | Out-Null
            }
        }
        if($rqMod.Modifications.Count -gt 0) {
            if($Timeout -ne [TimeSpan]::Zero)
            {
                $LdapConnection.SendRequest($rqMod, $Timeout) -as [System.DirectoryServices.Protocols.ModifyResponse] | Out-Null
            }
            else
            {
                $LdapConnection.SendRequest($rqMod) -as [System.DirectoryServices.Protocols.ModifyResponse] | Out-Null
            }
        }
        #if requested, pass the objeect to pipeline for further processing
        if($Passthrough) {$Object}
    }
}
