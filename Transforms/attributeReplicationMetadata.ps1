
'Load','Save' | ForEach-Object {
    $TransformName = 'attributeReplicationMetadata'
    #add attributes that can be used with this transform
    $SupportedAttributes = @('msDS-ReplAttributeMetaData')
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
                [object[]]$Values
                )
                Process
                {
                    foreach($Value in $Values)
                    {
                        [xml]$Value
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
                [object[]]$Values
                )
                
                Process
                {
                    foreach($Value in $Values)
                    {
                        $Value.InnerXml
                    }
                }
            }
            $codeBlock
            break;
        }
    }
}
