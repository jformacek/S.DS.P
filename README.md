# S.DS.P - PowerShell module for manipulation with LDAP directory data
This is repo for source code development for S.DS.P PowerShell module that's available on Technet Gallery here: https://gallery.technet.microsoft.com/Using-SystemDirectoryServic-0adf7ef5

This module is also published on PowerShell gallery: https://www.powershellgallery.com/packages/S.DS.P

You can directly install it from PowerShell session via <code>Install-Module -Name S.DS.P</code>

Feel free to contribute!

## Searching objects
### Simple object lookup
```powershell
#gets connection to domain controller of your own domain on port 389 with your current credentials
$Ldap = Get-LdapConnection
#gets RootDSE object
$Dse = $Ldap | Get-RootDSE
#perform the search
#Binary properties must be explicitly flagged, otherwise we try to load them as string
Find-LdapObject -LdapConnection $Ldap -SearchFilter:"(&(cn=jsmith)(objectClass=user)(objectCategory=organizationalPerson))" -SearchBase:"ou=Users,$($Dse.defaultNamingContext)" -PropertiesToLoad:@("sAMAccountName","objectSid") -BinaryProperties:@("objectSid")
```

### Lookup in Global catalog
```powershell
#gets connection to domain controller of your own domain on port 3268 (Global Catalog) with your current credentials
$Ldap = Get-LdapConnection -Port 3268
#perform the search in GC
# for GC searches, you don't have to specify search base if you want to search entire forest
Find-LdapObject -LdapConnection $Ldap -SearchFilter:"(&(cn=jsmith)(objectClass=user)(objectCategory=organizationalPerson))" -PropertiesToLoad:@("sAMAccountName","objectSid") -BinaryProperties:@("objectSid")
```

## Ldap Connection params
### Encryption types
```powershell
#Connects to LDAP server with TLS encryption
$Ldap = Get-LdapConnection -LdapServer ldap.mydomain.com -EncryptionType TLS

#Connects to LDAP server with SSL encryption
#Note: Port must be SSL port
$Ldap = Get-LdapConnection -LdapServer ldap.mydomain.com -EncryptionType SSL -Port 636

#Connects to LDAP server with Kerberos encryption - does not require SSL cert on LDAP server!
$Ldap = Get-LdapConnection -LdapServer ldap.mydomain.com -EncryptionType Kerberos
```
### Credentials and authentication
```powershell
#Connects to LDAP server with explicit credentials and Basic authentication
#Note: Server may require encryption to allow connection or searching of data
$Ldap = Get-LdapConnection -LdapServer ldap.mydomain.com -EncryptionType Kerberos -Credential (Get-Credential) -AuthType Basic

#Connects to LDAP server with explicit credentials and password retrieved on the fly via AdmPwd.E
$admpwd = Get-AdmPwdManagedAccountPassword -AccountName myAccount -AsSecureString
$credential = New-Object PSCredential($admpwd.Name, $admpwd.Password)
$Ldap = Get-LdapConnection -LdapServer ldap.mydomain.com -EncryptionType Kerberos -Credential $credential -AuthType Basic
```

## Capabilities of your LDAP server
### Supported controls
```powershell
#Can my LDAP server support paged search?
$Ldap = Get-LdapConnection -LdapServer ldap.mydomain.com
$dse = Get-RootDse -LdapConnection $Ldap
if($dse.supportedControl -contains '1.2.840.113556.1.4.319')
{
  'Paged search supported!'
}

#Can my LDAP server retrieve attributes via ranged retrieval?
if($dse.supportedControl -contains '1.2.840.113556.1.4.802')
{
  'Ranged attribute retrieval supported!'
}
```
### How time on my LDAP server differs from my time?
```powershell
$Ldap = Get-LdapConnection -LdapServer ldap.mydomain.com
(Get-RootDse -LdapConnection $Ldap).CurrentTime - [DateTime]::Now
```
## Attribute transforms
Attributes can be transformed from raw string or byte arrays to more comfortable objects
```powershell
#For list of available transforms and attributes that they can be applied on, run Get-LdapAttributeTransform -ListAvailable
Register-LdapAttributeTransform -Name SecurityIdentifier -AttributeName objectSid
$Ldap = Get-LdapConnection
#gets RootDSE object
$Dse = $Ldap | Get-RootDSE
#perform the search
#objectSid attribute on returned objects will not be byte array, but System.Security.Principal.SecurityIdentifier
Find-LdapObject -LdapConnection $Ldap -SearchFilter:"(&(cn=jsmith)(objectClass=user)(objectCategory=organizationalPerson))" -SearchBase:"ou=Users,$($Dse.defaultNamingContext)" -PropertiesToLoad:@("sAMAccountName","objectSid") -BinaryProperties:@("objectSid")
```

## Modifications of objects
Module supports modification of objects
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
Find-LdapObject -LdapConnection $Ldap -SearchFilter:"(&(cn=a*)(objectClass=user)(objectCategory=organizationalPerson))" -SearchBase:"ou=Users,$($Dse.defaultNamingContext)" -PropertiesToLoad:@('userAccountControl') | Perform-Modification | Edit-LdapObject -LdapConnection $Ldap -IncludedProps 'userAccountControl'

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

$Ldap = Get-LdapConnection
#gets RootDSE object
$Dse = $Ldap | Get-RootDSE
#Register the transform
Register-LdapAttributeTransform -Name UserAccountControl -AttributeName userAccountControl
#disable many user accounts
Find-LdapObject -LdapConnection $Ldap -SearchFilter:"(&(cn=a*)(objectClass=user)(objectCategory=organizationalPerson))" -SearchBase:"ou=Users,$($Dse.defaultNamingContext)" -PropertiesToLoad:@('userAccountControl' | Perform-Modification | Edit-LdapObject -LdapConnection $Ldap -IncludedProps 'userAccountControl'
```
## Creation of LDAP objects
```powershell
#We use transforms to convert some values to LDAP native format
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

#When dealing with password, LDAP server is likely to require encrypted connection
$Ldap = Get-LdapConnection -EncryptionType Kerberos
#Create the object in directory
Add-LdapObject -LdapConnection $Ldap -Object $obj
```
## Deletion of objects
```ps
$Ldap = Get-LdapConnection -LdapServer "mydc.mydomain.com" -EncryptionType Kerberos
Remove-LdapObject -LdapConnection $Ldap -Object "cn=User1,cn=Users,dc=mydomain,dc=com"
```