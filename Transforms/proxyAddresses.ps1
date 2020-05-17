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

'Load','Save' | ForEach-Object {
    $TransformName = 'proxyAddress'
    #add attributes that can be used with this transform
    $SupportedAttributes = @('proxyAddresses')
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
            $codeBlock
            break;
        }
        "Save"
        {
            #transform that executes when loading attribute from LDAP server
            $codeBlock.Transform = { 
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
            break;
        }
    }
}
