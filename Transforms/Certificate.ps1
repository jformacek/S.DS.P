[CmdletBinding()]
param (
    [Parameter()]
    [Switch]
    $FullLoad
)

$prop=[Ordered]@{
    SupportedAttributes=@('userCertificate','userCert')
    OnLoad = $null
    OnSave = $null
}
$codeBlock = new-object PSCustomObject -property $prop
$codeBlock.OnLoad = { 
    param(
    [object[]]$Values
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
    [object[]]$Values
    )
    
    Process
    {
        foreach($Value in $Values)
        {
            $Value.RawData
        }
    }
}
$codeBlock

