# Add any types that are used by transforms
# CSharp types added via Add-Type are supported

'Load','Save' | ForEach-Object {
    $TransformName = 'securityIdentifier'
    #add attributes that can be used with this transform
    $SupportedAttributes = @('objectSid')
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
                        New-Object System.Security.Principal.SecurityIdentifier($Value,0)
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
                [system.security.principal.securityidentifier[]]$Values
                )
                
                Process
                {
                    foreach($sid in $Values)
                    {
                        $retVal=new-object system.byte[]($sid.BinaryLength)
                        $sid.GetBinaryForm($retVal,0)
                        $retVal
                    }
                }
            }
            $codeBlock
            break;
        }
    }
}
