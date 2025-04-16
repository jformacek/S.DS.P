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
    using System.Text;

    public static class SecurityIdentifierExtensions
    {
        public static string ToLdapSearchableString(this System.Security.Principal.SecurityIdentifier sid)
        {
            StringBuilder sb = new StringBuilder();
            var bytes = new byte[sid.BinaryLength];
            sid.GetBinaryForm(bytes, 0);
            foreach(var v in bytes)
            {
                sb.Append("\\");
                sb.Append(v.ToString("X2"));
            }
            return sb.ToString();
        }
    }
'@

}
$codeBlock= New-LdapAttributeTransformDefinition -SupportedAttributes @('objectSid','tokenGroups','tokenGroupsGlobalAndUniversal','tokenGroupsNoGCAcceptable','sidHistory') -BinaryInput

$codeBlock.OnLoad = { 
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
$codeBlock.OnSave = { 
    param(
    [system.security.principal.securityidentifier[]]$Values
    )
    
    Process
    {
        foreach($sid in $Values)
        {
            $retVal=new-object system.byte[]($sid.BinaryLength)
            $sid.GetBinaryForm($retVal,0)
            ,($retVal)
        }
    }
}
$codeBlock
