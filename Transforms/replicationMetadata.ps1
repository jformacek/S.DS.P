
[CmdletBinding()]
param (
    [Parameter()]
    [Switch]
    $FullLoad
)

$codeBlock= New-LdapAttributeTransformDefinition -SupportedAttributes @('msDS-ReplAttributeMetaData','msDS-ReplValueMetaData','msDS-NCReplCursors','msDS-NCReplInboundNeighbors')

$codeBlock.OnLoad = { 
    param(
    [string[]]$Values
    )
    Process
    {
        foreach($Value in $Values)
        {
            [xml]$Value.SubString(0,$Value.Length-2)
        }
    }
}
$codeBlock.OnSave = { 
    param(
    [System.Xml.XmlDocument[]]$Values
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

