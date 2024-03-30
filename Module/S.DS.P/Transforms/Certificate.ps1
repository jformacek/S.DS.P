[CmdletBinding()]
param (
    [Parameter()]
    [Switch]
    $FullLoad
)

$codeBlock= New-LdapAttributeTransformDefinition -SupportedAttributes @('cACertificate','userCertificate','userCert') -BinaryInput
$codeBlock.OnLoad = { 
    param(
    [byte[][]]$Values
    )
    Process
    {
        foreach($Value in $Values)
        {
            new-object System.Security.Cryptography.X509Certificates.X509Certificate2(,$Value)
        }
    }
}
$codeBlock.OnSave = { 
    param(
    [System.Security.Cryptography.X509Certificates.X509Certificate2[]]$Values
    )
    
    Process
    {
        foreach($Value in $Values)
        {
            ,($Value.RawData)
        }
    }
}
$codeBlock

