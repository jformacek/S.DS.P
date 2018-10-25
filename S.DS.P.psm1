#Types used
Add-Type @'
public enum EncryptionType
{
    None=0,
    Kerberos,
    SSL
}
'@

<#
.SYNOPSIS
    Searches LDAP server in given search root and using given search filter
    

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
$cred=new-object System.Net.NetworkCredential("myUserName","MyPassword","MyDomain")
$Ldap = Get-LdapConnection -Credential $cred
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
Function Find-LdapObject {
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
        #we support pipelining of strings, or objects containing distinguishedName property
        switch($searchBase.GetType().Name) {
            "String" 
            {
                $rq.DistinguishedName=$searchBase
            }
            default 
            {
                if($searchBase.distinguishedName -ne $null) 
                {
                    $rq.DistinguishedName=$searchBase.distinguishedName
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
            $rq.Controls.Add($pagedRqc) | Out-Null
        }

        #add additional controls that caller may have passed
        foreach($ctrl in $AdditionalControls) {$rq.Controls.Add($ctrl)}

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
            
            #for paged search, the response for paged search result control - we will need a cookie from result later
            if($pageSize -gt 0) {
                [System.DirectoryServices.Protocols.PageResultResponseControl] $prrc=($rsp.Controls | Where-Object{$_ -is [System.DirectoryServices.Protocols.PageResultResponseControl]})
                if($prrc -eq $null) {
                    #server was unable to process paged search
                    throw "Find-LdapObject: Server failed to return paged response for request $SearchFilter"
                }
            }
            #now process the returned list of distinguishedNames and fetch required properties using ranged retrieval
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

                if($RangeSize -eq 0)
                {
                    #load all requested properties of object in single call, without ranged retrieval
                    $rqAttr.Attributes.AddRange($PropertiesToLoad) | Out-Null
                    $rspAttr = $LdapConnection.SendRequest($rqAttr)
                    foreach ($sr in $rspAttr.Entries) {
                        foreach($attrName in $sr.Attributes.AttributeNames) {
                            if($BinaryProperties -contains $attrName) {
                                $vals=$sr.Attributes[$attrName].GetValues([byte[]])
                            } else {
                                $vals = $sr.Attributes[$attrName].GetValues(([string]))
                            }
                            $data.$attrName=FlattenArray($vals)
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
                                if($sr.Attributes.AttributeNames -ne $null) {
                                    #LDAP server changes upper bound to * on last chunk
                                    $returnedAttrName=$($sr.Attributes.AttributeNames)
                                    #load binary properties as byte stream, other properties as strings
                                    if($BinaryProperties -contains $attrName) {
                                        $vals=$sr.Attributes[$returnedAttrName].GetValues([byte[]])
                                    } else {
                                        $vals = $sr.Attributes[$returnedAttrName].GetValues(([string])) # -as [string[]];
                                    }
                                    $data.$attrName+=$vals
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
                        $data.$attrName=FlattenArray($data.$attrName)
                    }
                }
                #return result to pipeline
                $data
            }
            if($pageSize -gt 0) {
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
        if($pageSize -gt 0 -and $ReferralChasing -ne $null) {
            #revert to original value of referral chasing on connection
            $LdapConnection.SessionOptions.ReferralChasing=$ReferralChasing
        }
    }
}


<#
.SYNOPSIS
    Connects to LDAP server and retrieves metadata
    

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
Function Get-RootDSE {
    Param (
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.DirectoryServices.Protocols.LdapConnection]
            #existing LDAPConnection object retrieved via Get-LdapConnection
            #When we perform many searches, it is more effective to use the same conbnection rather than create new connection for each search request.
        $LdapConnection
    )
    
    Process {
		#initialize output objects via hashtable --> faster than add-member
        #create default initializer beforehand
        $propDef=@{"rootDomainNamingContext"=@(); "configurationNamingContext"=@(); "schemaNamingContext"=@();"defaultNamingContext"=@();"dnsHostName"=@();"supportedControl"=@()}

        #build request
        $rq=new-object System.DirectoryServices.Protocols.SearchRequest
        $rq.Scope = "Base"
        $rq.Attributes.AddRange($propDef.Keys) | Out-Null
        [System.DirectoryServices.Protocols.ExtendedDNControl]$exRqc = new-object System.DirectoryServices.Protocols.ExtendedDNControl("StandardString")
        $rq.Controls.Add($exRqc) | Out-Null
        
        try
        {
            $rsp=$LdapConnection.SendRequest($rq)
            
            $data=new-object PSObject -Property $propDef
                
            $data.configurationNamingContext = (($rsp.Entries[0].Attributes["configurationNamingContext"].GetValues([string]))[0]).Split(';')[1];
            $data.schemaNamingContext = (($rsp.Entries[0].Attributes["schemaNamingContext"].GetValues([string]))[0]).Split(';')[1];

            # These attributes are not always available for ADAM / AD LDS
            if ($rsp.Entries[0].Attributes["rootDomainNamingContext"]) {
                $data.rootDomainNamingContext = (($rsp.Entries[0].Attributes["rootDomainNamingContext"].GetValues([string]))[0]).Split(';')[2];
            }
            if ($rsp.Entries[0].Attributes["defaultNamingContext"]) {
                $data.defaultNamingContext = (($rsp.Entries[0].Attributes["defaultNamingContext"].GetValues([string]))[0]).Split(';')[2];
            }

            $data.dnsHostName = ($rsp.Entries[0].Attributes["dnsHostName"].GetValues([string]))[0]
            $data.supportedControl = ( ($rsp.Entries[0].Attributes["supportedControl"].GetValues([string])) | Sort-Object )
            $data
        }
        catch
        {
            throw
        }
    }
}

<#
.SYNOPSIS
    Connects to LDAP server and returns LdapConnection object
    

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
Function Get-LdapConnection
{
    Param
    (
        [parameter(Mandatory = $false)]
        [String] 
            #LDAP server name
            #Default: default server given by environment
        $LdapServer=[String]::Empty,
        
        [parameter(Mandatory = $false)]
        [Int32] 
            #LDAP server port
            #Default: 389
        $Port=389,

        [parameter(Mandatory = $false)]
        [System.Net.NetworkCredential]
            #Use different credentials when connecting
        $Credential=$null,

        [parameter(Mandatory = $false)]
        [EncryptionType]
            #Type of encryption to use.
        $EncryptionType=[EncryptionType]::None,
        
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
        $AuthType
    )
    
    Process
    {   
        $FullyQualifiedDomainName=$false;
        [System.DirectoryServices.Protocols.LdapDirectoryIdentifier]$di=new-object System.DirectoryServices.Protocols.LdapDirectoryIdentifier($LdapServer, $Port, $FullyQualifiedDomainName, $ConnectionLess)
        
        if($Credential -ne $null) 
        {
            $LdapConnection=new-object System.DirectoryServices.Protocols.LdapConnection($di, $Credential)
        } else {
        	$LdapConnection=new-object System.DirectoryServices.Protocols.LdapConnection($di)
        }

        if ($AuthType -ne $null) 
        {
            $LdapConnection.AuthType = $AuthType
        }

        if($FastConcurrentBind)
        {
            $LdapConnection.SessionOptions.FastConcurrentBind()
        }
        switch($EncryptionType)
        {
            [EnryptionType]::None {break}
            [EnryptionType]::SSL {
                $LdapConnection.SessionOptions.ProtocolVersion=3
                $LdapConnection.SessionOptions.StartTransportLayerSecurity($null)
                break               
            }
            [EnryptionType]::Kerberos {
                $LdapConnection.SessionOptions.Sealing=$true
                $LdapConnection.SessionOptions.Signing=$true
                break
            }
        }
        $LdapConnection.Timeout = $Timeout
        $LdapConnection
     }       

}

<#
.SYNOPSIS
    Creates a new object in LDAP server
    

.OUTPUTS
    Nothing

.EXAMPLE
$Props = @{"distinguishedName"=$null;"objectClass"=$null;"sAMAccountName"=$null;"unicodePwd"=$null;"userAccountControl"=0}
$obj = new-object PSObject -Property $Props
$obj.DistinguishedName = "cn=user1,cn=users,dc=mydomain,dc=com"
$obj.sAMAccountName = "User1"
$obj.ObjectClass = "User"
$obj.unicodePwd = ,([System.Text.Encoding]::Unicode.GetBytes("`"P@ssw0rd`"") -as [byte[]])
$obj.userAccountControl = "512"

$Ldap = Get-LdapConnection -LdapServer "mydc.mydomain.com" -EncryptionType Kerberos
Add-LdapObject -LdapConnection $Ldap -Object $obj

Description
-----------
Creates new user account in domain.

.LINK
More about System.DirectoryServices.Protocols: http://msdn.microsoft.com/en-us/library/bb332056.aspx

#>
Function Add-LdapObject
{
    Param (
        [parameter(Mandatory = $true, ValueFromPipeline=$true)]
        [PSObject]
            #Source object to copy properties from
        $Object,

        [parameter()]
        [String[]]
            #Properties to ignore on source object
        $IgnoredProps,

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
        if([string]::IsNullOrEmpty($Object.DistinguishedName))
        {
            throw (new-object System.ArgumentException("Input object missing DistinguishedName property"))
        }
        [System.DirectoryServices.Protocols.AddRequest]$rqAdd=new-object System.DirectoryServices.Protocols.AddRequest
        $rqAdd.DistinguishedName=$Object.DistinguishedName

        foreach($prop in (Get-Member -InputObject $Object -MemberType NoteProperty))
        {
            if($prop.Name -eq "distinguishedName") {continue}
            if($IgnoredProps -contains $prop.Name) {continue}
            [System.DirectoryServices.Protocols.DirectoryAttribute]$propAdd=new-object System.DirectoryServices.Protocols.DirectoryAttribute
            $propAdd.Name=$prop.Name
            foreach($val in $Object.($prop.Name))
            {
                $propAdd.Add($val) | Out-Null
            }
            if($propAdd.Count -gt 0)
            {
                $rqAdd.Attributes.Add($propAdd) | Out-Null
            }
        }
        if($rqAdd.Attributes.Count -gt 0)
        {
            $LdapConnection.SendRequest($rqAdd, $Timeout) -as [System.DirectoryServices.Protocols.AddResponse] | Out-Null
        }
    }
}

<#
.SYNOPSIS
    Modifies existing object in LDAP server
    

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

.LINK
More about System.DirectoryServices.Protocols: http://msdn.microsoft.com/en-us/library/bb332056.aspx

#>
Function Edit-LdapObject
{
    Param (
        [parameter(Mandatory = $true, ValueFromPipeline=$true)]
        [PSObject]
            #Source object to copy properties from
        $Object,

        [parameter()]
        [String[]]
            #Properties to ignore on source object. If not specified, no props are ignored
        $IgnoredProps,

        [parameter()]
        [String[]]
            #Properties to include on source object. If not specified, all props are included
        $IncludedProps,

        [parameter(Mandatory = $true)]
        [System.DirectoryServices.Protocols.LdapConnection]
            #Existing LDAPConnection object.
        $LdapConnection,

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
        if([string]::IsNullOrEmpty($Object.DistinguishedName))
        {
            throw (new-object System.ArgumentException("Input object missing DistinguishedName property"))
        }

        [System.DirectoryServices.Protocols.ModifyRequest]$rqMod=new-object System.DirectoryServices.Protocols.ModifyRequest
        $rqMod.DistinguishedName=$Object.DistinguishedName

        foreach($prop in (Get-Member -InputObject $Object -MemberType NoteProperty))
        {
            if($prop.Name -eq "distinguishedName") {continue} #Dn is always ignored
            if(($IgnoredProps -ne $null) -and ($IgnoredProps -contains $prop.Name)) {continue}
            if(($IncludedProps -ne $null) -and (-not ($IncludedProps -contains $prop.Name))) {continue}
            [System.DirectoryServices.Protocols.DirectoryAttribute]$propMod=new-object System.DirectoryServices.Protocols.DirectoryAttributeModification
            $propMod.Name=$prop.Name
            $propMod.Operation='Replace'
            foreach($val in $Object.($prop.Name))
            {
                $propMod.Add($val) | Out-Null
            }
            if($propMod.Count -gt 0)
            {
                $rqMod.Modifications.Add($propMod) | Out-Null
            }
        }
        if($rqMod.Modifications.Count -gt 0)
        {
            $LdapConnection.SendRequest($rqMod, $Timeout) -as [System.DirectoryServices.Protocols.ModifyResponse] | Out-Null
        }
    }
}

<#
.SYNOPSIS
    Removes existing object from LDAP server
    

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
Function Remove-LdapObject
{
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
        switch($Object.GetType().Name)
        {
            "String" 
            {
                $rqDel.DistinguishedName=$Object
            }
            default 
            {
                if($Object.distinguishedName -ne $null) 
                {
                    $rqDel.DistinguishedName=$Object.distinguishedName
                }
                else
                {
                    throw (new-object System.ArgumentException("DistinguishedName must be passed"))
                }
            }
        }
        if($UseTreeDelete)
        {
            $rqDel.Controls.Add((new-object System.DirectoryServices.Protocols.TreeDeleteControl)) | Out-Null
        }
        $LdapConnection.SendRequest($rqDel) -as [System.DirectoryServices.Protocols.DeleteResponse] | Out-Null
        
    }
}


<#
.SYNOPSIS
    Change RDN of existing object

.OUTPUTS
    Nothing

.EXAMPLE
$Ldap = Get-LdapConnection -LdapServer "mydc.mydomain.com" -EncryptionType Kerberos
Rename-LdapObject -LdapConnection $Ldap -Object "cn=User1,cn=Users,dc=mydomain,dc=com" -NewName 'cn=User2'

.LINK
More about System.DirectoryServices.Protocols: http://msdn.microsoft.com/en-us/library/bb332056.aspx

#>
Function Rename-LdapObject
{
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

        [parameter(Mandatory = $false)]
        [System.DirectoryServices.Protocols.DirectoryControl[]]
            #Additional controls that caller may need to add to request
        $AdditionalControls=@(),

        [parameter(Mandatory = $true)]
            #New name of object
        [String]
        $NewName
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
                if($Object.distinguishedName -ne $null) 
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
        $LdapConnection.SendRequest($rqModDN) -as [System.DirectoryServices.Protocols.ModifyDNResponse] | Out-Null
    }
}

#Helpers
function FlattenArray ([Object[]] $arr) {
    #return single value as value, multiple values as array, empty value as null
    switch($arr.Count) {
        0 {
            return $null
            break;
        }
        1 {
            return $arr[0]
            break;
        }
        default {
            return $arr
            break;
        }
    }
}
