# S.DS.P - PowerShell module for working with LDAP servers
This is repo for source code development for S.DS.P PowerShell module that's available on Technet Gallery here: https://gallery.technet.microsoft.com/Using-SystemDirectoryServic-0adf7ef5

This module is also published on PowerShell gallery: https://www.powershellgallery.com/packages/S.DS.P

You can directly install it from PowerShell session via `Install-Module -Name S.DS.P`

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
### Really fast search and loading values of all properties
Specify RangeSize = -1 to perform fast search returning common attributes. Specify PropertiesToLoad as '*' to return "all present" properties of objects  
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
---

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
Kerberos authentication with explicit credentials:
```powershell
#Connects to LDAP server with explicit credentials 
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
Attributes can be transformed from raw string or byte arrays to more comfortable objects. In addition, transform knows syntax of property it transforms, so it's not needed to specify binary property as binary - see sample for objectSid below
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
  -PropertiesToLoad:@('userAccountControl' `
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
