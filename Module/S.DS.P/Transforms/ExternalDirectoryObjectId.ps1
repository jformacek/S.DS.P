[CmdletBinding()]
param (
    [Parameter()]
    [Switch]
    $FullLoad
)

if($FullLoad)
{
    Add-Type -TypeDefinition `
@'
    using System;
    
    public class ExternalDirectoryObjectId
    {
        public string ObjectClass {get; set;}
        public Guid Id {get; set;}
    
        public ExternalDirectoryObjectId(string rawValue)
        {
            string[] data = rawValue.Split('_');
            ObjectClass = data[0];
            Id = Guid.Parse(data[1]);
        }
    
        public override string ToString()
        {
            return string.Format("{0}_{1}",ObjectClass,Id);
        }
    }
'@
}

#add attributes that can be processed by this transform
$SupportedAttributes = @('msDS-ExternalDirectoryObjectId')

# This is mandatory definition of transform that is expected by transform architecture
$codeBlock = New-LdapAttributeTransformDefinition -SupportedAttributes $SupportedAttributes
$codeBlock.OnLoad = { 
    param(
    [string[]]$Values
    )
    Process
    {
        foreach($Value in $Values)
        {
            new-object ExternalDirectoryObjectId -ArgumentList $value
        }
    }
}
$codeBlock.OnSave = { 
    param(
    [ExternalDirectoryObjectId[]]$Values
    )
    
    Process
    {
        foreach($Value in $Values)
        {
            $Value.ToString()
        }
    }
}
$codeBlock
