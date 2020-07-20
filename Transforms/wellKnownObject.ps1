
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
    public class WellKnownObject
    {
        public Guid wellKnownGuid;
        public string distinguishedName;

        public WellKnownObject(Guid wellKnownGuid, string distinguishedName)
        {
            this.wellKnownGuid = wellKnownGuid;
            this.distinguishedName = distinguishedName;
        }
        public WellKnownObject(string value)
        {
            var vals = value.Split(new char[] {':'},StringSplitOptions.None);
            wellKnownGuid = new Guid(vals[2]);
            distinguishedName = vals[3];
        }
        public override string ToString()
        {
            return string.Format("{0}:{1}", wellKnownGuid.ToString(), distinguishedName);
        }
        public string ToDirectoryFormat()
        {
            string g = wellKnownGuid.ToString().Replace("-", "");
            return string.Format("B:{0}:{1}:{2}", g.Length, g, distinguishedName);
        }
        public string GetBinding(string containerDN)
        {
            return string.Format("<WKGUID={0},{1}>",wellKnownGuid.ToString().Replace("-",""),containerDN);
        }
    }
'@
}

#add attributes that can be used with this transform
$SupportedAttributes = @('wellKnownObjects','otherWellKnownObjects')

# This is mandatory definition of transform that is expected by transform architecture
$prop=[Ordered]@{
    SupportedAttributes=$SupportedAttributes
    OnLoad = $null
    OnSave = $null
}
$codeBlock = new-object PSCustomObject -property $prop
$codeBlock.OnLoad = { 
    param(
    [object[]]$Values
    )
    Process
    {
        foreach($Value in $Values)
        {
            new-object WellKnownObject($value);
        }
    }
}
$codeBlock.OnSave = { 
    param(
    [WellKnownObject[]]$Values
    )
    
    Process
    {
        foreach($Value in $Values)
        {
            $Value.ToDirectoryFormat();
        }
    }
}
$codeBlock

