[CmdletBinding()]
param (
    [Parameter()]
    [Switch]
    $FullLoad
)

if($FullLoad)
{
Add-Type @'
using System;
public class ExternalDirectoryObjectId
{
    public string Type;
    public string Id;
    public ExternalDirectoryObjectId(string rawData)
    {
        if(string.IsNullOrEmpty(rawData))
            throw new ArgumentException("Parameter must not be empty");
        string[] data = rawData.Split('_');
        if(data.Length <2)
            throw new FormatException("Parameter is not in valid format");
        Type = data[0];
        Id = data[1];
    }
    public override string ToString()
    {
        return string.Format("{0}_{1}",Type, Id);
    }
}
'@
}

#add attributes that can be processed by this transform
$SupportedAttributes = @()

# This is mandatory definition of transform that is expected by transform architecture
$codeBlock = New-LdapAttributeTransformDefinition -SupportedAttributes $SupportedAttributes
$codeBlock.OnLoad = { 
    param(
    [object[]]$Values
    )
    Process
    {
        foreach($Value in $Values)
        {
            new-object ExternalDirectoryObjectId($value)
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
            $value.ToString()
        }
    }
}
$codeBlock
