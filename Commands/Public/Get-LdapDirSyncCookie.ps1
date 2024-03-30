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
