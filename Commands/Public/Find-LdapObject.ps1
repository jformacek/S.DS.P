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
