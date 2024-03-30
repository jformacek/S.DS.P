Function Get-LdapConnection
{
<#
.SYNOPSIS
    Connects to LDAP server and returns LdapConnection object

.DESCRIPTION
    Creates connection to LDAP server according to parameters passed. 
    Stores retured LdapConnection object to module cache where other commands look for it when they do not receive connection from parameter.
.OUTPUTS
    LdapConnection object

.EXAMPLE
Get-LdapConnection -LdapServer "mydc.mydomain.com" -EncryptionType Kerberos

Description
-----------
Returns LdapConnection for caller's domain controller, with active Kerberos Encryption for data transfer security

.EXAMPLE
Get-LdapConnection -LdapServer "mydc.mydomain.com" -EncryptionType Kerberos -Credential (Get-AdmPwdCredential)

Description
-----------
Returns LdapConnection for caller's domain controller, with active Kerberos Encryption for data transfer security, authenticated by automatically retrieved password from AdmPwd.E client

.EXAMPLE
$thumb = '059d5318118e61fe54fd361ae07baf4644a67347'
$cert = (dir Cert:\CurrentUser\my).Where{$_.Thumbprint -eq $Thumb}[0]
Get-LdapConnection -LdapServer "mydc.mydomain.com" -Port 636 -CertificateValidationFlags ([System.Security.Cryptography.X509Certificates.X509VerificationFlags]::AllowUnknownCertificateAuthority) -ClientCertificate $cert

Description
-----------
Returns LdapConnection over SSL for given LDAP server, authenticated by a client certificate and allowing LDAP server to use self-signed certificate
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
        $Timeout = [TimeSpan]::Zero,

        [Parameter(Mandatory = $false)]
        [System.DirectoryServices.Protocols.AuthType]
            #The type of authentication to use with the LdapConnection
        $AuthType,

        [Parameter(Mandatory = $false)]
        [int]
            #Requested LDAP protocol version
        $ProtocolVersion = 3,

        [Parameter(Mandatory = $false)]
        [System.Security.Cryptography.X509Certificates.X509VerificationFlags]
            #Requested LDAP protocol version
        $CertificateValidationFlags = 'NoFlag',

        [Parameter(Mandatory = $false)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]
            #Client certificate used for authenticcation instead of credentials
            #See https://docs.microsoft.com/en-us/windows/win32/api/winldap/nc-winldap-queryclientcert
        $ClientCertificate
    )

    Begin
    {
        if($null -eq $script:ConnectionParams)
        {
            $script:ConnectionParams=@{}
        }
    }
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

        
        #store connection params for each server in global variable, so as it is reachable from callback scriptblocks
        $connectionParams=@{}
        foreach($server in $LdapServer) {$script:ConnectionParams[$server]=$connectionParams}
        if($CertificateValidationFlags -ne 'NoFlag')
        {
            $connectionParams['ServerCertificateValidationFlags'] = $CertificateValidationFlags
            #server certificate validation callback
            $LdapConnection.SessionOptions.VerifyServerCertificate = { 
                param(
                    [Parameter(Mandatory)][DirectoryServices.Protocols.LdapConnection]$LdapConnection,
                    [Parameter(Mandatory)][Security.Cryptography.X509Certificates.X509Certificate2]$Certificate
                )
                [System.Security.Cryptography.X509Certificates.X509Chain] $chain = new-object System.Security.Cryptography.X509Certificates.X509Chain
                foreach($server in $LdapConnection.Directory.Servers)
                {
                    if($server -in $script:ConnectionParams.Keys)
                    {
                        $connectionParam=$script:ConnectionParams[$server]
                        if($null -ne $connectionParam['ServerCertificateValidationFlags'])
                        {
                            $chain.ChainPolicy.VerificationFlags = $connectionParam['ServerCertificateValidationFlags']
                            break;
                        }
                    }
                }
                $result = $chain.Build($Certificate)
                return $result
            }
        }
        
        if($null -ne $ClientCertificate)
        {
            $connectionParams['ClientCertificate'] = $ClientCertificate
            #client certificate retrieval callback
            #we just support explicit certificate now
            $LdapConnection.SessionOptions.QueryClientCertificate = { param(
                [Parameter(Mandatory)][DirectoryServices.Protocols.LdapConnection]$LdapConnection,
                [Parameter(Mandatory)][byte[][]]$TrustedCAs
            )
                $clientCert = $null
                foreach($server in $LdapConnection.Directory.Servers)
                {
                    if($server -in $script:ConnectionParams.Keys)
                    {
                        $connectionParam=$script:ConnectionParams[$server]
                        if($null -ne $connectionParam['ClientCertificate'])
                        {
                            $clientCert = $connectionParam['ClientCertificate']
                            break;
                        }
                    }
                }
                return $clientCert
            }
        }

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
        if($Timeout -ne [TimeSpan]::Zero)
        {
            $LdapConnection.Timeout = $Timeout
        }

        if($FastConcurrentBind) {
            $LdapConnection.SessionOptions.FastConcurrentBind()
        }
        $script:LdapConnection = $LdapConnection
        $LdapConnection
     }
}
