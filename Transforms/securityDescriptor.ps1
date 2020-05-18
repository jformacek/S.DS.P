# Add any types that are used by transforms
# CSharp types added via Add-Type are supported

'Load','Save' | ForEach-Object {
    $TransformName = 'SecurityDescriptor'
    #add attributes that can be used with this transform
    $SupportedAttributes = @('ntSecurityDescriptor')
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
                        $dacl = new-object System.DirectoryServices.ActiveDirectorySecurity
                        $dacl.SetSecurityDescriptorBinaryForm($value)
                        $dacl
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
                [System.DirectoryServices.ActiveDirectorySecurity[]]$Values
                )
                
                Process
                {
                    foreach($Value in $Values)
                    {
                        $Value.GetSecurityDescriptorBinaryForm()
                    }
                }
            }
            $codeBlock
            break;
        }
    }
}
