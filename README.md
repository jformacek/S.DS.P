# S.DS.P - PowerShell module for working with LDAP servers
This is repo for source code development for S.DS.P PowerShell module that's available on PowerShell gallery: https://www.powershellgallery.com/packages/S.DS.P 

Module demonstrates how powerful and easy to use is pure LDAP protocol when wrapped into thin and elegant wrapper provided by classes in System.DirectoryServices.Protocols namespace. For an overview, see [Introduction to System.DirectoryServices.Protocols (S.DS.P)](http://msdn.microsoft.com/en-us/library/bb332056.aspx) article on MSDN.

Module also provides many attribute transforms that converts plain numbers, strings or byte arrays stored in LDAP into meaningful objects easy to work with, and converts them back to original raw format when storing back to LDAP storage.

You can directly install the module from PowerShell session via `Install-Module -Name S.DS.P`  
I also publish pre-release versions for testing of new features; installable via `Install-Module -Name S.DS.P -AllowPrerelease`

Feel free to contribute!

---

## Searching objects
### Simple object lookup
```powershell
#gets connection to domain controller of your own domain on port 389 with your current credentials
$Ldap = Get-LdapConnection
#gets RootDSE object
$Dse = $Ldap | Get-RootDSE
#perform the search
#Binary properties must be explicitly flagged, otherwise we try to load them as string
Find-LdapObject -LdapConnection $Ldap `
  -SearchFilter:"(&(cn=jsmith)(objectClass=user)(objectCategory=organizationalPerson))" `
  -SearchBase:"ou=Users,$($Dse.defaultNamingContext)" `
  -PropertiesToLoad:@("sAMAccountName","objectSid") `
  -BinaryProps:@("objectSid")
```

### Searching for deleted objects in AD
Sample below shows how to search for deleted objects in AD domain and lists deleted computer objects in the domain.
```powershell
$Ldap = Get-LdapConnection
$Dse = $Ldap | Get-RootDSE
#create necessary directory control
$ctrl = new-object System.DirectoryServices.Protocols.ShowDeletedControl
#use the control when searching
#Note: TRUE in isDeleted condition is case sensitive!
Find-LdapObject -LdapConnection $conn -searchFilter '(&(objectClass=computer)(isDeleted=TRUE))' -searchBase $dse.defaultNamingContext -AdditionalControls $ctrl
```
>**Important**: Make sure you have appropriate permissions on <code>cn=Deleted Objects</code> container. By default, permissions on this container are restricted. Typically, you need <code>Read property</code> and <code>List</code> permissions to be able to search for deleted objects.

### Ranged attribute retrieval
By default, since 2.1.1, objects are loaded from LDAP store via single search request (RangeSize default value is -1; see below for details). This may be impractical for certain scenarios (e.g. some properties are returned only when searchBase is object itself, or nultivalued properties have more values than allowed to retrieve in single search request by query policy. For such cases, there is RangeSize parameter that allows to specify search behavior.

>Prior version 2.1.1, default for RangeSize was 1000.

**RangeSize = -1** performs fast search returning requested attributes via single search  
**RangeSize = 0**  performs search for objects and then loads properties of returned objects via dedicated search with searchBase set to object's distinguishedName  
**RangeSize > 0** performs search for objects and then loads each property of each object via dedicated search with searchBase set to object's distinguishedName and for multivalued properties loads [RangeSize] values, allowing to overcome query policy and load complete list of values.

>RangeSizes > -1 increase # of requests sent to LDAP server and decrease the performance, but can help when you have specific needs

*Note*: Some properties are not returned unless you explicitly ask for them, so don't be surprised...

```powershell
#gets connection to domain controller of your own domain
#on port 389 with your current credentials
$Ldap = Get-LdapConnection
#gets RootDSE object
$Dse = $Ldap | Get-RootDSE
#perform the search
#Note: Binary properties must be explicitly flagged,
#  otherwise we try to load them as string
Find-LdapObject -LdapConnection $Ldap `
  -SearchFilter:"(&(cn=a*)(objectClass=user)(objectCategory=organizationalPerson))" `
  -SearchBase:"ou=Users,$($Dse.defaultNamingContext)" `
  -RangeSize -1 `
  -PropertiesToLoad '*'
```
### Lookup in Global catalog
```powershell
#gets connection to domain controller of your own domain
#on port 3268 (Global Catalog) with your current credentials
$Ldap = Get-LdapConnection -Port 3268
#perform the search in GC
# for GC searches, you don't have to specify search base if you want to search entire forest
Find-LdapObject -LdapConnection $Ldap `
  -SearchFilter:"(&(cn=jsmith)(objectClass=user)(objectCategory=organizationalPerson))" `
  -PropertiesToLoad:@("sAMAccountName","objectSid") `
  -BinaryProps:@("objectSid")
```

### Processing incremental changes via dirsync
Module supports incremental processing of changed obejcts via dirsync. Pattern is:
- perform initial sync
- store dirsync cookie for next run
- at the beginning of next run, retrieve stored cookie
- use the cookie to tell the server about last checkpoint and perform the search
- server returns changes since cookie
- retrieve updated cookie and store it for next run
More about dirsyn: [MD_ADTS - LDAP_SERVER_DIRSYNC_OID](https://docs.microsoft.com/en-us/openspecs/windows_protocols/MS-ADTS/2213a7f2-0a36-483c-b2a4-8574d53aa1e3)
```powershell
Get-LdapConnection -LdapServer "mydc.mydomain.com"
$cookieFile = ".\storedCookieFromPreviousIteration.txt"
$dse = Get-RootDse
#get cookie from prevous run, if there's any
if(Test-Path -Path$cookieFile)
{
    $cookie = Get-Content $cookieFile -Raw
}
else
{
    #for first sync, cookie is empty
    $cookie = $null
}
$cookie | Set-LdapDirSyncCookie
#get updates from since last cookie
$dirUpdates=Find-LdapObject `
    -SearchBase $dse.defaultNamingContext `
    -searchFilter '(objectClass=group)' `
    -PropertiesToLoad 'member' `
    -DirSync StandardIncremental
#process updates
foreach($record in $dirUpdates)
{
    #...
}
#get updated cookie and store it for next run
$cookie = Get-LdapDirSyncCookie
$cookie | Set-Content  $cookieFile
```
---

## Implicit LDAP connection
Starting with version 2.1.5, `Get-LdapConnection` command saves connection object to session variable, so you do not have to pass it as parameter to other commands. Result of most recent call of `Get-LdapConnection` is stored.  
However, you can still store it in variable and use it as parameter - this is useful when you need to work with multiple connections at the same time.
### Simple object lookup
```powershell
#gets connection to domain controller of your own domain on port 389 with your current credentials and stores it to session variable
Get-LdapConnection | Out-Null
#gets RootDSE object using connection stored in session variable
$Dse = Get-RootDSE
#perform the search
#Ldap connection is taken from session variable when not specified in parameter
Find-LdapObject `
  -SearchFilter:"(&(cn=jsmith)(objectClass=user)(objectCategory=organizationalPerson))" `
  -SearchBase:"ou=Users,$($Dse.defaultNamingContext)" `
  -PropertiesToLoad:@("sAMAccountName","objectSid") `
  -BinaryProps:@("objectSid")
```

## Ldap Connection params
### Encryption types
```powershell
#Connects to LDAP server with TLS encryption
$Ldap = Get-LdapConnection -LdapServer ldap.mydomain.com -EncryptionType TLS

#Connects to LDAP server with SSL encryption
#Note: Port must be SSL port
$Ldap = Get-LdapConnection -LdapServer ldap.mydomain.com `
  -EncryptionType SSL `
  -Port 636

#Connects to LDAP server with Kerberos encryption - does not require SSL cert on LDAP server!
$Ldap = Get-LdapConnection -LdapServer ldap.mydomain.com `
  -EncryptionType Kerberos
```
### Credentials and authentication
Basic authentication:
```powershell
#Connects to LDAP server with explicit credentials and Basic authentication
#Note: Server may require encryption to allow connection or searching of data

$Ldap = Get-LdapConnection -LdapServer ldap.mydomain.com `
  -EncryptionType Kerberos `
  -Credential (Get-Credential) `
  -AuthType Basic
```

Basic authentication with distinguishedName - Get-Credential command may not work properly with dn, so we're collecting credential a diferent way
```powershell
#get password as secure string 
$password = Read-Host -AsSecureString
#create credential object
$cred = new-object PSCredential("cn=userAccount,o=mycompany",$password)
$Ldap = Get-LdapConnection -LdapServer ldap.mydomain.com `
  -Credential $cred `
  -AuthType Basic
```

Kerberos authentication with explicit credentials:
```powershell
#Connects to LDAP server with explicit credentials (requires AdmPwd.E powershell module)
#and password retrieved on the fly via AdmPwd.E
$credential = Get-AdmPwdCredential `
  -UserName myAccount@mydomain.com
$Ldap = Get-LdapConnection -LdapServer ldap.mydomain.com `
  -EncryptionType Kerberos `
  -Credential $Credential
```

Client certificate authentication and allowing server certificate from CA with unavailable CRL:
```powershell
#connect to server and authenticate with client certificate
$thumb = '059d5318118e61fe54fd361ae07baf4644a67347'
cert = (dir Cert:\CurrentUser\my).Where{$_.Thumbprint -eq $Thumb}[0]
Get-LdapConnection -LdapServer "mydc.mydomain.com" `
  -Port 636 `
  -ClientCertificate $cert `
  -CertificateValidationFlags [System.Security.Cryptography.X509Certificates.X509VerificationFlags]::IgnoreRootRevocationUnknown
```

---

## Capabilities of your LDAP server
### Supported controls
```powershell
#Can my LDAP server support paged search?
$Ldap = Get-LdapConnection -LdapServer ldap.mydomain.com
$dse = Get-RootDse -LdapConnection $Ldap
if($dse.supportedControl -contains '1.2.840.113556.1.4.319') {
  'Paged search supported!'
}

#Can my LDAP server retrieve attributes via ranged retrieval?
if($dse.supportedControl -contains '1.2.840.113556.1.4.802') {
  'Ranged attribute retrieval supported!'
}
```
### How time on my LDAP server differs from my time?
```powershell
$Ldap = Get-LdapConnection -LdapServer ldap.mydomain.com
(Get-RootDse -LdapConnection $Ldap).CurrentTime - [DateTime]::Now
```
---

## Attribute transforms
### Transforms work on attribute basis
Attributes can be transformed from raw string or byte arrays to more comfortable objects. In addition, transform knows syntax of property it transforms, so it's not needed to specify binary property as binary, because transform "knows" - see sample for objectSid below
```powershell
#For list of available transforms and attributes 
#that they can be applied on, run Get-LdapAttributeTransform -ListAvailable
Register-LdapAttributeTransform `
  -Name SecurityIdentifier `
  -AttributeName objectSid
$Ldap = Get-LdapConnection
#gets RootDSE object
$Dse = $Ldap | Get-RootDSE
#perform the search
#objectSid attribute on returned objects will not be byte array, 
#but System.Security.Principal.SecurityIdentifier object
#no need to specify that objectSid is binary property - transform knows it
Find-LdapObject -LdapConnection $Ldap `
  -SearchFilter:"(&(cn=jsmith)(objectClass=user)(objectCategory=organizationalPerson))" `
  -SearchBase:"ou=Users,$($Dse.defaultNamingContext)" `
  -PropertiesToLoad:@("sAMAccountName","objectSid")
```
### Many transforms registered at the same time
There can be many transforms registered at the same time, and single transform definition can work for many attributes. Transform author defines which atributes are supported by transform.  
Many types of transforms available today, from simple string to integer conversion to parsing WindowsHello keys and AD replication metadata.
```powershell
#Use all available transforms
Get-LdapAttributeTransform -ListAvailable | Register-LdapAttributeTransform
$Ldap = Get-LdapConnection
#gets RootDSE object
$Dse = $Ldap | Get-RootDSE
Find-LdapObject -LdapConnection $Ldap `
  -SearchFilter:"(&(objectClass=user)(objectCategory=organizationalPerson))" `
  -SearchBase:"ou=Users,$($Dse.defaultNamingContext)" `
  -PropertiesToLoad:@('*') -RangeSize -1
```
### Transforms also support custom schema
Do you have custom schema unique for you use case, and want to use transforms? You can add new attribute 
to list of supported attributes of existing transform, once the transform is registered
```powershell
#register guid transform
Register-LdapAttributeTransform -Name Guid
#register your own attribute.
#-Force flag allows adding the attribute even when not included in the list of supported attributes in transform definition
Register-LdapAttributeTransform -Name Guid -AttributeName myCustomGuidAttr -Force
$Ldap = Get-LdapConnection
#gets RootDSE object
$Dse = $Ldap | Get-RootDSE
Find-LdapObject -LdapConnection $Ldap `
  -SearchFilter:"(&(objectClass=user)(objectCategory=organizationalPerson))" `
  -SearchBase:"ou=Users,$($Dse.defaultNamingContext)" `
  -PropertiesToLoad:@('myCustomGuidAttr') -RangeSize -1
```
---

## Modifications of objects
Module supports modification of objects and makes effective use of pipeline so you can modify objects as a part of pipeline processing.
```powershell
Function Perform-Modification
{
  Param
  (
    [Parameter(Mandatory,ValueFromPipeline)]
    $LdapObject
  )
  Process
  {
    $LdapObject.userAccountControl = $LdapObject.userAccountControl -bor 0x2
    $LdapObject
  }
}

$Ldap = Get-LdapConnection
#gets RootDSE object
$Dse = $Ldap | Get-RootDSE
#disable many user accounts
Find-LdapObject -LdapConnection $Ldap `
  -SearchFilter:"(&(cn=a*)(objectClass=user)(objectCategory=organizationalPerson))" `
  -SearchBase:"ou=Users,$($Dse.defaultNamingContext)" `
  -PropertiesToLoad:@('userAccountControl') `
| Perform-Modification `
| Edit-LdapObject -LdapConnection $Ldap `
    -IncludedProps 'userAccountControl'

```
And the same with attribute transform
```powershell
Function Perform-Modification
{
  Param
  (
    [Parameter(Mandatory,ValueFromPipeline)]
    $LdapObject
  )
  Process
  {
    $LdapObject.userAccountControl = @($LdapObject.userAccountControl) + 'UF_ACCOUNTDISABLE'
    $LdapObject
  }
}

#gets domain controller from own domain
$Ldap = Get-LdapConnection
#gets RootDSE object
$Dse = $Ldap | Get-RootDSE
#Register the transform
Register-LdapAttributeTransform -Name UserAccountControl
#disable many user accounts
Find-LdapObject -LdapConnection $Ldap `
  -SearchFilter:"(&(cn=a*)(objectClass=user)(objectCategory=organizationalPerson))" `
  -SearchBase:"ou=Users,$($Dse.defaultNamingContext)" `
  -PropertiesToLoad:@('userAccountControl') `
| Perform-Modification `
| Edit-LdapObject -LdapConnection $Ldap
```
---

## Creation of LDAP objects
```powershell
#We use transforms to convert values to LDAP native format when saving object to LDAP store
Register-LdapAttributeTransform -Name UnicodePwd
Register-LdapAttributeTransform -Name UserAccountControl

#Design the object
$Props = @{
  distinguishedName='cn=user1,cn=users,dc=mydomain,dc=com'
  objectClass='user'
  sAMAccountName='User1'
  unicodePwd='S3cur3Pa$$word'
  userAccountControl='UF_NORMAL_ACCOUNT'
  }

#Create the object according to design
$obj = new-object PSObject -Property $Props

#When dealing with password, LDAP server is likely
#to require encrypted connection
$Ldap = Get-LdapConnection -EncryptionType Kerberos
#Create the object in directory
$obj | Add-LdapObject -LdapConnection $Ldap
```
---

## Deletion of objects
Deletion of individual objects:
```powershell
$Ldap = Get-LdapConnection -LdapServer "mydc.mydomain.com"
Remove-LdapObject -LdapConnection $Ldap `
  -Object "cn=User1,cn=Users,dc=mydomain,dc=com"
```
Deletion of directory subtree:
```powershell
$Ldap = Get-LdapConnection -LdapServer "mydc.mydomain.com" -EncryptionType Kerberos
#With TreeDeleteControl, deletion of objects in container happens on server side
Remove-LdapObject -LdapConnection $Ldap `
  -Object "ou=myContainer,dc=mydomain,dc=com" `
  -UseTreeDelete
```
