[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]
    [ValidateSet('Load','Save')]
    $Action,
    [Parameter(Mandatory=$false)]
    [string]
    $AttributeName = 'proxyAddresses'

)

Add-Type @'
using System;
public class ProxyAddress
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
}
'@

# This is mandatory definition of transform that is expected by transform architecture
$prop=[Ordered]@{[string]'Action'=$Action;'Attribute'=$AttributeName;[string]'Transform' = $null}
$codeBlock = new-object PSCustomObject -property $prop

switch($Action)
{
    "Load"
    {
        $codeBlock.Transform = { 
            param(
            [object[]]$Values
            )
            foreach($Value in $Values)
            {
                new-object ProxyAddress($Value)
            }
        }
        $codeBlock
        break;
    }
    "Save"
    {
        $codeBlock.Transform = { 
            param(
            [ProxyAddress[]]$Values
            )
            
            foreach($Value in $Values)
            {
                $Value.ToString()
            }
        }
        $codeBlock
        break;
    }
}