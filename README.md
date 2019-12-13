# S.DS.P - PowerShell module for manipulation with LDAP directory data
This is repo for source code development for S.DS.P PowerShell module that's available on Technet Gallery here: https://gallery.technet.microsoft.com/Using-SystemDirectoryServic-0adf7ef5

This module is also published on PowerShell gallery: https://www.powershellgallery.com/packages/S.DS.P

You can directly install it from PowerShell session via <code>Install-Module -Name S.DS.P</code>

Feel free to contribute; current functionality:
- Searching objects via Find-LdapObject
- Adding objects via Add-LdapObject
- Modifying objects via Edit-LdapObject
- Removal of objects via Remove-LdapObject
- Change of RDN of an object via Rename-LdapObject
- Getting information about LDAP server via Get-RootDSE

Looking for testers against non-MS LDAP servers and more complex functionality (copying from object to object, transformations of objects, etc).

Jiri
