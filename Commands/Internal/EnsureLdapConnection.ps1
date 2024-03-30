<#
    Helper that makes sure that LdapConnection is initialized in commands that need it
#>
Function EnsureLdapConnection
{
    param
    (
        [parameter()]
        [System.DirectoryServices.Protocols.LdapConnection]
        $LdapConnection
    )

    process
    {
        if($null -eq $LdapConnection)
        {
            throw (new-object System.ArgumentException("LdapConnection parameter not provided and not found in session variable. Call Get-LdapConnection first"))
        }
    }
}
