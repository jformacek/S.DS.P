# Add any types that are used by transforms
# CSharp types added via Add-Type are supported

'Load','Save' | ForEach-Object {
    $TransformName = 'FileTime'
    #add attributes that can be used with this transform
    $SupportedAttributes = @('badPasswordTime','lastLogon','lastLogonTimestamp','ms-Mcs-AdmPwdExpirationTime')
    $Action = $_
    # This is mandatory definition of transform that is expected by transform architecture
    $prop=[Ordered]@{
        Name=$TransformName
        Action=$Action
        SupportedAttributes=$SupportedAttributes
        Transform = $null
    }
    $codeBlock = new-object PSCustomObject -property $prop
    switch($Action)
    {
        "Load"
        {
            #transform that executes when loading attribute from LDAP server
            $codeBlock.Transform = { 
                param(
                [long[]]$Values
                )
                Process
                {
                    foreach($Value in $Values)
                    {
                        [DateTime]::FromFileTimeUtc($Value)
                    }
                }
            }
            $codeBlock
            break;
        }
        "Save"
        {
            #transform that executes when loading attribute from LDAP server
            $codeBlock.Transform = { 
                param(
                [DateTime[]]$Values
                )
                
                Process
                {
                    foreach($Value in $Values)
                    {
                        $Value.ToFileTimeUtc()
                    }
                }
            }
            $codeBlock
            break;
        }
    }
}
