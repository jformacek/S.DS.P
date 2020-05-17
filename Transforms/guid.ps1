# Add any types that are used by transforms
# CSharp types added via Add-Type are supported

'Load','Save' | ForEach-Object {
    $TransformName = 'guid'
    #add attributes that can be used with this transform
    $SupportedAttributes = @()
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
                [byte[][]]$Values
                )
                Process
                {
                    foreach($Value in $Values)
                    {
                        New-Object System.Guid(,$Value)
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
                [Guid[]]$Values
                )
                
                Process
                {
                    foreach($value in $values)
                    {
                        $value.ToByteArray()
                    }
                }
            }
            $codeBlock
            break;
        }
    }
}
