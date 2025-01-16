Function Add-LdapObject
{
<#
.SYNOPSIS
    Creates a new object in LDAP server

.DESCRIPTION
    Creates a new object in LDAP server.
    Optionally performs attribute transforms registered for Save action before saving changes

.OUTPUTS
    Nothing

.EXAMPLE
$obj = [PSCustomObject]@{distinguishedName=$null; objectClass=$null; sAMAccountName=$null; unicodePwd=$null; userAccountControl=0}
$obj.DistinguishedName = "cn=user1,cn=users,dc=mydomain,dc=com"
$obj.sAMAccountName = "User1"
$obj.ObjectClass = "User"
$obj.unicodePwd = "P@ssw0rd"
$obj.userAccountControl = "512"

$Ldap = Get-LdapConnection -LdapServer "mydc.mydomain.com" -EncryptionType Kerberos
Register-LdapAttributeTransform -name UnicodePwd -AttributeName unicodePwd
Add-LdapObject -LdapConnection $Ldap -Object $obj -BinaryProps unicodePwd

Description
-----------
Creates new user account in domain.
Password is transformed to format expected by LDAP services by registered attribute transform

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
            #Properties to ignore on source object
        $IgnoredProps=@(),

        [parameter(Mandatory = $false)]
        [String[]]
            #List of properties that we want to handle as byte stream.
            #Note: Properties not listed here are handled as strings
            #Default: empty list, which means that all properties are handled as strings
        $BinaryProps=@(),

        [parameter()]
        [System.DirectoryServices.Protocols.LdapConnection]
            #Existing LDAPConnection object.
        $LdapConnection = $script:LdapConnection,

        [parameter(Mandatory = $false)]
        [System.DirectoryServices.Protocols.DirectoryControl[]]
            #Additional controls that caller may need to add to request
        $AdditionalControls=@(),

        [parameter(Mandatory = $false)]
        [Timespan]
            #Time before connection times out.
            #Default: [TimeSpan]::Zero, which means that no specific timeout provided
        $Timeout = [TimeSpan]::Zero,

        [Switch]
            #When turned on, command returns created object to pipeline
            #This is useful when further processing needed on object
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
        [System.DirectoryServices.Protocols.AddRequest]$rqAdd=new-object System.DirectoryServices.Protocols.AddRequest
        $rqAdd.DistinguishedName=$Object.DistinguishedName.ToString()

        #add additional controls that caller may have passed
        foreach($ctrl in $AdditionalControls) {$rqAdd.Controls.Add($ctrl) | Out-Null}

        foreach($prop in (Get-Member -InputObject $Object -MemberType NoteProperty)) {
            if($prop.Name -eq "distinguishedName") {continue}
            if($IgnoredProps -contains $prop.Name) {continue}
            [System.DirectoryServices.Protocols.DirectoryAttribute]$propAdd=new-object System.DirectoryServices.Protocols.DirectoryAttribute
            $transform = $script:RegisteredTransforms[$prop.Name]
            $binaryInput = ($null -ne $transform -and $transform.BinaryInput -eq $true) -or ($prop.Name -in $BinaryProps)
            $propAdd.Name=$prop.Name
            
            if($null -ne $transform -and $null -ne $transform.OnSave) {
                #transform defined -> transform to form accepted by directory
                $attrVal = @(& $transform.OnSave -Values $Object.($prop.Name))
            }
            else {
                #no transform defined - take value as-is
                $attrVal = $Object.($prop.Name)
            }

            if($null -ne $attrVal)  #ignore empty props
            {
                if($binaryInput) {
                    foreach($val in $attrVal) {
                        $propAdd.Add([byte[]]$val) | Out-Null
                    }
                } else {
                    $propAdd.AddRange([string[]]($attrVal))
                }

                if($propAdd.Count -gt 0) {
                    $rqAdd.Attributes.Add($propAdd) | Out-Null
                }
            }
        }
        if($rqAdd.Attributes.Count -gt 0) {
            if($Timeout -ne [TimeSpan]::Zero)
            {
                $LdapConnection.SendRequest($rqAdd, $Timeout) -as [System.DirectoryServices.Protocols.AddResponse] | Out-Null
            }
            else {
                $LdapConnection.SendRequest($rqAdd) -as [System.DirectoryServices.Protocols.AddResponse] | Out-Null
            }
        }
        if($Passthrough)
        {
            $Object
        }
    }
}
