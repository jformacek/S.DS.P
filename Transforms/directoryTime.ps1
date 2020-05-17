# Add any types that are used by transforms
# CSharp types added via Add-Type are supported

'Load','Save' | ForEach-Object {
    $TransformName = 'directoryTime'
    #add attributes that can be used with this transform
    $SupportedAttributes = @('createTimestamp','dsCorePropagationData','modifyTimestamp','whenCreated','whenChanged')
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
                [string[]]$Values
                )
                Process
                {
                    foreach($Value in $Values)
                    {
                        [DateTime]::ParseExact($val,'yyyyMMddHHmmss.fZ',[CultureInfo]::InvariantCulture,[System.Globalization.DateTimeStyles]::None)                    }
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
                [datetime[]]$Values
                )
                
                Process
                {
                    foreach($Value in $Values)
                    {
                        $Value.ToString('yyyyMMddHHmmss.0Z')
                    }
                }
            }
            $codeBlock
            break;
        }
    }
}
