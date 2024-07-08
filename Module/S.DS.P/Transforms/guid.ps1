[CmdletBinding()]
param (
    [Parameter()]
    [Switch]
    $FullLoad
)

if($FullLoad)
{
    #helper to convert Guid to ldap searchable string
    add-type -TypeDefinition @'
    using System;
    using System.Text;

    public static class GuidExtensions
    {
        public static string ToLdapSearchableString(this Guid guid)
        {
            StringBuilder sb = new StringBuilder();
            foreach(var v in guid.ToByteArray())
            {
                sb.Append("\\");
                sb.Append(v.ToString("X2"));
            }
            return sb.ToString();
        }
    }
'@

}

$codeBlock= New-LdapAttributeTransformDefinition `
-SupportedAttributes @('appliesTo','attributeSecurityGUID','objectGuid', `
    'mS-DS-ConsistencyGuid','msExchMailboxGuid','schemaIDGUID', `
    'msExchArchiveGUID') `
-BinaryInput

$codeBlock.OnLoad = { 
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
$codeBlock.OnSave = { 
    param(
    [Guid[]]$Values
    )
    
    Process
    {
        foreach($value in $values)
        {
            ,($value.ToByteArray())
        }
    }
}
$codeBlock
