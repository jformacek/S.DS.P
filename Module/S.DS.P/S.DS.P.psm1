#region Public commands
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
                $response = $LdapConnection.SendRequest($rqAdd, $Timeout) -as [System.DirectoryServices.Protocols.AddResponse]
            }
            else {
                $response = $LdapConnection.SendRequest($rqAdd) -as [System.DirectoryServices.Protocols.AddResponse]
            }
            #handle failed operation that does not throw itself
            if($null -ne $response -and $response.ResultCode -ne [System.DirectoryServices.Protocols.ResultCode]::Success) {
                throw (new-object System.DirectoryServices.Protocols.LdapException(([int]$response.ResultCode), "$($rqAdd.DistinguishedName)`: $($response.ResultCode)`: $($response.ErrorMessage)", $response.ErrorMessage))
            }
        }
        if($Passthrough)
        {
            $Object
        }
    }
}
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
                $response = $LdapConnection.SendRequest($rqMod, $Timeout) -as [System.DirectoryServices.Protocols.ModifyResponse]
            }
            else
            {
                $response = $LdapConnection.SendRequest($rqMod) -as [System.DirectoryServices.Protocols.ModifyResponse]
            }
            #handle failed operation that does not throw itself
            if($null -ne $response -and $response.ResultCode -ne [System.DirectoryServices.Protocols.ResultCode]::Success) {
                throw (new-object System.DirectoryServices.Protocols.LdapException(([int]$response.ResultCode), "$($rqMod.DistinguishedName)`: $($response.ResultCode)`: $($response.ErrorMessage)", $response.ErrorMessage))
            }
        }
        #if requested, pass the objeect to pipeline for further processing
        if($Passthrough) {$Object}
    }
}
Function Find-LdapObject {
    <#
.SYNOPSIS
    Searches LDAP server in given search root and using given search filter

.DESCRIPTION
    Searches LDAP server identified by LDAP connection passed as parameter.
    Attributes of returned objects are retrieved via ranged attribute retrieval by default. This allows to retrieve all attributes, including computed ones, but has impact on performace as each attribute generated own LDAP server query. Tu turn ranged attribute retrieval off, set parameter RangeSize to zero.
    Optionally, attribute values can be transformed to complex types using transform registered for an attribute with 'Load' action.

.OUTPUTS
    Search results as PSCustomObjects with requested properties as strings, byte streams or complex types produced by transforms

.EXAMPLE
Find-LdapObject -LdapConnection [string]::Empty -SearchFilter:"(&(sn=smith)(objectClass=user)(objectCategory=organizationalPerson))" -SearchBase:"cn=Users,dc=myDomain,dc=com"

Description
-----------
This command connects to domain controller of caller's domain on port 389 and performs the search

.EXAMPLE
$Ldap = Get-LdapConnection
Find-LdapObject -LdapConnection $Ldap -SearchFilter:'(&(cn=jsmith)(objectClass=user)(objectCategory=organizationalPerson))' -SearchBase:'ou=Users,dc=myDomain,dc=com' -PropertiesToLoad:@('sAMAccountName','objectSid') -BinaryProps:@('objectSid')

Description
-----------
This command connects to to domain controller of caller's domain and performs the search, returning value of objectSid attribute as byte stream

.EXAMPLE
$Ldap = Get-LdapConnection -LdapServer:mydc.mydomain.com -EncryptionType:SSL
Find-LdapObject -LdapConnection $Ldap -SearchFilter:"(&(sn=smith)(objectClass=user)(objectCategory=organizationalPerson))" -SearchBase:"ou=Users,dc=myDomain,dc=com"

Description
-----------
This command connects to given LDAP server and performs the search via SSL

.EXAMPLE
$Ldap = Get-LdapConnection -LdapServer "mydc.mydomain.com"

Find-LdapObject -LdapConnection:$Ldap -SearchFilter:"(&(sn=smith)(objectClass=user)(objectCategory=organizationalPerson))" -SearchBase:"cn=Users,dc=myDomain,dc=com"

Find-LdapObject -LdapConnection:$Ldap -SearchFilter:"(&(cn=myComputer)(objectClass=computer)(objectCategory=organizationalPerson))" -SearchBase:"ou=Computers,dc=myDomain,dc=com" -PropertiesToLoad:@("cn","managedBy")

Description
-----------
This command creates the LDAP connection object and passes it as parameter. Connection remains open and ready for reuse in subsequent searches

.EXAMPLE
Get-LdapConnection -LdapServer "mydc.mydomain.com" | Out-Null

$Dse = Get-RootDse

Find-LdapObject -SearchFilter:"(&(sn=smith)(objectClass=user)(objectCategory=organizationalPerson))" -SearchBase:"cn=Users,dc=myDomain,dc=com"

Find-LdapObject -SearchFilter:"(&(cn=myComputer)(objectClass=computer)(objectCategory=organizationalPerson))" -SearchBase:"ou=Computers,dc=myDomain,dc=com" -PropertiesToLoad:@("cn","managedBy")

Description
-----------
This command creates the LDAP connection object and stores it in session variable. Following commands take the connection information from session variable, so the connection object does not need to be passed from command line.

.EXAMPLE
$Ldap = Get-LdapConnection -LdapServer "mydc.mydomain.com"
Find-LdapObject -LdapConnection:$Ldap -SearchFilter:"(&(cn=SEC_*)(objectClass=group)(objectCategory=group))" -SearchBase:"cn=Groups,dc=myDomain,dc=com" | `
Find-LdapObject -LdapConnection:$Ldap -ASQ:"member" -SearchScope:"Base" -SearchFilter:"(&(objectClass=user)(objectCategory=organizationalPerson))" -propertiesToLoad:@("sAMAccountName","givenName","sn") | `
Select-Object * -Unique

Description
-----------
This one-liner lists sAMAccountName, first and last name, and DN of all users who are members of at least one group whose name starts with "SEC_" string

.EXAMPLE
$Ldap = Get-LdapConnection -Credential (Get-Credential)
Find-LdapObject -LdapConnection $Ldap -SearchFilter:"(&(cn=myComputer)(objectClass=computer)(objectCategory=organizationalPerson))" -SearchBase:"ou=Computers,dc=myDomain,dc=com" -PropertiesToLoad:@("cn","managedBy") -RangeSize 0

Description
-----------
This command creates explicit credential and uses it to authenticate LDAP query.
Then command retrieves data without ranged attribute value retrieval.

.EXAMPLE
$Users = Find-LdapObject -LdapConnection (Get-LdapConnection) -SearchFilter:"(&(sn=smith)(objectClass=user)(objectCategory=organizationalPerson))" -SearchBase:"cn=Users,dc=myDomain,dc=com" -AdditionalProperties:@("Result")
foreach($user in $Users)
{
    try
    {
        #do some processing
        $user.Result="OK"
    }
    catch
    {
        #report processing error
        $user.Result=$_.Exception.Message
    }
}
#report users with results of processing for each of them
$Users

Description
-----------
This command connects to domain controller of caller's domain on port 389 and performs the search.
For each user found, it also defines 'Result' property on returned object. Property is later used to store result of processing on user account

.EXAMPLE
$Ldap = Get-LdapConnection -LdapServer:ldap.mycorp.com -AuthType:Anonymous
Find-LdapObject -LdapConnection $ldap -SearchFilter:"(&(sn=smith)(objectClass=user)(objectCategory=organizationalPerson))" -SearchBase:"ou=People,ou=mycorp,o=world"

Description
-----------
This command connects to given LDAP server and performs the search anonymously.

.EXAMPLE
$Ldap = Get-LdapConnection -LdapServer:ldap.mycorp.com
$dse = Get-RootDSE -LdapConnection $conn
Find-LdapObject -LdapConnection $ldap -SearchFilter:"(&(objectClass=user)(objectCategory=organizationalPerson))" -SearchBase:"ou=People,ou=mycorp,o=world" -PropertiesToLoad *

Description
-----------
This command connects to given LDAP server and performs the direct search, retrieving all properties with value from objects found by search

.EXAMPLE
$Ldap = Get-LdapConnection -LdapServer:ldap.mycorp.com
$dse = Get-RootDSE -LdapConnection $conn
Find-LdapObject -LdapConnection $ldap -SearchFilter:"(&(objectClass=group)(objectCategory=group)(cn=MyVeryLargeGroup))" -SearchBase:"ou=People,ou=mycorp,o=world" -PropertiesToLoad member -RangeSize 1000

Description
-----------
This command connects to given LDAP server on default port with Negotiate authentication
Next commands use the connection to get Root DSE object and list of all members of a group, using ranged retrieval ("paging support on LDAP attributes")

.EXAMPLE
$creds=Get-Credential -UserName 'CN=MyUser,CN=Users,DC=mydomain,DC=com' -Message 'Enter password to user with this DN' -Title 'Password needed'
Get-LdapConnection -LdapServer dc.mydomain.com -Port 636 -AuthType Basic -Credential $creds | Out-Null
$dse = Get-RootDSE

Description
-----------
This command connects to given LDAP server with simple bind over TLS (TLS needed for basic authentication), storing the connection in session variable.
Next command uses connection from session variable to get Root DSE object.
Usage of Basic authentication is typically way to go on client platforms that do not support other authentication schemes, such as Negotiate

.EXAMPLE
Get-LdapConnection -LdapServer dc.mydomain.com | Out-Null
$dse = Get-RootDSE
#obtain initial sync cookie valid from now on
Find-LdapObject -searchBase $dse.defaultNamingContext -searchFilter '(objectClass=domainDns)' -PropertiesToLoad 'name' -DirSync Standard | Out-Null
$show the cookie
Get-LdapDirSyncCookie

Description
-----------
This command connects to given LDAP server and obtains initial cookie that represents current time - output does not contain full sync.

.LINK
More about System.DirectoryServices.Protocols: http://msdn.microsoft.com/en-us/library/bb332056.aspx
#>
    Param (
        [parameter()]
        [System.DirectoryServices.Protocols.LdapConnection]
            #existing LDAPConnection object retrieved with cmdlet Get-LdapConnection
            #When we perform many searches, it is more effective to use the same connection rather than create new connection for each search request.
        $LdapConnection = $script:LdapConnection,

        [parameter(Mandatory = $true)]
        [String]
            #Search filter in LDAP syntax
        $searchFilter,

        [parameter(Mandatory = $false, ValueFromPipeline=$true)]
        [Object]
            #DN of container where to search
        $searchBase,

        [parameter(Mandatory = $false)]
        [System.DirectoryServices.Protocols.SearchScope]
            #Search scope
            #Ignored for DirSync searches
            #Default: Subtree
        $searchScope='Subtree',

        [parameter(Mandatory = $false)]
        [String[]]
            #List of properties we want to return for objects we find.
            #Default: empty array, meaning no properties are returned
        $PropertiesToLoad=@(),

        [parameter(Mandatory = $false)]
        [String]
            #Name of attribute for Attribite Scoped Query (ASQ)
            #Note: searchScope must be set to Base for ASQ
            #Note: #Ignored for DirSync searches
            #Default: empty string
        $ASQ,

        [parameter(Mandatory = $false)]
        [UInt32]
            #Page size for paged search. Zero means that paging is disabled
            #Ignored for DirSync searches
            #Default: 500
        $PageSize=500,

        [parameter(Mandatory = $false)]
        [Int32]
            # Specification of attribute value retrieval mode
            # Negative value means that attribute values are loaded directly with list of objects
            # Zero means that ranged attribute value retrieval is disabled and attribute values are returned in single request.
            # Positive value  means that each attribute value is loaded in dedicated requests in batches of given size. Usable for loading of group members
            # Ignored for DirSync searches
            # Note: Default in query policy in AD is 1500; make sure that you do not use here higher value than allowed by LDAP server
            # Default: -1 (means that ranged attribute retrieval is not used by default)
            # IMPORTANT: default changed in v2.1.1 - previously it was 1000. Changed because it typically caused large perforrmance impact when using -PropsToLoad '*'
        $RangeSize=-1,

        [parameter(Mandatory=$false)]
        [Int32]
            #Max number of results to return from the search
            #Negative number means that all available results are returned
            #Ignored for DirSync searches
        $SizeLimit = -1,
        [parameter(Mandatory = $false)]
        [alias('BinaryProperties')]
        [String[]]
            #List of properties that we want to load as byte stream.
            #Note: Those properties must also be present in PropertiesToLoad parameter. Properties not listed here are loaded as strings
            #Note: When using transform for a property, then transform "knows" if it's binary or not, so no need to specify it in BinaryProps
            #Default: empty list, which means that all properties are loaded as strings
        $BinaryProps=@(),

        [parameter(Mandatory = $false)]
        [String[]]
            <#
            List of properties that we want to be defined on output object, but we do not want to load them from AD.
            Properties listed here must NOT occur in propertiesToLoad list
            Command defines properties on output objects and sets the value to $null
            Good for having output object with all props that we need for further processing, so we do not need to add them ourselves
            Default: empty list, which means that we don't want any additional propertis defined on output object
            #>
        $AdditionalProperties=@(),

        [parameter()]
        [String[]]
            #Properties to ignore when loading objects from LDAP
            #Default: empty list, which means that no properties are ignored
        $IgnoredProperties=@(),

        [parameter(Mandatory = $false)]
        [System.DirectoryServices.Protocols.DirectoryControl[]]
            #additional controls that caller may need to add to request
        $AdditionalControls=@(),

        [parameter(Mandatory = $false)]
        [Timespan]
            #Number of seconds before request times out.
            #Default: [TimeSpan]::Zero, which means that no specific timeout provided
        $Timeout = [TimeSpan]::Zero,

        [Parameter(Mandatory=$false)]
        [ValidateSet('None','Standard','ObjectSecurity','StandardIncremental','ObjectSecurityIncremental')]
        [string]
            #whether to issue search with DirSync. Allowed options:
            #None: Standard searxh without DirSync
            #Standard: Dirsync search using standard permisions of caller. Requires Replicate Directory Changes permission
            #ObjectSecurity: DirSync search using Replicate Direcory Changes permission that reveals object that caller normally does not have permission to see. Requires Requires Replicate Directory Changes All permission
            #Note: When Standard or ObjectSecurity specified, searchBase must be set to root of directory partition
            #For specs, see https://docs.microsoft.com/en-us/openspecs/windows_protocols/MS-ADTS/2213a7f2-0a36-483c-b2a4-8574d53aa1e3
            #Default: None, which means search without DirSync
        $DirSync = 'None',

        [Switch]
            #Whether to alphabetically sort attributes on returned objects
        $SortAttributes
    )

    Begin
    {
        EnsureLdapConnection -LdapConnection $LdapConnection
        Function PostProcess {
            param
            (
                [Parameter(ValueFromPipeline)]
                [System.Collections.Hashtable]$data,
                [bool]$Sort
            )
    
            process
            {
                #Flatten
                $coll=@($data.Keys)
                foreach($prop in $coll) {
                    $data[$prop] = [Flattener]::FlattenArray($data[$prop])
                    <#
                    #support for DirSync struct for Add/Remove values of multival props
                    if($data[$prop] -is [System.Collections.Hashtable])
                    {
                        $data[$prop] = [pscustomobject]$data[$prop]
                    }
                    #>
                }
                if($Sort)
                {
                    #flatten and sort attributes
                    $coll=@($coll | Sort-Object)
                    $sortedData=[ordered]@{}
                    foreach($prop in $coll) {$sortedData[$prop] = $data[$prop]}
                    #return result to pipeline
                    [PSCustomObject]$sortedData
                }
                else {
                    [PSCustomObject]$data
                }
            }
        }
    
        #remove unwanted props
        $PropertiesToLoad=@($propertiesToLoad | where-object {$_ -notin @('distinguishedName','1.1')})
        #if asterisk in list of props to load, load all props available on object despite of  required list
        if($propertiesToLoad.Count -eq 0) {$NoAttributes=$true} else {$NoAttributes=$false}
        if('*' -in $PropertiesToLoad) {$PropertiesToLoad=@()}

        #configure LDAP connection
        #preserve original value of referral chasing
        $referralChasing = $LdapConnection.SessionOptions.ReferralChasing
        if($pageSize -gt 0) {
            #paged search silently fails in AD when chasing referrals
            $LdapConnection.SessionOptions.ReferralChasing="None"
        }
    }

    Process {
        #build request
        $rq=new-object System.DirectoryServices.Protocols.SearchRequest

        #search base
        #we support passing $null as SearchBase - used for Global Catalog searches
        if($null -ne $searchBase)
        {
            #we support pipelining of strings or DistinguishedName types, or objects containing distinguishedName property - string or DistinguishedName
            switch($searchBase.GetType().Name) {
                "String"
                {
                    $rq.DistinguishedName=$searchBase
                    break;
                }
                'DistinguishedName' {
                    $rq.DistinguishedName=$searchBase.ToString()
                    break;
                }
                default
                {
                    if($null -ne $searchBase.distinguishedName)
                    {
                        #covers both string and DistinguishedName types
                        $rq.DistinguishedName=$searchBase.distinguishedName.ToString()
                    }
                }
            }
        }

        #search filter in LDAP syntax
        $rq.Filter=$searchFilter


        if($DirSync -eq 'None')
        {
            #paged search control for paged search
            #for DirSync searches, paging is not used
            if($pageSize -gt 0) {
                [System.DirectoryServices.Protocols.PageResultRequestControl]$pagedRqc = new-object System.DirectoryServices.Protocols.PageResultRequestControl($pageSize)
                #asking server for best effort with paging
                $pagedRqc.IsCritical=$false
                $rq.Controls.Add($pagedRqc) | Out-Null
            }

            #Attribute scoped query
            #Not supported for DirSync
            if(-not [String]::IsNullOrEmpty($asq)) {
                [System.DirectoryServices.Protocols.AsqRequestControl]$asqRqc=new-object System.DirectoryServices.Protocols.AsqRequestControl($ASQ)
                $rq.Controls.Add($asqRqc) | Out-Null
            }

            #search scope
            $rq.Scope=$searchScope

            #size limit
            if($SizeLimit -gt 0)
            {
                $rq.SizeLimit = $SizeLimit
            }
        }
        else {
            #specifics for DirSync searches

            #only supported scope is subtree
            $rq.Scope = 'Subtree'

            #Windows AD/LDS server always returns objectGuid for DirSync.
            #We do not want to hide it, we just make sure it is returned in proper format
            if('objectGuid' -notin $BinaryProps)
            {
                $BinaryProps+='objectGuid'
            }
        }

        #add additional controls that caller may have passed
        foreach($ctrl in $AdditionalControls) {$rq.Controls.Add($ctrl) | Out-Null}

        if($Timeout -ne [timespan]::Zero)
        {
            #server side timeout
            $rq.TimeLimit=$Timeout
        }

        switch($DirSync)
        {
            'None' {
                #standard search
                if($NoAttributes)
                {
                    #just run as fast as possible when not loading any attribs
                    GetResultsDirectlyInternal -rq $rq -conn $LdapConnection -PropertiesToLoad $PropertiesToLoad -AdditionalProperties $AdditionalProperties -IgnoredProperties $IgnoredProperties -BinaryProperties $BinaryProps -Timeout $Timeout -NoAttributes | PostProcess
                }
                else {
                    #load attributes according to desired strategy
                    switch($RangeSize)
                    {
                        {$_ -lt 0} {
                            #directly via single ldap call
                            #some attribs may not be loaded (e.g. computed)
                            GetResultsDirectlyInternal -rq $rq -conn $LdapConnection -PropertiesToLoad $PropertiesToLoad -AdditionalProperties $AdditionalProperties -IgnoredProperties $IgnoredProperties -BinaryProperties $BinaryProps -Timeout $Timeout | PostProcess -Sort $SortAttributes
                            break
                        }
                        0 {
                            #query attributes for each object returned using base search
                            #but not using ranged retrieval, so multivalued attributes with many values may not be returned completely
                            GetResultsIndirectlyInternal -rq $rq -conn $LdapConnection -PropertiesToLoad $PropertiesToLoad -AdditionalProperties $AdditionalProperties -IgnoredProperties $IgnoredProperties -AdditionalControls $AdditionalControls -BinaryProperties $BinaryProps -Timeout $Timeout | PostProcess -Sort $SortAttributes
                            break
                        }
                        {$_ -gt 0} {
                            #query attributes for each object returned using base search and each attribute value with ranged retrieval
                            #so even multivalued attributes with many values are returned completely
                            GetResultsIndirectlyRangedInternal -rq $rq -conn $LdapConnection -PropertiesToLoad $PropertiesToLoad -AdditionalProperties $AdditionalProperties -IgnoredProperties $IgnoredProperties -AdditionalControls $AdditionalControls -BinaryProperties $BinaryProps -Timeout $Timeout -RangeSize $RangeSize | PostProcess -Sort $SortAttributes
                            break
                        }
                    }
                }
                break;
            }
            'Standard' {
                GetResultsDirSyncInternal -rq $rq -conn $LdapConnection -PropertiesToLoad $PropertiesToLoad -AdditionalProperties $AdditionalProperties -IgnoredProperties $IgnoredProperties -BinaryProperties $BinaryProps -Timeout $Timeout | PostProcess -Sort $SortAttributes
                break;
            }
            'ObjectSecurity' {
                GetResultsDirSyncInternal -rq $rq -conn $LdapConnection -PropertiesToLoad $PropertiesToLoad -AdditionalProperties $AdditionalProperties -IgnoredProperties $IgnoredProperties -BinaryProperties $BinaryProps -Timeout $Timeout -ObjectSecurity | PostProcess -Sort $SortAttributes
                break;
            }
            'StandardIncremental' {
                GetResultsDirSyncInternal -rq $rq -conn $LdapConnection -PropertiesToLoad $PropertiesToLoad -AdditionalProperties $AdditionalProperties -IgnoredProperties $IgnoredProperties -BinaryProperties $BinaryProps -Timeout $Timeout -Incremental | PostProcess -Sort $SortAttributes
                break;
            }
            'ObjectSecurityIncremental' {
                GetResultsDirSyncInternal -rq $rq -conn $LdapConnection -PropertiesToLoad $PropertiesToLoad -AdditionalProperties $AdditionalProperties -IgnoredProperties $IgnoredProperties -BinaryProperties $BinaryProps -Timeout $Timeout -ObjectSecurity -Incremental | PostProcess -Sort $SortAttributes
                break;
            }
        }
    }

    End
    {
        if(($pageSize -gt 0) -and ($null -ne $ReferralChasing)) {
            #revert to original value of referral chasing on connection
            $LdapConnection.SessionOptions.ReferralChasing=$ReferralChasing
        }
    }
}
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
Function Get-LdapConnection
{
<#
.SYNOPSIS
    Connects to LDAP server and returns LdapConnection object

.DESCRIPTION
    Creates connection to LDAP server according to parameters passed. 
    Stores retured LdapConnection object to module cache where other commands look for it when they do not receive connection from parameter.
.OUTPUTS
    LdapConnection object

.EXAMPLE
Get-LdapConnection -LdapServer "mydc.mydomain.com" -EncryptionType Kerberos

Description
-----------
Returns LdapConnection for caller's domain controller, with active Kerberos Encryption for data transfer security

.EXAMPLE
Get-LdapConnection -LdapServer "mydc.mydomain.com" -EncryptionType Kerberos -Credential (Get-AdmPwdCredential)

Description
-----------
Returns LdapConnection for caller's domain controller, with active Kerberos Encryption for data transfer security, authenticated by automatically retrieved password from AdmPwd.E client

.EXAMPLE
$thumb = '059d5318118e61fe54fd361ae07baf4644a67347'
$cert = (dir Cert:\CurrentUser\my).Where{$_.Thumbprint -eq $Thumb}[0]
Get-LdapConnection -LdapServer "mydc.mydomain.com" -Port 636 -CertificateValidationFlags ([System.Security.Cryptography.X509Certificates.X509VerificationFlags]::AllowUnknownCertificateAuthority) -ClientCertificate $cert

Description
-----------
Returns LdapConnection over SSL for given LDAP server, authenticated by a client certificate and allowing LDAP server to use self-signed certificate
.LINK
More about System.DirectoryServices.Protocols: http://msdn.microsoft.com/en-us/library/bb332056.aspx
#>
    Param
    (
        [parameter(Mandatory = $false)]
        [String[]]
            #LDAP server name
            #Default: default server given by environment
        $LdapServer=[String]::Empty,

        [parameter(Mandatory = $false)]
        [Int32]
            #LDAP server port
            #Default: 389
        $Port=389,

        [parameter(Mandatory = $false)]
        [PSCredential]
            #Use different credentials when connecting
        $Credential=$null,

        [parameter(Mandatory = $false)]
        [ValidateSet('None','TLS','SSL','Kerberos')]
        [string]
            #Type of encryption to use.
        $EncryptionType='None',

        [Switch]
            #enable support for Fast Concurrent Bind
        $FastConcurrentBind,

        [Switch]
        #enable support for UDP transport
        $ConnectionLess,

        [parameter(Mandatory = $false)]
        [Timespan]
            #Time before connection times out.
            #Default: 120 seconds
        $Timeout = [TimeSpan]::Zero,

        [Parameter(Mandatory = $false)]
        [System.DirectoryServices.Protocols.AuthType]
            #The type of authentication to use with the LdapConnection
        $AuthType,

        [Parameter(Mandatory = $false)]
        [int]
            #Requested LDAP protocol version
        $ProtocolVersion = 3,

        [Parameter(Mandatory = $false)]
        [System.Security.Cryptography.X509Certificates.X509VerificationFlags]
            #Requested LDAP protocol version
        $CertificateValidationFlags = 'NoFlag',

        [Parameter(Mandatory = $false)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]
            #Client certificate used for authenticcation instead of credentials
            #See https://docs.microsoft.com/en-us/windows/win32/api/winldap/nc-winldap-queryclientcert
        $ClientCertificate
    )

    Begin
    {
        if($null -eq $script:ConnectionParams)
        {
            $script:ConnectionParams=@{}
        }
    }
    Process
    {

        $FullyQualifiedDomainName=$false;
        [System.DirectoryServices.Protocols.LdapDirectoryIdentifier]$di=new-object System.DirectoryServices.Protocols.LdapDirectoryIdentifier($LdapServer, $Port, $FullyQualifiedDomainName, $ConnectionLess)

        if($null -ne $Credential)
        {
            $LdapConnection=new-object System.DirectoryServices.Protocols.LdapConnection($di, $Credential.GetNetworkCredential())
        }
        else 
        {
            $LdapConnection=new-object System.DirectoryServices.Protocols.LdapConnection($di)
        }
        $LdapConnection.SessionOptions.ProtocolVersion=$ProtocolVersion

        
        #store connection params for each server in global variable, so as it is reachable from callback scriptblocks
        $connectionParams=@{}
        foreach($server in $LdapServer) {$script:ConnectionParams[$server]=$connectionParams}
        if($CertificateValidationFlags -ne 'NoFlag')
        {
            $connectionParams['ServerCertificateValidationFlags'] = $CertificateValidationFlags
            #server certificate validation callback
            $LdapConnection.SessionOptions.VerifyServerCertificate = { 
                param(
                    [Parameter(Mandatory)][DirectoryServices.Protocols.LdapConnection]$LdapConnection,
                    [Parameter(Mandatory)][Security.Cryptography.X509Certificates.X509Certificate2]$Certificate
                )
                Write-Verbose "Validating server certificate $($Certificate.Subject) with thumbprint $($Certificate.Thumbprint) and issuer $($Certificate.Issuer)"
                [System.Security.Cryptography.X509Certificates.X509Chain] $chain = new-object System.Security.Cryptography.X509Certificates.X509Chain
                foreach($server in $LdapConnection.Directory.Servers)
                {
                    if($server -in $script:ConnectionParams.Keys)
                    {
                        $connectionParam=$script:ConnectionParams[$server]
                        if($null -ne $connectionParam['ServerCertificateValidationFlags'])
                        {
                            $chain.ChainPolicy.VerificationFlags = $connectionParam['ServerCertificateValidationFlags']
                            break;
                        }
                    }
                }
                $result = $chain.Build($Certificate)
                return $result
            }
        }
        
        if($null -ne $ClientCertificate)
        {
            $connectionParams['ClientCertificate'] = $ClientCertificate
            #client certificate retrieval callback
            #we just support explicit certificate now
            $LdapConnection.SessionOptions.QueryClientCertificate = { param(
                [Parameter(Mandatory)][DirectoryServices.Protocols.LdapConnection]$LdapConnection,
                [Parameter(Mandatory)][byte[][]]$TrustedCAs
            )
                $clientCert = $null
                foreach($server in $LdapConnection.Directory.Servers)
                {
                    if($server -in $script:ConnectionParams.Keys)
                    {
                        $connectionParam=$script:ConnectionParams[$server]
                        if($null -ne $connectionParam['ClientCertificate'])
                        {
                            $clientCert = $connectionParam['ClientCertificate']
                            break;
                        }
                    }
                }
                if($null -ne $clientCert)
                {
                    Write-Verbose "Using client certificate $($clientCert.Subject) with thumbprint $($clientCert.Thumbprint) from issuer $($clientCert.Issuer)"
                }
                return $clientCert
            }
        }

        if ($null -ne $AuthType) {
            $LdapConnection.AuthType = $AuthType
        }


        switch($EncryptionType) {
            'None' {break}
            'TLS' {
                $LdapConnection.SessionOptions.StartTransportLayerSecurity($null)
                break
            }
            'Kerberos' {
                $LdapConnection.SessionOptions.Sealing=$true
                $LdapConnection.SessionOptions.Signing=$true
                break
            }
            'SSL' {
                $LdapConnection.SessionOptions.SecureSocketLayer=$true
                break
            }
        }
        if($Timeout -ne [TimeSpan]::Zero)
        {
            $LdapConnection.Timeout = $Timeout
        }

        if($FastConcurrentBind) {
            $LdapConnection.SessionOptions.FastConcurrentBind()
        }
        $script:LdapConnection = $LdapConnection
        $LdapConnection
     }
}
Function Get-LdapDirSyncCookie
{
<#
.SYNOPSIS
    Returns DirSync cookie serialized as Base64 string.
    Caller is responsible to save and call Set-LdapDirSyncCookie when continuing data retrieval via directory synchronization

.OUTPUTS
    DirSync cookie as Base64 string

.EXAMPLE
Get-LdapConnection -LdapServer "mydc.mydomain.com"

$dse = Get-RootDse
$cookie = Get-Content .\storedCookieFromPreviousIteration.txt
$cookie | Set-LdapDirSyncCookie
$dirUpdates=Find-LdapObject -SearchBase $dse.defaultNamingContext -searchFilter '(objectClass=group)' -PropertiesToLoad 'member' -DirSync StandardIncremental
#process updates
foreach($record in $dirUpdates)
{
    #...
}

$cookie = Get-LdapDirSyncCookie
$cookie | Set-Content  .\storedCookieFromPreviousIteration.txt

Description
----------
This example loads dirsync cookie stored in file and performs dirsync search for updates that happened after cookie was generated
Then it stores updated cookie back to file for usage in next iteration

.EXAMPLE
Get-LdapConnection -LdapServer dc.mydomain.com | Out-Null
$dse = Get-RootDSE
#obtain initial sync cookie valid from now on
Find-LdapObject -searchBase $dse.defaultNamingContext -searchFilter '(objectClass=domainDns)' -PropertiesToLoad 'name' -DirSync Standard | Out-Null
$show the cookie
Get-LdapDirSyncCookie

Description
-----------
This example connects to given LDAP server and obtains initial cookie that represents current time - output does not contain full sync data.


.LINK
More about DirSync: https://docs.microsoft.com/en-us/openspecs/windows_protocols/MS-ADTS/2213a7f2-0a36-483c-b2a4-8574d53aa1e3

#>
param()

    process
    {
        if($null -ne $script:DirSyncCookie)
        {
            [Convert]::ToBase64String($script:DirSyncCookie)
        }
    }
}
Function Get-RootDSE {
    <#
    .SYNOPSIS
        Connects to LDAP server and retrieves metadata
    
    .DESCRIPTION
        Retrieves LDAP server metadata from Root DSE object
        Current implementation is specialized to metadata foung on Windows LDAP server, so on other platforms, some metadata may be empty.
        Or other platforms may publish interesting metadata not available on Windwos LDAP - feel free to add here
    
    .OUTPUTS
        Custom object containing information about LDAP server
    
    .EXAMPLE
    Get-LdapConnection | Get-RootDSE
    
    Description
    -----------
    This command connects to closest domain controller of caller's domain on port 389 and returns metadata about the server
    
    .EXAMPLE
    #connect to server and authenticate with client certificate
    $thumb = '059d5318118e61fe54fd361ae07baf4644a67347'
    cert = (dir Cert:\CurrentUser\my).Where{$_.Thumbprint -eq $Thumb}[0]
    Get-LdapConnection -LdapServer "mydc.mydomain.com" `
      -Port 636 `
      -ClientCertificate $cert `
      -CertificateValidationFlags [System.Security.Cryptography.X509Certificates.X509VerificationFlags]::IgnoreRootRevocationUnknown
    
    Description
    -----------
    Gets Ldap connection authenticated by client certificate authentication and allowing server certificate from CA with unavailable CRL.
    
    .LINK
    More about System.DirectoryServices.Protocols: http://msdn.microsoft.com/en-us/library/bb332056.aspx
    #>
    
    Param (
        [parameter(ValueFromPipeline = $true)]
        [System.DirectoryServices.Protocols.LdapConnection]
            #existing LDAPConnection object retrieved via Get-LdapConnection
            #When we perform many searches, it is more effective to use the same connection rather than create new connection for each search request.
        $LdapConnection = $script:LdapConnection
    )
    Begin
    {
        EnsureLdapConnection -LdapConnection $LdapConnection

        #initialize output objects via hashtable --> faster than add-member
        #create default initializer beforehand
        $propDef=[ordered]@{`
            rootDomainNamingContext=$null; configurationNamingContext=$null; schemaNamingContext=$null; `
            'defaultNamingContext'=$null; 'namingContexts'=$null; `
            'dnsHostName'=$null; 'ldapServiceName'=$null; 'dsServiceName'=$null; 'serverName'=$null;`
            'supportedLdapPolicies'=$null; 'supportedSASLMechanisms'=$null; 'supportedControl'=$null; 'supportedConfigurableSettings'=$null; `
            'currentTime'=$null; 'highestCommittedUSN' = $null; 'approximateHighestInternalObjectID'=$null; `
            'dsSchemaAttrCount'=$null; 'dsSchemaClassCount'=$null; 'dsSchemaPrefixCount'=$null; `
            'isGlobalCatalogReady'=$null; 'isSynchronized'=$null; 'pendingPropagations'=$null; `
            'domainControllerFunctionality' = $null; 'domainFunctionality'=$null; 'forestFunctionality'=$null; `
            'subSchemaSubEntry'=$null; `
            'msDS-ReplAllInboundNeighbors'=$null; 'msDS-ReplConnectionFailures'=$null; 'msDS-ReplLinkFailures'=$null; 'msDS-ReplPendingOps'=$null; `
            'dsaVersionString'=$null; 'serviceAccountInfo'=$null; 'LDAPPoliciesEffective'=$null `
        }
    }
    Process {

        #build request
        $rq=new-object System.DirectoryServices.Protocols.SearchRequest
        $rq.Scope =  [System.DirectoryServices.Protocols.SearchScope]::Base
        $rq.Attributes.AddRange($propDef.Keys) | Out-Null

        #try to get extra information with ExtendedDNControl
        #RFC4511: Server MUST ignore unsupported controls marked as not critical
        [System.DirectoryServices.Protocols.ExtendedDNControl]$exRqc = new-object System.DirectoryServices.Protocols.ExtendedDNControl('StandardString')
        $exRqc.IsCritical=$false
        $rq.Controls.Add($exRqc) | Out-Null

        try {
            $rsp=$LdapConnection.SendRequest($rq)
        }
        catch {
            throw $_.Exception
            return
        }
        #if there was error, let the exception go to caller and do not continue

        #sometimes server does not return anything if we ask for property that is not supported by protocol
        if($rsp.Entries.Count -eq 0) {
            return;
        }

        $data=[PSCustomObject]$propDef

        if ($rsp.Entries[0].Attributes['configurationNamingContext']) {
            $data.configurationNamingContext = [NamingContext]::Parse($rsp.Entries[0].Attributes['configurationNamingContext'].GetValues([string])[0])
        }
        if ($rsp.Entries[0].Attributes['schemaNamingContext']) {
            $data.schemaNamingContext = [NamingContext]::Parse(($rsp.Entries[0].Attributes['schemaNamingContext'].GetValues([string]))[0])
        }
        if ($rsp.Entries[0].Attributes['rootDomainNamingContext']) {
            $data.rootDomainNamingContext = [NamingContext]::Parse($rsp.Entries[0].Attributes['rootDomainNamingContext'].GetValues([string])[0])
        }
        if ($rsp.Entries[0].Attributes['defaultNamingContext']) {
            $data.defaultNamingContext = [NamingContext]::Parse($rsp.Entries[0].Attributes['defaultNamingContext'].GetValues([string])[0])
        }
        if($null -ne $rsp.Entries[0].Attributes['approximateHighestInternalObjectID']) {
            try {
                $data.approximateHighestInternalObjectID=[long]::Parse($rsp.Entries[0].Attributes['approximateHighestInternalObjectID'].GetValues([string]))
            }
            catch {
                #it isn't a numeric, just return what's stored without parsing
                $data.approximateHighestInternalObjectID=$rsp.Entries[0].Attributes['approximateHighestInternalObjectID'].GetValues([string])
            }
        }
        if($null -ne $rsp.Entries[0].Attributes['highestCommittedUSN']) {
            try {
                $data.highestCommittedUSN=[long]::Parse($rsp.Entries[0].Attributes['highestCommittedUSN'].GetValues([string]))
            }
            catch {
                #it isn't a numeric, just return what's stored without parsing
                $data.highestCommittedUSN=$rsp.Entries[0].Attributes['highestCommittedUSN'].GetValues([string])
            }
        }
        if($null -ne $rsp.Entries[0].Attributes['currentTime']) {
            $val = ($rsp.Entries[0].Attributes['currentTime'].GetValues([string]))[0]
            try {
                $data.currentTime = [DateTime]::ParseExact($val,'yyyyMMddHHmmss.fZ',[CultureInfo]::InvariantCulture,[System.Globalization.DateTimeStyles]::None)
            }
            catch {
                $data.currentTime=$val
            }
        }
        if($null -ne $rsp.Entries[0].Attributes['dnsHostName']) {
            $data.dnsHostName = ($rsp.Entries[0].Attributes['dnsHostName'].GetValues([string]))[0]
        }
        if($null -ne $rsp.Entries[0].Attributes['ldapServiceName']) {
            $data.ldapServiceName = ($rsp.Entries[0].Attributes['ldapServiceName'].GetValues([string]))[0]
        }
        if($null -ne $rsp.Entries[0].Attributes['dsServiceName']) {
            $val = ($rsp.Entries[0].Attributes['dsServiceName'].GetValues([string]))[0]
            if($val.Contains(';'))
            {
                $data.dsServiceName = $val.Split(';')
            }
            else {
                $data.dsServiceName=$val
            }
        }
        if($null -ne $rsp.Entries[0].Attributes['serverName']) {
            $val = ($rsp.Entries[0].Attributes['serverName'].GetValues([string]))[0]
            if($val.Contains(';'))
            {
                $data.serverName = $val.Split(';')
            }
            else {
                $data.serverName=$val
            }
        }
        if($null -ne $rsp.Entries[0].Attributes['supportedControl']) {
            $data.supportedControl = ( ($rsp.Entries[0].Attributes['supportedControl'].GetValues([string])) | Sort-Object )
        }
        if($null -ne $rsp.Entries[0].Attributes['supportedLdapPolicies']) {
            $data.supportedLdapPolicies = ( ($rsp.Entries[0].Attributes['supportedLdapPolicies'].GetValues([string])) | Sort-Object )
        }
        if($null -ne $rsp.Entries[0].Attributes['supportedSASLMechanisms']) {
            $data.supportedSASLMechanisms = ( ($rsp.Entries[0].Attributes['supportedSASLMechanisms'].GetValues([string])) | Sort-Object )
        }
        if($null -ne $rsp.Entries[0].Attributes['supportedConfigurableSettings']) {
            $data.supportedConfigurableSettings = ( ($rsp.Entries[0].Attributes['supportedConfigurableSettings'].GetValues([string])) | Sort-Object )
        }
        if($null -ne $rsp.Entries[0].Attributes['namingContexts']) {
            $data.namingContexts = @()
            foreach($ctxDef in ($rsp.Entries[0].Attributes['namingContexts'].GetValues([string]))) {
                $data.namingContexts+=[NamingContext]::Parse($ctxDef)
            }
        }
        if($null -ne $rsp.Entries[0].Attributes['dsSchemaAttrCount']) {
            [long]$outVal=-1
            [long]::TryParse($rsp.Entries[0].Attributes['dsSchemaAttrCount'].GetValues([string]),[ref]$outVal) | Out-Null
            $data.dsSchemaAttrCount=$outVal
        }
        if($null -ne $rsp.Entries[0].Attributes['dsSchemaClassCount']) {
            [long]$outVal=-1
            [long]::TryParse($rsp.Entries[0].Attributes['dsSchemaClassCount'].GetValues([string]),[ref]$outVal) | Out-Null
            $data.dsSchemaClassCount=$outVal
        }
        if($null -ne $rsp.Entries[0].Attributes['dsSchemaPrefixCount']) {
            [long]$outVal=-1
            [long]::TryParse($rsp.Entries[0].Attributes['dsSchemaPrefixCount'].GetValues([string]),[ref]$outVal) | Out-Null
            $data.dsSchemaPrefixCount=$outVal
        }
        if($null -ne $rsp.Entries[0].Attributes['isGlobalCatalogReady']) {
            $data.isGlobalCatalogReady=[bool]$rsp.Entries[0].Attributes['isGlobalCatalogReady'].GetValues([string])
        }
        if($null -ne $rsp.Entries[0].Attributes['isSynchronized']) {
            $data.isSynchronized=[bool]$rsp.Entries[0].Attributes['isSynchronized'].GetValues([string])
        }
        if($null -ne $rsp.Entries[0].Attributes['pendingPropagations']) {
            $data.pendingPropagations=$rsp.Entries[0].Attributes['pendingPropagations'].GetValues([string])
        }
        if($null -ne $rsp.Entries[0].Attributes['subSchemaSubEntry']) {
            $data.subSchemaSubEntry=$rsp.Entries[0].Attributes['subSchemaSubEntry'].GetValues([string])[0]
        }
            if($null -ne $rsp.Entries[0].Attributes['domainControllerFunctionality']) {
            $data.domainControllerFunctionality=[int]$rsp.Entries[0].Attributes['domainControllerFunctionality'].GetValues([string])[0]
        }
        if($null -ne $rsp.Entries[0].Attributes['domainFunctionality']) {
            $data.domainFunctionality=[int]$rsp.Entries[0].Attributes['domainFunctionality'].GetValues([string])[0]
        }
        if($null -ne $rsp.Entries[0].Attributes['forestFunctionality']) {
            $data.forestFunctionality=[int]$rsp.Entries[0].Attributes['forestFunctionality'].GetValues([string])[0]
        }
        if($null -ne $rsp.Entries[0].Attributes['msDS-ReplAllInboundNeighbors']) {
            $data.'msDS-ReplAllInboundNeighbors'=@()
            foreach($val in $rsp.Entries[0].Attributes['msDS-ReplAllInboundNeighbors'].GetValues([string])) {
                $data.'msDS-ReplAllInboundNeighbors'+=[xml]$Val.SubString(0,$Val.Length-2)
            }
        }
        if($null -ne $rsp.Entries[0].Attributes['msDS-ReplConnectionFailures']) {
            $data.'msDS-ReplConnectionFailures'=@()
            foreach($val in $rsp.Entries[0].Attributes['msDS-ReplConnectionFailures'].GetValues([string])) {
                $data.'msDS-ReplConnectionFailures'+=[xml]$Val.SubString(0,$Val.Length-2)
            }
        }
        if($null -ne $rsp.Entries[0].Attributes['msDS-ReplLinkFailures']) {
            $data.'msDS-ReplLinkFailures'=@()
            foreach($val in $rsp.Entries[0].Attributes['msDS-ReplLinkFailures'].GetValues([string])) {
                $data.'msDS-ReplLinkFailures'+=[xml]$Val.SubString(0,$Val.Length-2)
            }
        }
        if($null -ne $rsp.Entries[0].Attributes['msDS-ReplPendingOps']) {
            $data.'msDS-ReplPendingOps'=@()
            foreach($val in $rsp.Entries[0].Attributes['msDS-ReplPendingOps'].GetValues([string])) {
                $data.'msDS-ReplPendingOps'+=[xml]$Val.SubString(0,$Val.Length-2)
            }
        }
        if($null -ne $rsp.Entries[0].Attributes['dsaVersionString']) {
            $data.dsaVersionString=$rsp.Entries[0].Attributes['dsaVersionString'].GetValues([string])[0]
        }
        if($null -ne $rsp.Entries[0].Attributes['serviceAccountInfo']) {
            $data.serviceAccountInfo=$rsp.Entries[0].Attributes['serviceAccountInfo'].GetValues([string])
        }
        if($null -ne $rsp.Entries[0].Attributes['LDAPPoliciesEffective']) {
            $data.LDAPPoliciesEffective=@{}
            foreach($val in $rsp.Entries[0].Attributes['LDAPPoliciesEffective'].GetValues([string]))
            {
                $vals=$val.Split(':')
                if($vals.Length -gt 1) {
                    $data.LDAPPoliciesEffective[$vals[0]]=$vals[1]
                }
            }
        }
        $data
    }
}
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
        [Parameter(Position=0)]
        [string[]]$SupportedAttributes,
        [switch]
            #Whether supported attributes need to be loaded from/saved to LDAP as binary stream
        $BinaryInput
    )

    process
    {
        if($null -eq $SupportedAttributes)
        {
            $supportedAttributes = @()
        }
        [PSCustomObject][Ordered]@{
            BinaryInput=$BinaryInput
            SupportedAttributes=$SupportedAttributes
            OnLoad = $null
            OnSave = $null
        }
    }
}
# Internal holder of registered transforms
Function Register-LdapAttributeTransform
{
<#
.SYNOPSIS
    Registers attribute transform logic

.DESCRIPTION
    Registered attribute transforms are used by various cmdlets to convert value to/from format used by LDAP server to/from more convenient format
    Sample transforms can be found in GitHub repository, including template for creation of new transforms

.OUTPUTS
    Nothing

.EXAMPLE
$Ldap = Get-LdapConnection -LdapServer "mydc.mydomain.com" -EncryptionType Kerberos
#get list of available transforms
Get-LdapAttributeTransform -ListAvailable

#register transform for specific attributes only
Register-LdapAttributeTransform -Name Guid -AttributeName objectGuid
Register-LdapAttributeTransform -Name SecurityDescriptor -AttributeName ntSecurityDescriptor

#register for all supported attributes
Register-LdapAttributeTransform -Name Certificate

#find objects, applying registered transforms as necessary
# Notice that for attributes processed by a transform, there is no need to specify them in -BinaryProps parameter: transform 'knows' if it's binary or not
Find-LdapObject -LdapConnection $Ldap -SearchBase "cn=User1,cn=Users,dc=mydomain,dc=com" -SearchScope Base -PropertiesToLoad 'cn','ntSecurityDescriptor','userCert,'userCertificate'

Decription
----------
This example registers transform that converts raw byte array in ntSecurityDescriptor property into instance of System.DirectoryServices.ActiveDirectorySecurity
After command completes, returned object(s) will have instance of System.DirectoryServices.ActiveDirectorySecurity in ntSecurityDescriptor property

.EXAMPLE
$Ldap = Get-LdapConnection -LdapServer "mydc.mydomain.com" -EncryptionType Kerberos
#register all available transforms
Get-LdapAttributeTransform -ListAvailable | Register-LdapAttributeTransform
#find objects, applying registered transforms as necessary
# Notice that for attributes processed by a transform, there is no need to specify them in -BinaryProps parameter: transform 'knows' if it's binary or not
Find-LdapObject -LdapConnection $Ldap -SearchBase "cn=User1,cn=Users,dc=mydomain,dc=com" -SearchScope Base -PropertiesToLoad 'cn','ntSecurityDescriptor','userCert,'userCertificate'

.LINK
More about System.DirectoryServices.Protocols: http://msdn.microsoft.com/en-us/library/bb332056.aspx
More about attribute transforms and how to create them: https://github.com/jformacek/S.DS.P/tree/master/Transforms
Template for creation of new transforms: https://github.com/jformacek/S.DS.P/blob/master/TransformTemplate/_Template.ps1
#>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory,ParameterSetName='Name', Position=0)]
        [string]
            #Name of the transform
        $Name,
        [Parameter()]
        [string]
            #Name of the attribute that will be processed by transform
            #If not specified, transform will be registered on all supported attributes
        $AttributeName,
        [Parameter(Mandatory,ValueFromPipeline,ParameterSetName='TransformObject', Position=0)]
        [PSCustomObject]
            #Transform object produced by Get-LdapAttributeTransform
        $Transform,
        [Parameter(Mandatory,ValueFromPipeline,ParameterSetName='TransformFilePath', Position=0)]
        [string]
            #Full path to transform file
        $TransformFile,
        [switch]
            #Force registration of transform, even if the attribute is not contained in the list of supported attributes
        $Force
    )

    Process
    {
        switch($PSCmdlet.ParameterSetName)
        {
            'TransformObject' {
                $TransformFile = "$PSScriptRoot\Transforms\$($transform.TransformName).ps1"
                $Name = $transform.TransformName
                break;
            }
            'Name' {
                $TransformFile = "$PSScriptRoot\Transforms\$Name.ps1"
                break;
            }
            'TransformFile' {
                $Name = [System.IO.Path]::GetFileNameWithoutExtension($transformFile)
                break;
            }
        }

        if(-not (Test-Path -Path "$TransformFile") )
        {
            throw new-object System.ArgumentException "Transform "$TransformFile" not found"
        }

        $SupportedAttributes = (& "$TransformFile").SupportedAttributes
        switch($PSCmdlet.ParameterSetName)
        {
            'Name' {
                if([string]::IsNullOrEmpty($AttributeName))
                {
                    $attribs = $SupportedAttributes
                }
                else
                {
                    if(($supportedAttributes -contains $AttributeName) -or $Force)
                    {
                        $attribs = @($AttributeName)
                    }
                    else {
                        throw new-object System.ArgumentException "Transform $Name does not support attribute $AttributeName"
                    }
                }
                break;
            }
            default {
                $attribs = $SupportedAttributes
                break;
            }
        }
        foreach($attr in $attribs)
        {
            $t = (. "$TransformFile" -FullLoad)
            $script:RegisteredTransforms[$attr] = $t | Add-Member -MemberType NoteProperty -Name 'Name' -Value $Name -PassThru
        }
    }
}
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

        $rqDel.DistinguishedName = $Object | GetDnFromInput

        if($UseTreeDelete) {
            $rqDel.Controls.Add((new-object System.DirectoryServices.Protocols.TreeDeleteControl)) | Out-Null
        }
        $response = $LdapConnection.SendRequest($rqDel) -as [System.DirectoryServices.Protocols.DeleteResponse]
        #handle failed operation that does not throw itself
        if($null -ne $response -and $response.ResultCode -ne [System.DirectoryServices.Protocols.ResultCode]::Success) {
            throw (new-object System.DirectoryServices.Protocols.LdapException(([int]$response.ResultCode), "$($rqDel.DistinguishedName)`: $($response.ResultCode)`: $($response.ErrorMessage)", $response.ErrorMessage))
        }

    }
}
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
This command Moves the User1 object to different OU. Notice the newName parameter - it's the same as old name as we do not rename the object and new name is required parameter for the protocol.

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
        $rqModDn.DistinguishedName = $Object | GetDnFromInput

        foreach($ctrl in $AdditionalControls) {$rqModDN.Controls.Add($ctrl) | Out-Null}

        $rqModDn.NewName = $NewName
        if(-not [string]::IsNullOrEmpty($NewParent)) {$rqModDN.NewParentDistinguishedName = $NewParent}
        $rqModDN.DeleteOldRdn = (-not $KeepOldRdn)
        $response = $LdapConnection.SendRequest($rqModDN) -as [System.DirectoryServices.Protocols.ModifyDNResponse]
        #handle failed operation that does not throw itself
        if($null -ne $response -and $response.ResultCode -ne [System.DirectoryServices.Protocols.ResultCode]::Success) {
            throw (new-object System.DirectoryServices.Protocols.LdapException(([int]$response.ResultCode), "$($rqModDN.DistinguishedName)`: $($response.ResultCode)`: $($response.ErrorMessage)", $response.ErrorMessage))
        }

    }
}
Function Set-LdapDirSyncCookie
{
<#
.SYNOPSIS
    Returns DirSync cookie serialized as Base64 string.
    Caller is responsible to save and call Set-LdapDirSyncCookie when continuing data retrieval via directory synchronization

.OUTPUTS
    DirSync cookie as Base64 string

.EXAMPLE
Get-LdapConnection -LdapServer "mydc.mydomain.com"

$dse = Get-RootDse
$cookie = Get-Content .\storedCookieFromPreviousIteration.txt
$cookie | Set-LdapDirSyncCookie
$dirUpdates=Find-LdapObject -SearchBase $dse.defaultNamingContext -searchFilter '(objectClass=group)' -PropertiesToLoad 'member' -DirSync Standard
#process updates
foreach($record in $dirUpdates)
{
    #...
}

$cookie = Get-LdapDirSyncCookie
$cookie | Set-Content  .\storedCookieFromPreviousIteration.txt

Description
----------
This example loads dirsync cookie stored in file and performs dirsync search for updates that happened after cookie was generated
Then it stores updated cookie back to file for usage in next iteration

.LINK
More about DirSync: https://docs.microsoft.com/en-us/openspecs/windows_protocols/MS-ADTS/2213a7f2-0a36-483c-b2a4-8574d53aa1e3

#>
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory,ValueFromPipeline)]
        [string]$Cookie
    )

    process
    {
        [byte[]]$script:DirSyncCookie = [System.Convert]::FromBase64String($Cookie)
    }
}
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
#endregion Public commands

#region Internal commands
<#
    Helper that makes sure that LdapConnection is initialized in commands that need it
#>
Function EnsureLdapConnection
{
    param
    (
        [parameter()]
        [System.DirectoryServices.Protocols.LdapConnection]
        $LdapConnection
    )

    process
    {
        if($null -eq $LdapConnection)
        {
            throw (new-object System.ArgumentException("LdapConnection parameter not provided and not found in session variable. Call Get-LdapConnection first"))
        }
    }
}
function GetDnFromInput
{
    Param (
        [parameter(Mandatory = $true, ValueFromPipeline=$true)]
        [Object]
            #DN string or object with distinguishedName property
        $Object
    )

    process
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
        #we return the DN as a string
        return $dn
    }
}
<#
    Retrieves search results as single search request
    Total # of search requests produced is 1
#>
function GetResultsDirectlyInternal
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [System.DirectoryServices.Protocols.SearchRequest]
        $rq,
        [parameter(Mandatory)]
        [System.DirectoryServices.Protocols.LdapConnection]
        $conn,
        [parameter()]
        [String[]]
        $PropertiesToLoad=@(),
        [parameter()]
        [String[]]
        $AdditionalProperties=@(),
        [parameter()]
        [String[]]
        $IgnoredProperties=@(),
        [parameter()]
        [String[]]
        $BinaryProperties=@(),
        [parameter()]
        [Timespan]
        $Timeout,
        [switch]$NoAttributes
    )
    begin
    {
        $template=InitializeItemTemplateInternal -props $PropertiesToLoad -additionalProps $AdditionalProperties
    }
    process
    {
        $pagedRqc=$rq.Controls | Where-Object{$_ -is [System.DirectoryServices.Protocols.PageResultRequestControl]}
        if($NoAttributes) {
            $rq.Attributes.Add('1.1') | Out-Null
        } else {
            $rq.Attributes.AddRange($propertiesToLoad) | Out-Null
        }
        while($true)
        {
            try
            {
                if($Timeout -ne [timespan]::Zero)
                {
                    $rsp = $conn.SendRequest($rq, $Timeout) -as [System.DirectoryServices.Protocols.SearchResponse]
                }
                else
                {
                    $rsp = $conn.SendRequest($rq) -as [System.DirectoryServices.Protocols.SearchResponse]
                }
            }
            catch [System.DirectoryServices.Protocols.DirectoryOperationException]
            {
                if($null -ne $_.Exception.Response -and $_.Exception.Response.ResultCode -eq 'SizeLimitExceeded')
                {
                    #size limit exceeded
                    $rsp = $_.Exception.Response
                }
                else
                {
                    throw $_.Exception
                }
            }

            foreach ($sr in $rsp.Entries)
            {
                $data=$template.Clone()
                
                foreach($attrName in $sr.Attributes.AttributeNames) {
                    $targetAttrName = GetTargetAttr -attr $attrName
                    if($targetAttrName -in $IgnoredProperties) {continue}
                    if($targetAttrName -ne $attrName)
                    {
                        Write-Warning "Value of attribute $targetAttrName not completely retrieved as it exceeds query policy. Use ranged retrieval. Range hint: $attrName"
                    }
                    else
                    {
                        if($null -ne $data[$attrName])
                        {
                            #we may have already loaded partial results from ranged hint
                            continue
                        }
                    }
                    
                    $transform = $script:RegisteredTransforms[$targetAttrName]
                    $BinaryInput = ($null -ne $transform -and $transform.BinaryInput -eq $true) -or ($targetAttrName -in $BinaryProperties)
                    try {
                        if($null -ne $transform -and $null -ne $transform.OnLoad)
                        {
                            if($BinaryInput -eq $true) {
                                $data[$targetAttrName] = (& $transform.OnLoad -Values ($sr.Attributes[$attrName].GetValues([byte[]])))
                            } else {
                                $data[$targetAttrName] = (& $transform.OnLoad -Values ($sr.Attributes[$attrName].GetValues([string])))
                            }
                        } else {
                            if($BinaryInput -eq $true) {
                                $data[$targetAttrName] = $sr.Attributes[$attrName].GetValues([byte[]])
                            } else {
                                $data[$targetAttrName] = $sr.Attributes[$attrName].GetValues([string])
                            }
                        }
                    }
                    catch {
                        Write-Error -ErrorRecord $_
                    }
                }
                
                if([string]::IsNullOrEmpty($data['distinguishedName'])) {
                    #dn has to be present on all objects
                    #having DN processed at the end gives chance to possible transforms on this attribute
                    $transform = $script:RegisteredTransforms['distinguishedName']
                    try {
                        if($null -ne $transform -and $null -ne $transform.OnLoad)
                        {
                            $data['distinguishedName'] = & $transform.OnLoad -Values $sr.DistinguishedName
                        } else {
                            $data['distinguishedName']=$sr.DistinguishedName
                        }
                    }
                    catch {
                        Write-Error -ErrorRecord $_
                    }
                }
                $data
            }
            #the response may contain paged search response. If so, we will need a cookie from it
            [System.DirectoryServices.Protocols.PageResultResponseControl] $prrc=$rsp.Controls | Where-Object{$_ -is [System.DirectoryServices.Protocols.PageResultResponseControl]}
            if($null -ne $prrc -and $prrc.Cookie.Length -ne 0 -and $null -ne $pagedRqc) {
                #pass the search cookie back to server in next paged request
                $pagedRqc.Cookie = $prrc.Cookie;
            } else {
                #either non paged search or we've processed last page
                break;
            }
        }
    }
}
<#
    Retrieves search results as dirsync request
#>
function GetResultsDirSyncInternal
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [System.DirectoryServices.Protocols.SearchRequest]
        $rq,
        [parameter(Mandatory)]
        [System.DirectoryServices.Protocols.LdapConnection]
        $conn,
        [parameter()]
        [String[]]
        $PropertiesToLoad=@(),
        [parameter()]
        [String[]]
        $AdditionalProperties=@(),
        [parameter()]
        [String[]]
        $IgnoredProperties=@(),
        [parameter()]
        [String[]]
        $BinaryProperties=@(),
        [parameter()]
        [Timespan]
        $Timeout,
        [Switch]$ObjectSecurity,
        [switch]$Incremental
    )
    begin
    {
        $template=InitializeItemTemplateInternal -props $PropertiesToLoad -additionalProps $AdditionalProperties
    }
    process
    {
        $DirSyncRqc= new-object System.DirectoryServices.Protocols.DirSyncRequestControl(,$script:DirSyncCookie)
        $DirSyncRqc.Option = [System.DirectoryServices.Protocols.DirectorySynchronizationOptions]::ParentsFirst
        if($ObjectSecurity)
        {
            $DirSyncRqc.Option = $DirSyncRqc.Option -bor [System.DirectoryServices.Protocols.DirectorySynchronizationOptions]::ObjectSecurity
        }
        if($Incremental)
        {
            $DirSyncRqc.Option = $DirSyncRqc.Option -bor [System.DirectoryServices.Protocols.DirectorySynchronizationOptions]::IncrementalValues
        }
        $rq.Controls.Add($DirSyncRqc) | Out-Null
        $rq.Attributes.AddRange($propertiesToLoad) | Out-Null
        
        while($true)
        {
            try
            {
                if($Timeout -ne [timespan]::Zero)
                {
                    $rsp = $conn.SendRequest($rq, $Timeout) -as [System.DirectoryServices.Protocols.SearchResponse]
                }
                else
                {
                    $rsp = $conn.SendRequest($rq) -as [System.DirectoryServices.Protocols.SearchResponse]
                }
            }
            catch [System.DirectoryServices.Protocols.DirectoryOperationException]
            {
                #just throw as we do not have need case for special handling now
                throw $_.Exception
            }

            foreach ($sr in $rsp.Entries)
            {
                $data=$template.Clone()
                
                foreach($attrName in $sr.Attributes.AttributeNames) {
                    $targetAttrName = GetTargetAttr -attr $attrName
                    if($IgnoredProperties -contains $targetAttrName) {continue}
                    if($attrName -ne $targetAttrName)
                    {
                        if($null -eq $data[$targetAttrName])
                        {
                            $data[$targetAttrName] = [PSCustomObject]@{
                                Add=@()
                                Remove=@()
                            }
                        }
                        #we have multival prop chnage --> need special handling
                        #Windows AD/LDS server returns attribute name as '<attr>;range=1-1' for added values and '<attr>;range=0-0' for removed values on forward-linked attributes
                        if($attrName -like '*;range=1-1')
                        {
                            $attributeContainer = {param($val) $data[$targetAttrName].Add=$val}
                        }
                        else {
                            $attributeContainer = {param($val) $data[$targetAttrName].Remove=$val}
                        }
                    }
                    else
                    {
                        $attributeContainer = {param($val) $data[$targetAttrName]=$val}
                    }
                    
                    $transform = $script:RegisteredTransforms[$targetAttrName]
                    $BinaryInput = ($null -ne $transform -and $transform.BinaryInput -eq $true) -or ($targetAttrName -in $BinaryProperties)
                    try {
                        if($null -ne $transform -and $null -ne $transform.OnLoad)
                        {
                            if($BinaryInput -eq $true) {
                                &$attributeContainer (& $transform.OnLoad -Values ($sr.Attributes[$attrName].GetValues([byte[]])))
                            } else {
                                &$attributeContainer (& $transform.OnLoad -Values ($sr.Attributes[$attrName].GetValues([string])))
                            }
                        } else {
                            if($BinaryInput -eq $true) {
                                &$attributeContainer $sr.Attributes[$attrName].GetValues([byte[]])
                            } else {
                                &$attributeContainer $sr.Attributes[$attrName].GetValues([string])
                            }
                        }
                    }
                    catch {
                        Write-Error -ErrorRecord $_
                    }
                }
                
                if([string]::IsNullOrEmpty($data['distinguishedName'])) {
                    #dn has to be present on all objects
                    #having DN processed at the end gives chance to possible transforms on this attribute
                    $transform = $script:RegisteredTransforms['distinguishedName']
                    try {
                        if($null -ne $transform -and $null -ne $transform.OnLoad)
                        {
                            $data['distinguishedName'] = & $transform.OnLoad -Values $sr.DistinguishedName
                        } else {
                            $data['distinguishedName']=$sr.DistinguishedName
                        }
                    }
                    catch {
                        Write-Error -ErrorRecord $_
                    }
                }
                $data
            }
            #the response may contain dirsync response. If so, we will need a cookie from it
            [System.DirectoryServices.Protocols.DirSyncResponseControl] $dsrc=$rsp.Controls | Where-Object{$_ -is [System.DirectoryServices.Protocols.DirSyncResponseControl]}
            if($null -ne $dsrc -and $dsrc.Cookie.Length -ne 0 -and $null -ne $DirSyncRqc) {
                #pass the search cookie back to server in next paged request
                $DirSyncRqc.Cookie = $dsrc.Cookie;
                $script:DirSyncCookie = $dsrc.Cookie
                if(-not $dsrc.MoreData)
                {
                    break;
                }
            } else {
                #either non paged search or we've processed last page
                break;
            }
        }
    }
}
<#
    Retrieves search results as series of requests: first request just returns list of returned objects, and then each object's props are loaded by separate request.
    Total # of search requests produced is N+1, where N is # of objects found
#>

function GetResultsIndirectlyInternal
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [System.DirectoryServices.Protocols.SearchRequest]
        $rq,

        [parameter(Mandatory)]
        [System.DirectoryServices.Protocols.LdapConnection]
        $conn,

        [parameter()]
        [String[]]
        $PropertiesToLoad=@(),

        [parameter()]
        [String[]]
        $AdditionalProperties=@(),

        [parameter()]
        [String[]]
        $IgnoredProperties=@(),

        [parameter(Mandatory = $false)]
        [System.DirectoryServices.Protocols.DirectoryControl[]]
            #additional controls that caller may need to add to request
        $AdditionalControls=@(),

        [parameter()]
        [String[]]
        $BinaryProperties=@(),

        [parameter()]
        [Timespan]
        $Timeout
    )
    begin
    {
        $template=InitializeItemTemplateInternal -props $PropertiesToLoad -additionalProps $AdditionalProperties
    }
    process
    {
        $pagedRqc=$rq.Controls | Where-Object{$_ -is [System.DirectoryServices.Protocols.PageResultRequestControl]}
        $rq.Attributes.AddRange($propertiesToLoad) | Out-Null
        #load only attribute names now and attribute values later
        $rq.TypesOnly=$true
        while ($true)
        {
            try
            {
                if($Timeout -ne [timespan]::Zero)
                {
                    $rsp = $conn.SendRequest($rq, $Timeout) -as [System.DirectoryServices.Protocols.SearchResponse]
                }
                else
                {
                    $rsp = $conn.SendRequest($rq) -as [System.DirectoryServices.Protocols.SearchResponse]
                }
            }
            catch [System.DirectoryServices.Protocols.DirectoryOperationException]
            {
                if($null -ne $_.Exception.Response -and $_.Exception.Response.ResultCode -eq 'SizeLimitExceeded')
                {
                    #size limit exceeded
                    $rsp = $_.Exception.Response
                }
                else
                {
                    throw $_.Exception
                }
            }

            #now process the returned list of distinguishedNames and fetch required properties directly from returned objects
            foreach ($sr in $rsp.Entries)
            {
                $data=$template.Clone()

                $rqAttr=new-object System.DirectoryServices.Protocols.SearchRequest
                $rqAttr.DistinguishedName=$sr.DistinguishedName
                $rqAttr.Scope="Base"
                $rqAttr.Controls.AddRange($AdditionalControls)

                #loading just attributes indicated as present in first search
                $rqAttr.Attributes.AddRange($sr.Attributes.AttributeNames) | Out-Null
                $rspAttr = $LdapConnection.SendRequest($rqAttr)
                foreach ($srAttr in $rspAttr.Entries) {
                    foreach($attrName in $srAttr.Attributes.AttributeNames) {
                        $targetAttrName = GetTargetAttr -attr $attrName
                        if($IgnoredProperties -contains $targetAttrName) {continue}
                        if($targetAttrName -ne $attrName)
                        {
                            Write-Warning "Value of attribute $targetAttrName not completely retrieved as it exceeds query policy. Use ranged retrieval. Range hint: $attrName"
                        }
                        else
                        {
                            if($null -ne $data[$attrName])
                            {
                                #we may have already loaded partial results from ranged hint
                                continue
                            }
                        }

                        $transform = $script:RegisteredTransforms[$targetAttrName]
                        $BinaryInput = ($null -ne $transform -and $transform.BinaryInput -eq $true) -or ($attrName -in $BinaryProperties)
                        #protecting against LDAP servers who don't understand '1.1' prop
                        try {
                            if($null -ne $transform -and $null -ne $transform.OnLoad)
                            {
                                if($BinaryInput -eq $true) {
                                    $data[$targetAttrName] = (& $transform.OnLoad -Values ($srAttr.Attributes[$attrName].GetValues([byte[]])))
                                } else {
                                    $data[$targetAttrName] = (& $transform.OnLoad -Values ($srAttr.Attributes[$attrName].GetValues([string])))
                                }
                            } else {
                                if($BinaryInput -eq $true) {
                                    $data[$targetAttrName] = $srAttr.Attributes[$attrName].GetValues([byte[]])
                                } else {
                                    $data[$targetAttrName] = $srAttr.Attributes[$attrName].GetValues([string])
                                }                                    
                            }
                        }
                        catch {
                            Write-Error -ErrorRecord $_
                        }
                    }
                }
                if([string]::IsNullOrEmpty($data['distinguishedName'])) {
                    #dn has to be present on all objects
                    $transform = $script:RegisteredTransforms['distinguishedName']
                    try {
                        if($null -ne $transform -and $null -ne $transform.OnLoad)
                        {
                            $data['distinguishedName'] = & $transform.OnLoad -Values $sr.DistinguishedName
                        } else {
                            $data['distinguishedName']=$sr.DistinguishedName
                        }
                    }
                    catch {
                        Write-Error -ErrorRecord $_
                    }
                }
                $data
            }
            #the response may contain paged search response. If so, we will need a cookie from it
            [System.DirectoryServices.Protocols.PageResultResponseControl] $prrc=$rsp.Controls | Where-Object{$_ -is [System.DirectoryServices.Protocols.PageResultResponseControl]}
            if($null -ne $prrc -and $prrc.Cookie.Length -ne 0 -and $null -ne $pagedRqc) {
                #pass the search cookie back to server in next paged request
                $pagedRqc.Cookie = $prrc.Cookie;
            } else {
                #either non paged search or we've processed last page
                break;
            }
        }
    }
}
<#
    Retrieves search results as series of requests: first request just returns list of returned objects, and then each property of each object is loaded by separate request.
    When there is a lot of values in multivalued property (such as 'member' attribute of group), property may be loaded by multiple requests
    Total # of search requests produced is at least (N x P) + 1, where N is # of objects found and P is # of properties loaded for each object
#>
function GetResultsIndirectlyRangedInternal
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [System.DirectoryServices.Protocols.SearchRequest]
        $rq,

        [parameter(Mandatory)]
        [System.DirectoryServices.Protocols.LdapConnection]
        $conn,

        [parameter()]
        [String[]]
        $PropertiesToLoad,

        [parameter()]
        [String[]]
        $AdditionalProperties=@(),

        [parameter()]
        [System.DirectoryServices.Protocols.DirectoryControl[]]
            #additional controls that caller may need to add to request
        $AdditionalControls=@(),

        [parameter()]
        [String[]]
        $IgnoredProperties=@(),

        [parameter()]
        [String[]]
        $BinaryProperties=@(),

        [parameter()]
        [Timespan]
        $Timeout,

        [parameter()]
        [Int32]
        $RangeSize
    )
    begin
    {
        $template=InitializeItemTemplateInternal -props $PropertiesToLoad -additionalProps $AdditionalProperties
    }
    process
    {
        $pagedRqc=$rq.Controls | Where-Object{$_ -is [System.DirectoryServices.Protocols.PageResultRequestControl]}
        $rq.Attributes.AddRange($PropertiesToLoad)
        #load only attribute names now and attribute values later
        $rq.TypesOnly=$true
        while ($true)
        {
            try
            {
                if($Timeout -ne [timespan]::Zero)
                {
                    $rsp = $conn.SendRequest($rq, $Timeout) -as [System.DirectoryServices.Protocols.SearchResponse]
                }
                else
                {
                    $rsp = $conn.SendRequest($rq) -as [System.DirectoryServices.Protocols.SearchResponse]
                }
            }
            catch [System.DirectoryServices.Protocols.DirectoryOperationException]
            {
                if($null -ne $_.Exception.Response -and $_.Exception.Response.ResultCode -eq 'SizeLimitExceeded')
                {
                    #size limit exceeded
                    $rsp = $_.Exception.Response
                }
                else
                {
                    throw $_.Exception
                }
            }

            #now process the returned list of distinguishedNames and fetch required properties directly from returned objects
            foreach ($sr in $rsp.Entries)
            {
                $data=$template.Clone()

                $rqAttr=new-object System.DirectoryServices.Protocols.SearchRequest
                $rqAttr.DistinguishedName=$sr.DistinguishedName
                $rqAttr.Scope="Base"
                $rqAttr.Controls.AddRange($AdditionalControls)

                #loading just attributes indicated as present in first search
                foreach($attrName in $sr.Attributes.AttributeNames) {
                    $targetAttrName = GetTargetAttr -attr $attrName
                    if($IgnoredProperties -contains $targetAttrName) {continue}
                    if($targetAttrName -ne $attrName)
                    {
                        #skip paging hint
                        Write-Verbose "Skipping paging hint: $attrName"
                        continue
                    }
                    $transform = $script:RegisteredTransforms[$attrName]
                    $BinaryInput = ($null -ne $transform -and $transform.BinaryInput -eq $true) -or ($attrName -in $BinaryProperties)
                    $start=-$rangeSize
                    $lastRange=$false
                    while ($lastRange -eq $false) {
                        $start += $rangeSize
                        $rng = "$($attrName.ToLower());range=$start`-$($start+$rangeSize-1)"
                        $rqAttr.Attributes.Clear() | Out-Null
                        $rqAttr.Attributes.Add($rng) | Out-Null
                        $rspAttr = $LdapConnection.SendRequest($rqAttr)
                        foreach ($srAttr in $rspAttr.Entries) {
                            #LDAP server changes upper bound to * on last chunk
                            $returnedAttrName=$($srAttr.Attributes.AttributeNames)
                            #load binary properties as byte stream, other properties as strings
                            try {
                                if($BinaryInput) {
                                    $data[$attrName]+=$srAttr.Attributes[$returnedAttrName].GetValues([byte[]])
                                } else {
                                    $data[$attrName] += $srAttr.Attributes[$returnedAttrName].GetValues([string])
                                }
                            }
                            catch {
                                Write-Error -ErrorRecord $_
                            }
                            if($returnedAttrName.EndsWith("-*") -or $returnedAttrName -eq $attrName) {
                                #last chunk arrived
                                $lastRange = $true
                            }
                        }
                    }

                    #perform transform if registered
                    if($null -ne $transform -and $null -ne $transform.OnLoad)
                    {
                        try {
                            $data[$attrName] = (& $transform.OnLoad -Values $data[$attrName])
                        }
                        catch {
                            Write-Error -ErrorRecord $_
                        }
                    }
                }
                if ([string]::IsNullOrEmpty($data['distinguishedName'])) {
                    #dn has to be present on all objects
                    $transform = $script:RegisteredTransforms['distinguishedName']
                    try {
                        if ($null -ne $transform -and $null -ne $transform.OnLoad) {
                            $data['distinguishedName'] = & $transform.OnLoad -Values $sr.DistinguishedName
                        }
                        else {
                            $data['distinguishedName'] = $sr.DistinguishedName
                        }
                    }
                    catch {
                        Write-Error -ErrorRecord $_
                    }

                }
                $data
            }
            #the response may contain paged search response. If so, we will need a cookie from it
            [System.DirectoryServices.Protocols.PageResultResponseControl] $prrc=$rsp.Controls | Where-Object{$_ -is [System.DirectoryServices.Protocols.PageResultResponseControl]}
            if($null -ne $prrc -and $prrc.Cookie.Length -ne 0 -and $null -ne $pagedRqc) {
                #pass the search cookie back to server in next paged request
                $pagedRqc.Cookie = $prrc.Cookie;
            } else {
                #either non paged search or we've processed last page
                break;
            }
        }
    }
}
<#
    Process ragnged retrieval hints
#>
function GetTargetAttr
{
    param
    (
        [Parameter(Mandatory)]
        [string]$attr
    )

    process
    {
        $targetAttr = $attr
        $m = [System.Text.RegularExpressions.Regex]::Match($attr,';range=.+');  #this is to skip range hints provided by DC
        if($m.Success)
        {
            $targetAttr = $($attr.Substring(0,$m.Index))
        }
        $targetAttr
    }
}
<#
    Helper that creates output object template used by Find-LdapObject command, based on required properties to be returned
#>
Function InitializeItemTemplateInternal
{
    param
    (
        [string[]]$props,
        [string[]]$additionalProps
    )

    process
    {
        $template=@{}
        foreach($prop in $additionalProps) {$template[$prop]= $null}
        foreach($prop in $props) {$template[$prop]=$null}
        $template
    }
}
#endregion Internal commands

#region Module initialization
$script:RegisteredTransforms = @{}
$referencedAssemblies=@()
if($PSVersionTable.PSEdition -eq 'Core') {$referencedAssemblies+='System.Security.Principal.Windows'}

#Add compiled helpers. Load only if not loaded previously
$helpers = 'Flattener', 'NamingContext'
foreach($helper in $helpers) {
    if($null -eq ($helper -as [type])) {
        $definition = Get-Content "$PSScriptRoot\Helpers\$helper.cs" -Raw
        Add-Type -TypeDefinition $definition -ReferencedAssemblies $referencedAssemblies -WarningAction SilentlyContinue -IgnoreWarnings
    }
}
#endregion Module initialization
