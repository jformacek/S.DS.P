function GetDnFromInput
{
    Param (
        [parameter(Mandatory = $true, ValueFromPipeline=$true)]
        [Object]
            #DN string or object with distinguishedName property
        $Object
    )

    process
    {
        if($null -ne $Object)
        {
            #we support pipelining of strings or DistinguishedName types, or objects containing distinguishedName property - string or DistinguishedName
            switch($Object.GetType().Name) {
                "String"
                {
                    $dn = $Object
                    break;
                }
                'DistinguishedName' {
                    $dn=$Object.ToString()
                    break;
                }
                default
                {
                    if($null -ne $Object.distinguishedName)
                    {
                        #covers both string and DistinguishedName types
                        $dn=$Object.distinguishedName.ToString()
                    }
                }
            }
        }
        if([string]::IsNullOrEmpty($dn)) {
            throw (new-object System.ArgumentException("Distinguished name not present on input object"))
        }
				$dn
    }
}