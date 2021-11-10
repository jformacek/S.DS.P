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
    public ProxyAddress(string addressType, string address, bool isPrimary)
    {
        if (null == addressType || null == address)
            throw new ArgumentException("Address and AddressType cannot be null");

        Address = address;
        if(isPrimary)
            AddressType = addressType.ToUpper();
        else
            AddressType = addressType.ToLower();
    }
    
    public override string ToString()
    {
        if (AddressType == string.Empty)
            return Address;

        return string.Format("{0}:{1}", AddressType, Address);
    }

    public bool Equals(ProxyAddress other)
    {
        return (string.Compare(this.Address,other.Address,true) == 0 && string.Compare(this.AddressType,other.AddressType,true)==0);
    }
}
'@
}

$codeBlock= New-LdapAttributeTransformDefinition -SupportedAttributes @('proxyAddresses','targetAddress')

$codeBlock.OnLoad = { 
    param(
    [string[]]$Values
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
