Function Get-RootDSE {
    <#
    .SYNOPSIS
        Connects to LDAP server and retrieves metadata
    
    .DESCRIPTION
        Retrieves LDAP server metadata from Root DSE object
        Current implementation is specialized to metadata foung on Windows LDAP server, so on other platforms, some metadata may be empty.
        Or other platforms may publish interesting metadata not available on Windwos LDAP - feel free to add here
    
    .OUTPUTS
        Custom object containing information about LDAP server
    
    .EXAMPLE
    Get-LdapConnection | Get-RootDSE
    
    Description
    -----------
    This command connects to closest domain controller of caller's domain on port 389 and returns metadata about the server
    
    .EXAMPLE
    #connect to server and authenticate with client certificate
    $thumb = '059d5318118e61fe54fd361ae07baf4644a67347'
    cert = (dir Cert:\CurrentUser\my).Where{$_.Thumbprint -eq $Thumb}[0]
    Get-LdapConnection -LdapServer "mydc.mydomain.com" `
      -Port 636 `
      -ClientCertificate $cert `
      -CertificateValidationFlags [System.Security.Cryptography.X509Certificates.X509VerificationFlags]::IgnoreRootRevocationUnknown
    
    Description
    -----------
    Gets Ldap connection authenticated by client certificate authentication and allowing server certificate from CA with unavailable CRL.
    
    .LINK
    More about System.DirectoryServices.Protocols: http://msdn.microsoft.com/en-us/library/bb332056.aspx
    #>
    
    Param (
        [parameter(ValueFromPipeline = $true)]
        [System.DirectoryServices.Protocols.LdapConnection]
            #existing LDAPConnection object retrieved via Get-LdapConnection
            #When we perform many searches, it is more effective to use the same connection rather than create new connection for each search request.
        $LdapConnection = $script:LdapConnection
    )
    Begin
    {
        EnsureLdapConnection -LdapConnection $LdapConnection

        #initialize output objects via hashtable --> faster than add-member
        #create default initializer beforehand
        $propDef=[ordered]@{`
            rootDomainNamingContext=$null; configurationNamingContext=$null; schemaNamingContext=$null; `
            'defaultNamingContext'=$null; 'namingContexts'=$null; `
            'dnsHostName'=$null; 'ldapServiceName'=$null; 'dsServiceName'=$null; 'serverName'=$null;`
            'supportedLdapPolicies'=$null; 'supportedSASLMechanisms'=$null; 'supportedControl'=$null; 'supportedConfigurableSettings'=$null; `
            'currentTime'=$null; 'highestCommittedUSN' = $null; 'approximateHighestInternalObjectID'=$null; `
            'dsSchemaAttrCount'=$null; 'dsSchemaClassCount'=$null; 'dsSchemaPrefixCount'=$null; `
            'isGlobalCatalogReady'=$null; 'isSynchronized'=$null; 'pendingPropagations'=$null; `
            'domainControllerFunctionality' = $null; 'domainFunctionality'=$null; 'forestFunctionality'=$null; `
            'subSchemaSubEntry'=$null; `
            'msDS-ReplAllInboundNeighbors'=$null; 'msDS-ReplConnectionFailures'=$null; 'msDS-ReplLinkFailures'=$null; 'msDS-ReplPendingOps'=$null; `
            'dsaVersionString'=$null; 'serviceAccountInfo'=$null; 'LDAPPoliciesEffective'=$null `
        }
    }
    Process {

        #build request
        $rq=new-object System.DirectoryServices.Protocols.SearchRequest
        $rq.Scope =  [System.DirectoryServices.Protocols.SearchScope]::Base
        $rq.Attributes.AddRange($propDef.Keys) | Out-Null

        #try to get extra information with ExtendedDNControl
        #RFC4511: Server MUST ignore unsupported controls marked as not critical
        [System.DirectoryServices.Protocols.ExtendedDNControl]$exRqc = new-object System.DirectoryServices.Protocols.ExtendedDNControl('StandardString')
        $exRqc.IsCritical=$false
        $rq.Controls.Add($exRqc) | Out-Null

        try {
            $rsp=$LdapConnection.SendRequest($rq)
        }
        catch {
            throw $_.Exception
            return
        }
        #if there was error, let the exception go to caller and do not continue

        #sometimes server does not return anything if we ask for property that is not supported by protocol
        if($rsp.Entries.Count -eq 0) {
            return;
        }

        $data=[PSCustomObject]$propDef

        if ($rsp.Entries[0].Attributes['configurationNamingContext']) {
            $data.configurationNamingContext = [NamingContext]::Parse($rsp.Entries[0].Attributes['configurationNamingContext'].GetValues([string])[0])
        }
        if ($rsp.Entries[0].Attributes['schemaNamingContext']) {
            $data.schemaNamingContext = [NamingContext]::Parse(($rsp.Entries[0].Attributes['schemaNamingContext'].GetValues([string]))[0])
        }
        if ($rsp.Entries[0].Attributes['rootDomainNamingContext']) {
            $data.rootDomainNamingContext = [NamingContext]::Parse($rsp.Entries[0].Attributes['rootDomainNamingContext'].GetValues([string])[0])
        }
        if ($rsp.Entries[0].Attributes['defaultNamingContext']) {
            $data.defaultNamingContext = [NamingContext]::Parse($rsp.Entries[0].Attributes['defaultNamingContext'].GetValues([string])[0])
        }
        if($null -ne $rsp.Entries[0].Attributes['approximateHighestInternalObjectID']) {
            try {
                $data.approximateHighestInternalObjectID=[long]::Parse($rsp.Entries[0].Attributes['approximateHighestInternalObjectID'].GetValues([string]))
            }
            catch {
                #it isn't a numeric, just return what's stored without parsing
                $data.approximateHighestInternalObjectID=$rsp.Entries[0].Attributes['approximateHighestInternalObjectID'].GetValues([string])
            }
        }
        if($null -ne $rsp.Entries[0].Attributes['highestCommittedUSN']) {
            try {
                $data.highestCommittedUSN=[long]::Parse($rsp.Entries[0].Attributes['highestCommittedUSN'].GetValues([string]))
            }
            catch {
                #it isn't a numeric, just return what's stored without parsing
                $data.highestCommittedUSN=$rsp.Entries[0].Attributes['highestCommittedUSN'].GetValues([string])
            }
        }
        if($null -ne $rsp.Entries[0].Attributes['currentTime']) {
            $val = ($rsp.Entries[0].Attributes['currentTime'].GetValues([string]))[0]
            try {
                $data.currentTime = [DateTime]::ParseExact($val,'yyyyMMddHHmmss.fZ',[CultureInfo]::InvariantCulture,[System.Globalization.DateTimeStyles]::None)
            }
            catch {
                $data.currentTime=$val
            }
        }
        if($null -ne $rsp.Entries[0].Attributes['dnsHostName']) {
            $data.dnsHostName = ($rsp.Entries[0].Attributes['dnsHostName'].GetValues([string]))[0]
        }
        if($null -ne $rsp.Entries[0].Attributes['ldapServiceName']) {
            $data.ldapServiceName = ($rsp.Entries[0].Attributes['ldapServiceName'].GetValues([string]))[0]
        }
        if($null -ne $rsp.Entries[0].Attributes['dsServiceName']) {
            $val = ($rsp.Entries[0].Attributes['dsServiceName'].GetValues([string]))[0]
            if($val.Contains(';'))
            {
                $data.dsServiceName = $val.Split(';')
            }
            else {
                $data.dsServiceName=$val
            }
        }
        if($null -ne $rsp.Entries[0].Attributes['serverName']) {
            $val = ($rsp.Entries[0].Attributes['serverName'].GetValues([string]))[0]
            if($val.Contains(';'))
            {
                $data.serverName = $val.Split(';')
            }
            else {
                $data.serverName=$val
            }
        }
        if($null -ne $rsp.Entries[0].Attributes['supportedControl']) {
            $data.supportedControl = ( ($rsp.Entries[0].Attributes['supportedControl'].GetValues([string])) | Sort-Object )
        }
        if($null -ne $rsp.Entries[0].Attributes['supportedLdapPolicies']) {
            $data.supportedLdapPolicies = ( ($rsp.Entries[0].Attributes['supportedLdapPolicies'].GetValues([string])) | Sort-Object )
        }
        if($null -ne $rsp.Entries[0].Attributes['supportedSASLMechanisms']) {
            $data.supportedSASLMechanisms = ( ($rsp.Entries[0].Attributes['supportedSASLMechanisms'].GetValues([string])) | Sort-Object )
        }
        if($null -ne $rsp.Entries[0].Attributes['supportedConfigurableSettings']) {
            $data.supportedConfigurableSettings = ( ($rsp.Entries[0].Attributes['supportedConfigurableSettings'].GetValues([string])) | Sort-Object )
        }
        if($null -ne $rsp.Entries[0].Attributes['namingContexts']) {
            $data.namingContexts = @()
            foreach($ctxDef in ($rsp.Entries[0].Attributes['namingContexts'].GetValues([string]))) {
                $data.namingContexts+=[NamingContext]::Parse($ctxDef)
            }
        }
        if($null -ne $rsp.Entries[0].Attributes['dsSchemaAttrCount']) {
            [long]$outVal=-1
            [long]::TryParse($rsp.Entries[0].Attributes['dsSchemaAttrCount'].GetValues([string]),[ref]$outVal) | Out-Null
            $data.dsSchemaAttrCount=$outVal
        }
        if($null -ne $rsp.Entries[0].Attributes['dsSchemaClassCount']) {
            [long]$outVal=-1
            [long]::TryParse($rsp.Entries[0].Attributes['dsSchemaClassCount'].GetValues([string]),[ref]$outVal) | Out-Null
            $data.dsSchemaClassCount=$outVal
        }
        if($null -ne $rsp.Entries[0].Attributes['dsSchemaPrefixCount']) {
            [long]$outVal=-1
            [long]::TryParse($rsp.Entries[0].Attributes['dsSchemaPrefixCount'].GetValues([string]),[ref]$outVal) | Out-Null
            $data.dsSchemaPrefixCount=$outVal
        }
        if($null -ne $rsp.Entries[0].Attributes['isGlobalCatalogReady']) {
            $data.isGlobalCatalogReady=[bool]$rsp.Entries[0].Attributes['isGlobalCatalogReady'].GetValues([string])
        }
        if($null -ne $rsp.Entries[0].Attributes['isSynchronized']) {
            $data.isSynchronized=[bool]$rsp.Entries[0].Attributes['isSynchronized'].GetValues([string])
        }
        if($null -ne $rsp.Entries[0].Attributes['pendingPropagations']) {
            $data.pendingPropagations=$rsp.Entries[0].Attributes['pendingPropagations'].GetValues([string])
        }
        if($null -ne $rsp.Entries[0].Attributes['subSchemaSubEntry']) {
            $data.subSchemaSubEntry=$rsp.Entries[0].Attributes['subSchemaSubEntry'].GetValues([string])[0]
        }
            if($null -ne $rsp.Entries[0].Attributes['domainControllerFunctionality']) {
            $data.domainControllerFunctionality=[int]$rsp.Entries[0].Attributes['domainControllerFunctionality'].GetValues([string])[0]
        }
        if($null -ne $rsp.Entries[0].Attributes['domainFunctionality']) {
            $data.domainFunctionality=[int]$rsp.Entries[0].Attributes['domainFunctionality'].GetValues([string])[0]
        }
        if($null -ne $rsp.Entries[0].Attributes['forestFunctionality']) {
            $data.forestFunctionality=[int]$rsp.Entries[0].Attributes['forestFunctionality'].GetValues([string])[0]
        }
        if($null -ne $rsp.Entries[0].Attributes['msDS-ReplAllInboundNeighbors']) {
            $data.'msDS-ReplAllInboundNeighbors'=@()
            foreach($val in $rsp.Entries[0].Attributes['msDS-ReplAllInboundNeighbors'].GetValues([string])) {
                $data.'msDS-ReplAllInboundNeighbors'+=[xml]$Val.SubString(0,$Val.Length-2)
            }
        }
        if($null -ne $rsp.Entries[0].Attributes['msDS-ReplConnectionFailures']) {
            $data.'msDS-ReplConnectionFailures'=@()
            foreach($val in $rsp.Entries[0].Attributes['msDS-ReplConnectionFailures'].GetValues([string])) {
                $data.'msDS-ReplConnectionFailures'+=[xml]$Val.SubString(0,$Val.Length-2)
            }
        }
        if($null -ne $rsp.Entries[0].Attributes['msDS-ReplLinkFailures']) {
            $data.'msDS-ReplLinkFailures'=@()
            foreach($val in $rsp.Entries[0].Attributes['msDS-ReplLinkFailures'].GetValues([string])) {
                $data.'msDS-ReplLinkFailures'+=[xml]$Val.SubString(0,$Val.Length-2)
            }
        }
        if($null -ne $rsp.Entries[0].Attributes['msDS-ReplPendingOps']) {
            $data.'msDS-ReplPendingOps'=@()
            foreach($val in $rsp.Entries[0].Attributes['msDS-ReplPendingOps'].GetValues([string])) {
                $data.'msDS-ReplPendingOps'+=[xml]$Val.SubString(0,$Val.Length-2)
            }
        }
        if($null -ne $rsp.Entries[0].Attributes['dsaVersionString']) {
            $data.dsaVersionString=$rsp.Entries[0].Attributes['dsaVersionString'].GetValues([string])[0]
        }
        if($null -ne $rsp.Entries[0].Attributes['serviceAccountInfo']) {
            $data.serviceAccountInfo=$rsp.Entries[0].Attributes['serviceAccountInfo'].GetValues([string])
        }
        if($null -ne $rsp.Entries[0].Attributes['LDAPPoliciesEffective']) {
            $data.LDAPPoliciesEffective=@{}
            foreach($val in $rsp.Entries[0].Attributes['LDAPPoliciesEffective'].GetValues([string]))
            {
                $vals=$val.Split(':')
                if($vals.Length -gt 1) {
                    $data.LDAPPoliciesEffective[$vals[0]]=$vals[1]
                }
            }
        }
        $data
    }
}
