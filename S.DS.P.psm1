Function Find-LdapObject {
    <#
.SYNOPSIS
    Searches LDAP server in given search root and using given search filter

.DESCRIPTION
    Searches LDAP server identified by LDAP connection passed as parameter.
    Attributes of returned objects are retrieved via ranged attribute retrieval by default. This allows to retrieve all attributes, including computed ones, but has impact on performace as each attribute generated own LDAP server query. Tu turn ranged attribute retrieval off, set parameter RangeSize to zero.
    Optionally, attribute values can be transformed to complex types using transform registered for an attribute with 'Load' action.

.OUTPUTS
    Search results as custom objects with requested properties as strings or byte stream

.EXAMPLE
Find-LdapObject -LdapConnection [string]::Empty -SearchFilter:"(&(sn=smith)(objectClass=user)(objectCategory=organizationalPerson))" -SearchBase:"cn=Users,dc=myDomain,dc=com"

Description
-----------
This command connects to domain controller of caller's domain on port 389 and performs the search

.EXAMPLE
$Ldap = Get-LdapConnection
Find-LdapObject -LdapConnection $Ldap -SearchFilter:"(&(cn=jsmith)(objectClass=user)(objectCategory=organizationalPerson))" -SearchBase:"ou=Users,dc=myDomain,dc=com" -PropertiesToLoad:@("sAMAccountName","objectSid") -BinaryProperties:@("objectSid")

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

.LINK
More about System.DirectoryServices.Protocols: http://msdn.microsoft.com/en-us/library/bb332056.aspx
#>
    Param (
        [parameter(Mandatory = $true)]
        [System.DirectoryServices.Protocols.LdapConnection]
            #existing LDAPConnection object retrieved with cmdlet Get-LdapConnection
            #When we perform many searches, it is more effective to use the same conbnection rather than create new connection for each search request.
        $LdapConnection,

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
            #Default: Subtree
        $searchScope='Subtree',

        [parameter(Mandatory = $false)]
        [String[]]
            #List of properties we want to return for objects we find.
            #Default: empty array, meaning no properties are returned
        $PropertiesToLoad=@(),

        [parameter(Mandatory = $false)]
        [String]
            #Name of attribute for ASQ search. Note that searchScope must be set to Base for this type of seach
            #Default: empty string
        $ASQ,

        [parameter(Mandatory = $false)]
        [UInt32]
            #Page size for paged search. Zero means that paging is disabled
            #Default: 500
        $PageSize=500,

        [parameter(Mandatory = $false)]
        [UInt32]
            #Range size for ranged attribute value retrieval. Zero means that ranged attribute value retrieval is disabled and attribute values are returned in single request.
            #Note: Default in query policy in AD is 1500; we use 1000 as default here.
            #Default: 1000
        $RangeSize=1000,

        [parameter(Mandatory = $false)]
        [String[]]
            #List of properties that we want to load as byte stream.
            #Note: Those properties must also be present in PropertiesToLoad parameter. Properties not listed here are loaded as strings
            #Default: empty list, which means that all properties are loaded as strings
        $BinaryProperties=@(),

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

        [parameter(Mandatory = $false)]
        [System.DirectoryServices.Protocols.DirectoryControl[]]
            #additional controls that caller may need to add to request
        $AdditionalControls=@(),

        [parameter(Mandatory = $false)]
        [Timespan]
            #Number of seconds before request times out.
            #Default: 120 seconds
        $Timeout = (New-Object System.TimeSpan(0,0,120))
    )

    Begin
    {
        #initialize output objects via hashtable --> faster than add-member
        #create default initializer beforehand
        #and just once for processing
        $propDef=@{}
        #we always return at least distinguishedName
        #so add it explicitly to object template and remove from propsToLoad if specified
        #also remove '1.1' if present as this is special prop and is in conflict with standard props
        $propDef.Add('distinguishedName','')
        $PropertiesToLoad=@($propertiesToLoad | where-object {$_ -notin @('distinguishedName','1.1')})

        #prepare template for output object
        foreach($prop in $PropertiesToLoad) { $propDef.Add($prop,@()) }

        #define additional properties, skipping props that may have been specified in propertiesToLoad
        foreach($prop in $AdditionalProperties) {
            if($propDef.ContainsKey($prop)) { continue }
            #Intentionally setting to $null instead of empty array as we just define prop for caller's use
            $propDef.Add($prop,$null)
        }

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
        #we support passing $null as SearchBase - user for Global Catalog searches
        if($null -ne $searchBase)
        {
            #we support pipelining of strings, or objects containing distinguishedName property
            switch($searchBase.GetType().Name) {
                "String"
                {
                    $rq.DistinguishedName=$searchBase
                }
                default
                {
                    if($null -ne $searchBase.distinguishedName)
                    {
                        $rq.DistinguishedName=$searchBase.distinguishedName
                    }
                }
            }
        }

        #search filter in LDAP syntax
        $rq.Filter=$searchFilter

        #search scope
        $rq.Scope=$searchScope

        #attributes we want to return - nothing now, and then load attributes directly from each entry returned
        #this allows returning computed and special attributes that can only be returned directly from object
        $rq.Attributes.Add("1.1") | Out-Null

        #paged search control for paged search
        if($pageSize -gt 0) {
            [System.DirectoryServices.Protocols.PageResultRequestControl]$pagedRqc = new-object System.DirectoryServices.Protocols.PageResultRequestControl($pageSize)
            #asking server for best effort with paging
            $pagedRqc.IsCritical=$false
            $rq.Controls.Add($pagedRqc) | Out-Null
        }

        #add additional controls that caller may have passed
        foreach($ctrl in $AdditionalControls) {$rq.Controls.Add($ctrl) | Out-Null}

        #server side timeout
        $rq.TimeLimit=$Timeout

        #Attribute scoped query
        if(-not [String]::IsNullOrEmpty($asq)) {
            [System.DirectoryServices.Protocols.AsqRequestControl]$asqRqc=new-object System.DirectoryServices.Protocols.AsqRequestControl($ASQ)
            $rq.Controls.Add($asqRqc) | Out-Null
        }

        #process paged search in cycle or go through the processing at least once for non-paged search
        while ($true)
        {
            $rsp = $LdapConnection.SendRequest($rq, $Timeout) -as [System.DirectoryServices.Protocols.SearchResponse];

            #now process the returned list of distinguishedNames and fetch required properties directly from returned objects
            foreach ($sr in $rsp.Entries)
            {
                $dn=$sr.DistinguishedName
                #we return results as powershell custom objects to pipeline
                #initialize members of result object (server response does not contain empty attributes, so classes would not have the same layout
                #create empty custom object for result, including only distinguishedName as a default
                $data=new-object PSObject -Property $propDef
                $data.distinguishedName=$dn

                $rqAttr=new-object System.DirectoryServices.Protocols.SearchRequest
                $rqAttr.DistinguishedName=$dn
                $rqAttr.Scope="Base"
                foreach($ctrl in $AdditionalControls) {$rqAttr.Controls.Add($ctrl) | Out-Null}

                if($RangeSize -eq 0) {
                    #load all requested properties of object in single call, without ranged retrieval
                    if($PropertiesToLoad.Count -eq 0) {
                        #if no props specified, ask server to return just result without attrs
                        $rqAttr.Attributes.Add('1.1') | Out-Null
                    }
                    else {
                        $rqAttr.Attributes.AddRange($PropertiesToLoad) | Out-Null
                    }

                    $rspAttr = $LdapConnection.SendRequest($rqAttr)
                    foreach ($sr in $rspAttr.Entries) {
                        foreach($attrName in $PropertiesToLoad) {
                            #protecting against LDAP servers who don't understand '1.1' prop
                            if($sr.Attributes.AttributeNames -contains $attrName) {
                                if($BinaryProperties -contains $attrName) {
                                    $data.$attrName += $sr.Attributes[$attrName].GetValues([byte[]])
                                } else {
                                    $data.$attrName += $sr.Attributes[$attrName].GetValues(([string]))
                                }
                                #perform transform if registered
                                if($null -ne $script:RegisteredTransforms[$attrName] -and $null -ne $script:RegisteredTransforms[$attrName].OnLoad)
                                {
                                    $data.$attrName = (& $script:RegisteredTransforms[$attrName].OnLoad -Values $data.$attrName)
                                }
                            }
                        }
                    }
                }
                else
                {
                    #load properties of object, if requested, using ranged retrieval
                    foreach ($attrName in $PropertiesToLoad) {
                        $start=-$rangeSize
                        $lastRange=$false
                        while ($lastRange -eq $false) {
                            $start += $rangeSize
                            $rng = "$($attrName.ToLower());range=$start`-$($start+$rangeSize-1)"
                            $rqAttr.Attributes.Clear() | Out-Null
                            $rqAttr.Attributes.Add($rng) | Out-Null
                            $rspAttr = $LdapConnection.SendRequest($rqAttr)
                            foreach ($sr in $rspAttr.Entries) {
                                if(($null -ne $sr.Attributes.AttributeNames) -and ($sr.Attributes.AttributeNames.Count -gt 0)) {
                                    #LDAP server changes upper bound to * on last chunk
                                    $returnedAttrName=$($sr.Attributes.AttributeNames)
                                    #load binary properties as byte stream, other properties as strings
                                    if($BinaryProperties -contains $attrName) {
                                        $data.$attrName+=$sr.Attributes[$returnedAttrName].GetValues([byte[]])
                                    } else {
                                        $data.$attrName += $sr.Attributes[$returnedAttrName].GetValues(([string])) # -as [string[]];
                                    }
                                    #$data.$attrName+=$vals
                                    if($returnedAttrName.EndsWith("-*") -or $returnedAttrName -eq $attrName) {
                                        #last chunk arrived
                                        $lastRange = $true
                                    }
                                } else {
                                    #nothing was found
                                    $lastRange = $true
                                }
                            }
                        }
                        #perform transform if registered
                        if($null -ne $script:RegisteredTransforms[$attrName] -and $null -ne $script:RegisteredTransforms[$attrName].OnLoad)
                        {
                            $data.$attrName = (& $script:RegisteredTransforms[$attrName].OnLoad -Values $data.$attrName)
                        }
                    }
                }
                #flatten props
                foreach($prop in $PropertiesToLoad) {$data.$prop = [Flattener]::FlattenArray($data.$prop)}
                #and return result to pipeline
                $data
            }
            #the response may contain paged search response. If so, we will need a cookie from it
            [System.DirectoryServices.Protocols.PageResultResponseControl] $prrc=($rsp.Controls | Where-Object{$_ -is [System.DirectoryServices.Protocols.PageResultResponseControl]})
            if(($pageSize -gt 0) -and ($null -ne $prrc)) {
                #we performed paged search
                if ($prrc.Cookie.Length -eq 0) {
                    #last page --> we're done
                    break;
                }
                #pass the search cookie back to server in next paged request
                $pagedRqc.Cookie = $prrc.Cookie;
            } else {
                #exit the processing for non-paged search
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

Function Get-RootDSE {
<#
.SYNOPSIS
    Connects to LDAP server and retrieves metadata

.DESCRIPTION
    Retrieves LDAP server metadata from Root DSE object
    Current implementation is specialized to metadata foung on Windows LDAP server, so on other platforms, some metadata may be empty.

.OUTPUTS
    Custom object containing information about LDAP server

.EXAMPLE
Get-LdapConnection | Get-RootDSE

Description
-----------
This command connects to domain controller of caller's domain on port 389 and returns metadata about the server

.LINK
More about System.DirectoryServices.Protocols: http://msdn.microsoft.com/en-us/library/bb332056.aspx
#>

    Param (
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.DirectoryServices.Protocols.LdapConnection]
            #existing LDAPConnection object retrieved via Get-LdapConnection
            #When we perform many searches, it is more effective to use the same conbnection rather than create new connection for each search request.
        $LdapConnection
    )
    Begin
    {
		#initialize output objects via hashtable --> faster than add-member
        #create default initializer beforehand
        $propDef=[ordered]@{`
            'rootDomainNamingContext'=$null; 'configurationNamingContext'=$null; 'schemaNamingContext'=$null; `
            'defaultNamingContext'=$null; 'namingContexts'=$null; `
            'dnsHostName'=$null; 'ldapServiceName'=$null; 'dsServiceName'=$null; 'serverName'=$null;`
            'supportedLdapPolicies'=$null; 'supportedSASLMechanisms'=$null; 'supportedControl'=$null;`
            'currentTime'=$null; 'approximateHighestInternalObjectID'=$null `
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

        $data=new-object PSObject -Property $propDef

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
        if($null -ne $rsp.Entries[0].Attributes['namingContexts']) {
            $data.namingContexts = @()
            foreach($ctxDef in ($rsp.Entries[0].Attributes['namingContexts'].GetValues([string]))) {
                $data.namingContexts+=[NamingContext]::Parse($ctxDef)
            }
        }
        $data
    }
}

Function Get-LdapConnection
{
<#
.SYNOPSIS
    Connects to LDAP server and returns LdapConnection object

.DESCRIPTION
    Creates connection to LDAP server according to parameters passed.
.OUTPUTS
    LdapConnection object

.EXAMPLE
Get-LdapConnection -LdapServer "mydc.mydomain.com" -EncryptionType Kerberos

Description
-----------
Returns LdapConnection for caller's domain controller, with active Kerberos Encryption for data transfer security

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
        $Timeout = (New-Object System.TimeSpan(0,0,120)),

        [Parameter(Mandatory = $false)]
        [System.DirectoryServices.Protocols.AuthType]
            #The type of authentication to use with the LdapConnection
        $AuthType,

        [Parameter(Mandatory = $false)]
        [int]
            #Requested LDAP protocol version
        $ProtocolVersion = 3
    )

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
        $LdapConnection.Timeout = $Timeout

        if($FastConcurrentBind) {
            $LdapConnection.SessionOptions.FastConcurrentBind()
        }
        $LdapConnection
     }
}


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
$Props = @{"distinguishedName"=$null;"objectClass"=$null;"sAMAccountName"=$null;"unicodePwd"=$null;"userAccountControl"=0}
$obj = new-object PSObject -Property $Props
$obj.DistinguishedName = "cn=user1,cn=users,dc=mydomain,dc=com"
$obj.sAMAccountName = "User1"
$obj.ObjectClass = "User"
$obj.unicodePwd = "P@ssw0rd"
$obj.userAccountControl = "512"

$Ldap = Get-LdapConnection -LdapServer "mydc.mydomain.com" -EncryptionType Kerberos
Register-LdapAttributeTransform (.\Transforms\unicodePwd.ps1 -Action Save)
Add-LdapObject -LdapConnection $Ldap -Object $obj

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

        [parameter(Mandatory = $true)]
        [System.DirectoryServices.Protocols.LdapConnection]
            #Existing LDAPConnection object.
        $LdapConnection,

        [parameter(Mandatory = $false)]
        [System.DirectoryServices.Protocols.DirectoryControl[]]
            #Additional controls that caller may need to add to request
        $AdditionalControls=@(),

        [parameter(Mandatory = $false)]
        [Timespan]
            #Time before connection times out.
            #Default: 120 seconds
        $Timeout = (New-Object System.TimeSpan(0,0,120))
    )

    Process
    {
        if([string]::IsNullOrEmpty($Object.DistinguishedName)) {
            throw (new-object System.ArgumentException("Input object missing DistinguishedName property"))
        }
        [System.DirectoryServices.Protocols.AddRequest]$rqAdd=new-object System.DirectoryServices.Protocols.AddRequest
        $rqAdd.DistinguishedName=$Object.DistinguishedName

        #add additional controls that caller may have passed
        foreach($ctrl in $AdditionalControls) {$rqAdd.Controls.Add($ctrl) | Out-Null}

        foreach($prop in (Get-Member -InputObject $Object -MemberType NoteProperty)) {
            if($prop.Name -eq "distinguishedName") {continue}
            if($IgnoredProps -contains $prop.Name) {continue}
            [System.DirectoryServices.Protocols.DirectoryAttribute]$propAdd=new-object System.DirectoryServices.Protocols.DirectoryAttribute
            $propAdd.Name=$prop.Name
            $attrVal = $Object.($prop.Name)

            #if transform defined -> transform to form accepted by directory
            if($null -ne $script:RegisteredTransforms[$prop.Name] -and $null -ne $script:RegisteredTransforms[$prop.Name].OnSave)
            {
                $attrVal = (& $script:RegisteredTransforms[$prop.Name].OnSave -Values $attrVal)
            }

            if($prop.Name -in $BinaryProps) {
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
        if($rqAdd.Attributes.Count -gt 0) {
            $LdapConnection.SendRequest($rqAdd, $Timeout) -as [System.DirectoryServices.Protocols.AddResponse] | Out-Null
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
$Props = @{"distinguishedName"=$null;employeeNumber=$null}
$obj = new-object PSObject -Property $Props
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

        [parameter(Mandatory = $true)]
        [System.DirectoryServices.Protocols.LdapConnection]
            #Existing LDAPConnection object.
        $LdapConnection,

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
            #Default: 120 seconds
        $Timeout = (New-Object System.TimeSpan(0,0,120))
    )

    Process
    {
        if([string]::IsNullOrEmpty($Object.DistinguishedName)) {
            throw (new-object System.ArgumentException("Input object missing DistinguishedName property"))
        }

        [System.DirectoryServices.Protocols.ModifyRequest]$rqMod=new-object System.DirectoryServices.Protocols.ModifyRequest
        $rqMod.DistinguishedName=$Object.DistinguishedName
        $permissiveModifyRqc = new-object System.DirectoryServices.Protocols.PermissiveModifyControl
        $permissiveModifyRqc.IsCritical = $false
        $rqMod.Controls.Add($permissiveModifyRqc) | Out-Null

        #add additional controls that caller may have passed
        foreach($ctrl in $AdditionalControls) {$rqMod.Controls.Add($ctrl) | Out-Null}

        foreach($prop in (Get-Member -InputObject $Object -MemberType NoteProperty)) {
            if($prop.Name -eq "distinguishedName") {continue} #Dn is always ignored
            if($IgnoredProps -contains $prop.Name) {continue}
            if(($IncludedProps.Count -gt 0) -and ($IncludedProps -notcontains $prop.Name)) {continue}
            [System.DirectoryServices.Protocols.DirectoryAttribute]$propMod=new-object System.DirectoryServices.Protocols.DirectoryAttributeModification
            $propMod.Name=$prop.Name

            if($Object.($prop.Name)) {
                #we're modifying property
                $attrVal = $Object.($prop.Name)

                #if transform defined -> transform to form accepted by directory
                if($null -ne $script:RegisteredTransforms[$prop.Name] -and $null -ne $script:RegisteredTransforms[$prop.Name].OnSave)
                {
                    $attrVal = (& $script:RegisteredTransforms[$prop.Name].OnSave -Values $attrVal)
                }

                if($attrVal.Count -gt 0) {
                    $propMod.Operation=$Mode
                    if($prop.Name -in $BinaryProps)  {
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
            $LdapConnection.SendRequest($rqMod, $Timeout) -as [System.DirectoryServices.Protocols.ModifyResponse] | Out-Null
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
        [parameter(Mandatory = $true)]
        [System.DirectoryServices.Protocols.LdapConnection]
            #Existing LDAPConnection object.
        $LdapConnection,

        [parameter(Mandatory = $false)]
        [System.DirectoryServices.Protocols.DirectoryControl[]]
            #Additional controls that caller may need to add to request
        $AdditionalControls=@(),

        [parameter(Mandatory = $false)]
        [Switch]
            #Whether or not to use TreeDeleteControl.
        $UseTreeDelete
    )

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
            }
            default
            {
                if($null -ne $Object.distinguishedName)
                {
                    $rqDel.DistinguishedName=$Object.distinguishedName
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
        [parameter(Mandatory = $true)]
        [System.DirectoryServices.Protocols.LdapConnection]
            #Existing LDAPConnection object.
        $LdapConnection,

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
        $DeleteOldRdn,

        [parameter(Mandatory = $false)]
        [System.DirectoryServices.Protocols.DirectoryControl[]]
            #Additional controls that caller may need to add to request
        $AdditionalControls=@()
    )

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
        $rqModDN.DeleteOldRdn = ($DeleteOldRdn)
        $LdapConnection.SendRequest($rqModDN) -as [System.DirectoryServices.Protocols.ModifyDNResponse] | Out-Null
    }
}

#Transform registration handling support

# Internal holder of registered transforms
$script:RegisteredTransforms = @{}


Function Register-LdapAttributeTransform
{
<#
.SYNOPSIS
    Registers attribute transform logic

.DESCRIPTION
    Registered attribute transforms are used by various cmdlets to convert value to/from format used by LDAP server to/from more convenient format
    Sample transforms can be found in GitHub repository

.OUTPUTS
    Nothing

.EXAMPLE
$Ldap = Get-LdapConnection -LdapServer "mydc.mydomain.com" -EncryptionType Kerberos
#get list of available transforms
Get-LdapAttributeTransform -ListAvailable
#register necessary transforms
Register-LdapAttributeTransform -Name Guid -AttributeName objectGuid
Register-LdapAttributeTransform -Name SecurityDescriptor -AttributeName ntSecurityDescriptor
Register-LdapAttributeTransform -Name Certificate -AttributeName userCert
Register-LdapAttributeTransform -Name Certificate -AttributeName userCertificate
Find-LdapObject -LdapConnection $Ldap -SearchBase "cn=User1,cn=Users,dc=mydomain,dc=com" -SearchScope Base -PropertiesToLoad 'cn','ntSecurityDescriptor','userCert,'userCertificate' -BinaryProperties 'ntSecurityDescriptor','userCert,'userCertificate'

Decription
----------
This example registers transform that converts raw byte array in ntSecurityDescriptor property into instance of System.DirectoryServices.ActiveDirectorySecurity
After command completes, returned object(s) will have instance of System.DirectoryServices.ActiveDirectorySecurity in ntSecurityDescriptor property

.LINK
More about System.DirectoryServices.Protocols: http://msdn.microsoft.com/en-us/library/bb332056.aspx
More about attribute transforms and how to create them: https://github.com/jformacek/S.DS.P/tree/master/Transforms
#>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory,ParameterSetName='Names')]
        [string]
            #Name of the transform
        $Name,
        [Parameter(Mandatory,ValueFromPipeline,ParameterSetName='Names')]
        [string]
            #Name of the attribute that will be processed by transform
        $AttributeName,
        [Parameter(Mandatory,ValueFromPipeline,ParameterSetName='TransformObject')]
        [PSCustomObject]
        $Transform
    )

    Process
    {
        switch($PSCmdlet.ParameterSetName)
        {
            'Names' {
                $transform = (. "$PSScriptRoot\Transforms\$Name.ps1" -FullLoad)
                if($AttributeName -in $transform.SupportedAttributes) {
                    $transform = $transform | Add-Member -MemberType NoteProperty -Name 'Name' -Value $Name -PassThru
                    $script:RegisteredTransforms[$AttributeName]= $transform
                }
                else {
                    throw new-object System.ArgumentException "Attribute $AttributeName is not supported by this transform"
                }
                break;
            }
            'TransformObject' {
                $attribs = (& "$PSScriptRoot\Transforms\$($transform.Name).ps1").SupportedAttributes
                foreach($attr in $attribs)
                {
                    $t = (. "$PSScriptRoot\Transforms\$($transform.Name).ps1" -FullLoad)
                    $t = $t | Add-Member -MemberType NoteProperty -Name 'Name' -Value $Transform.Name -PassThru
                    $script:RegisteredTransforms[$attr]= $t
                }
                break;
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

#we no longer need the transform, let's unregister
Unregister-LdapAttributeTransform -AttributeName objectGuid
Find-LdapObject -LdapConnection $Ldap -SearchBase "cn=User1,cn=Users,dc=mydomain,dc=com" -SearchScope Base -PropertiesToLoad 'cn',objectGuid -BinaryProperties 'objectGuid'
#now objectGuid property of returned object contains raw byte array

Description
----------
This example registers transform that converts raw byte array in ntSecurityDescriptor property into instance of System.DirectoryServices.ActiveDirectorySecurity
After command completes, returned object(s) will have instance of System.DirectoryServices.ActiveDirectorySecurity in ntSecurityDescriptor property
Then transform is unregistered, so subsequent calls do not use it

.LINK

More about System.DirectoryServices.Protocols: http://msdn.microsoft.com/en-us/library/bb332056.aspx
More about attribute transforms and how to create them: https://github.com/jformacek/S.DS.P/tree/master/Transforms

#>

    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
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
            $transform = $transform | Add-Member -MemberType NoteProperty -Name 'Name' -Value ([System.IO.Path]::GetFileNameWithoutExtension($transformFile.FullName)) -PassThru
            $transform | Select-Object Name,SupportedAttributes
        }
    }
    else {
        foreach($attrName in ($script:RegisteredTransforms.Keys | Sort-object))
        {
            New-Object PSCustomObject -Property ([Ordered]@{
                AttributeName = $attrName
                Name = $script:RegisteredTransforms[$attrName].Name
            })
        }
    }
}


#Helpers
Add-Type @'
public static class Flattener
{
    public static System.Object FlattenArray(System.Object[] arr)
    {
        if(arr==null) return null;
        int i=arr.Length;
        if(i==0) return null;
        if(i==1) return arr[0];
        return arr;
    }
}
'@

$referencedAssemblies=@()
if($PSVersionTable.PSEdition -eq 'Core') {$referencedAssemblies+='System.Security.Principal.Windows'}
Add-Type @'
public class NamingContext
{
    public System.Security.Principal.SecurityIdentifier SID {get; set;}
    public System.Guid GUID {get; set;}
    public string distinguishedName {get; set;}
    public override string ToString() {return distinguishedName;}
    public static NamingContext Parse(string ctxDef)
    {
        NamingContext retVal = new NamingContext();
        var parts = ctxDef.Split(';');
        if(parts.Length == 1)
        {
            retVal.distinguishedName = parts[0];
        }
        else
        {
            foreach(string part in parts)
            {
                if(part.StartsWith("<GUID="))
                {
                    retVal.GUID=System.Guid.Parse(part.Substring(6,part.Length-7));
                    continue;
                }
                if(part.StartsWith("<SID="))
                {
                    retVal.SID=new System.Security.Principal.SecurityIdentifier(part.Substring(5,part.Length-6));
                    continue;
                }
                retVal.distinguishedName=part;
            }
        }
        return retVal;
    }
}
'@ -ReferencedAssemblies $referencedAssemblies
