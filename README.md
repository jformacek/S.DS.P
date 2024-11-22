# S.DS.P - PowerShell module for working with LDAP servers
This is repo for source code development for S.DS.P PowerShell module that's available on PowerShell gallery: https://www.powershellgallery.com/packages/S.DS.P 

Module demonstrates how powerful and easy to use is pure LDAP protocol when wrapped into thin and elegant wrapper provided by classes in System.DirectoryServices.Protocols namespace. For an overview, see [Introduction to System.DirectoryServices.Protocols (S.DS.P)](http://msdn.microsoft.com/en-us/library/bb332056.aspx) article on MSDN.

Module also provides many attribute transforms that converts plain numbers, strings or byte arrays stored in LDAP into meaningful objects easy to work with, and converts them back to original raw format when storing back to LDAP storage.

You can directly install the module from PowerShell session via `Install-Module -Name S.DS.P`  
I also publish pre-release versions for testing of new features; installable via `Install-Module -Name S.DS.P -AllowPrerelease`

For documentation and code samples, see [Wiki pages](https://github.com/jformacek/S.DS.P/wiki)

Feel free to contribute!
