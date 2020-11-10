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
public class ProxyAddress:IEquatable<ProxyAddress>
{
    public string AddressType { get; set; }
    public string Address { get; set; }
    public bool IsPrimary
    {
        get
        {
            return AddressType == AddressType.ToUpper();
        }
        set
        {
            if (value)
                AddressType = AddressType.ToUpper();
            else
                AddressType = AddressType.ToLower();
        }
    }
    public ProxyAddress(string Value)
    {
        if (null == Value)
            throw new ArgumentException("Value cannot be null");

        AddressType = string.Empty;
        int idx = Value.IndexOf(':');
        if (idx > -1)
        {
            if (idx > 0)
            {
                AddressType = Value.Substring(0, idx);
            }
            Address = Value.Substring(idx + 1, Value.Length - idx-1);
        }
        else
        {
            Address = Value;
        }
    }
    public override string ToString()
    {
        if (AddressType == string.Empty)
            return Address;

        return string.Format("{0}:{1}", AddressType, Address);
    }

    public bool Equals(ProxyAddress other)
    {
        return (string.Compare(this.Address,other.Address,false) == 0) && (string.Compare(this.AddressType,other.AddressType,false)==0) && (this.IsPrimary == other.IsPrimary);
    }
}
'@
}

$prop=[Ordered]@{
    SupportedAttributes=@('proxyAddresses','targetAddress')
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
            new-object ProxyAddress($Value)
        }
    }
}
$codeBlock.OnSave = { 
    param(
    [ProxyAddress[]]$Values
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
