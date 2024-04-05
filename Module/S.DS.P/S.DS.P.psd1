#
# Module manifest for module 'S.DS.P' (System.DirectoryServices.Protocols)
#
# Generated by: Jiri Formacek
#
# Generated on: 30.5.2012
#
@{

    # Script module or binary module file associated with this manifest
    RootModule = '.\S.DS.P.psm1'

    # Version number of this module.
    ModuleVersion = '2.1.9'

    # ID used to uniquely identify this module
    GUID = '766cbbc0-85b9-4773-b4db-2fa86cd771ff'

    # Author of this module
    Author = 'Jiri Formacek'

    # Company or vendor of this module
    CompanyName = 'GreyCorbel Solutions'

    # Copyright statement for this module
    Copyright = ''

    # Description of the functionality provided by this module
    Description = 'Provides cmdlets that demonstrate usage of System.DirectoryServices.Protocols .NET API in Powershell'

    CompatiblePSEditions = @('Desktop','Core')

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Name of the Windows PowerShell host required by this module
    PowerShellHostName = ''

    # Minimum version of the Windows PowerShell host required by this module
    PowerShellHostVersion = ''

    # Minimum version of the .NET Framework required by this module
    #DotNetFrameworkVersion = '2.0'

    # Minimum version of the common language runtime (CLR) required by this module
    CLRVersion = ''

    # Processor architecture (None, X86, Amd64, IA64) required by this module
    ProcessorArchitecture = ''

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules = @()

    # Assemblies that must be loaded prior to importing this module
    RequiredAssemblies = @('System.DirectoryServices.Protocols')

    # Script files (.ps1) that are run in the caller's environment prior to importing this module
    ScriptsToProcess = @()

    # Type files (.ps1xml) to be loaded when importing this module
    TypesToProcess = @()

    # Format files (.ps1xml) to be loaded when importing this module
    FormatsToProcess = @('.\S.DS.P.format.ps1xml')

    # Modules to import as nested modules of the module specified in ModuleToProcess
    NestedModules = @()

    # Functions to export from this module
    CmdletsToExport = @()

    # Cmdlets to export from this module
    FunctionsToExport = 'Find-LdapObject','Get-RootDSE',
        'Get-LdapConnection', 'Edit-LdapObject',
        'Add-LdapObject','Remove-LdapObject',
        'Rename-LdapObject',
        'Register-LdapAttributeTransform','Unregister-LdapAttributeTransform',
        'Get-LdapAttributeTransform',
        'New-LdapAttributeTransformDefinition',
        'Get-LdapDirSyncCookie', 'Set-LdapDirSyncCookie'

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module
    AliasesToExport = @()

    # List of all modules packaged with this module
    ModuleList = @()

    # List of all files packaged with this module
    FileList = @('.\Transforms\admpwd.e.pwd.ps1', '.\Transforms\admpwd.e.pwdhistory.ps1', '.\Transforms\fileTime.ps1', `
        '.\Transforms\Boolean.ps1', '.\Transforms\Certificate.ps1', '.\Transforms\ExternalDirectoryObjectId.ps1', '.\Transforms\GeneralizedTime.ps1', `
        '.\Transforms\groupType.ps1', '.\Transforms\guid.ps1', '.\Transforms\Integer.ps1', '.\Transforms\Long.ps1', `
        '.\Transforms\msExchRecipientDisplayType.ps1', '.\Transforms\msExchRecipientTypeDetails.ps1', '.\Transforms\msExchRemoteRecipientType.ps1', `
        '.\Transforms\ProxyAddress.ps1', '.\Transforms\quotaUsage.ps1', '.\Transforms\replicationMetadata.ps1', '.\Transforms\SamAccountType.ps1', `
        '.\Transforms\searchFlags.ps1', '.\Transforms\securityDescriptor.ps1', '.\Transforms\securityIdentifier.ps1', '.\Transforms\supportedEncryptionTypes.ps1', `
        '.\Transforms\systemFlags.ps1', '.\Transforms\unicodePwd.ps1', '.\Transforms\userAccountControl.ps1', '.\Transforms\wellKnownObject.ps1', '.\Transforms\WindowsHelloKeyInfo.ps1', `
        '.\S.DS.P.psd1', '.\S.DS.P.psm1', `
        '.\S.DS.P.format.ps1xml' `
        )

    # Private data to pass to the module specified in ModuleToProcess
    PrivateData = @{
        PSData = @{

            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @('Ldap','System.DirectoryServices.Protocols','S.DS.P','PSEdition_Desktop','PSEdition_Core','Windows')

            # A URL to the license for this module.
            # LicenseUri = ''            

            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/jformacek/S.DS.P'

            # A URL to an icon representing this module.
            IconUri = 'https://raw.githubusercontent.com/jformacek/S.DS.P/master/Graphics/icon.png'

            # ReleaseNotes of this module
            # ReleaseNotes = ''

            # Prerelease string of this module
            Prerelease = 'beta1'

            # Flag to indicate whether the module requires explicit user acceptance for install/update/save
            RequireLicenseAcceptance = $false

            # External dependent modules of this module
            # ExternalModuleDependencies = @()
        }
    }
}
