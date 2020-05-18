# Add any types that are used by transforms
# CSharp types added via Add-Type are supported

'Save' | ForEach-Object {
    $TransformName = 'UnicodePwd'
    #add attributes that can be used with this transform
    $SupportedAttributes = @('unicodePwd')
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
        "Save"
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
                        ,([System.Text.Encoding]::Unicode.GetBytes("`"$Value`"") -as [byte[]])                    }
                }
            }
            $codeBlock
            break;
        }
    }
}
