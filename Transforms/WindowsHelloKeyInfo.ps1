
[CmdletBinding()]
param (
    [Parameter()]
    [Switch]
    $FullLoad
)

#see [MS-ADTS] 2.2.20 (https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-adts/de61eb56-b75f-4743-b8af-e9be154b47af)
if($FullLoad)
{
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Text;

public enum KeyCredentialEntryType
{
    KeyID=1,
    KeyHash=2,
    KeyMaterial=3,
    KeyUsage=4,
    KeySource=5,
    DeviceId=6,
    CustomKeyInformation=7,
    KeyApproximateLastLogonTimeStamp=8,
    KeyCreationTime=9
}

public enum KeyUsage
{
    AdminKey=0,
    NGC=1,
    STK=2,
    BitLockerRecovery=3,
    FIDO=7,
    FEK=8,
    OTHER=int.MinValue
}

public enum KeySource
{
    AD=0,
    AzureAD=1,
    OTHER=int.MinValue
}

[Flags]
public enum CustomKeyFlags
{
    CUSTOMKEYINFO_FLAGS_ATTESTATION=1,
    CUSTOMKEYINFO_FLAGS_MFA_NOT_USED = 2
}

public enum VolType
{
    None=0,
    OSV=1,
    FDV=2,
    RDV=3
}

public enum KeyStrength
{
    Unknown=0,
    Weak=1,
    Normal=2
}

public class CustomKeyInformation
{
    public byte Version { get; private set; }
    public CustomKeyFlags Flags { get; private set; }

    public CustomKeyInformation(string data)
    {
        if (data.Length > 1)
            Version = Convert.ToByte(data.Substring(0, 2), 16);
        if (data.Length > 3)
            Flags = (CustomKeyFlags)Convert.ToByte(data.Substring(2, 2), 16);
    }
}

public class CustomKeyInformation2:CustomKeyInformation
{
    public VolType VolumeType;
    public bool SupportsNotification;
    public byte FekKeyVersion;
    public KeyStrength KeyStrength;
    public CustomKeyInformation2(string data):base(data)
    {
        if(data.Length > 13)
            KeyStrength = (KeyStrength)Convert.ToByte(data.Substring(12, 2), 16);
        if (data.Length > 11)
            FekKeyVersion = Convert.ToByte(data.Substring(10, 2), 16);
        if (data.Length > 9)
        {
            if (data.Substring(8, 2) != "00")
                SupportsNotification = true;
            else
                SupportsNotification = false;
        }
        if(data.Length > 7)
            VolumeType = (VolType)Convert.ToByte(data.Substring(6, 2), 16);
    }
}

public class KeyCredentialEntry
{
    public byte Usage { get; protected set; }
    public byte[] Value;

    public KeyCredentialEntry(byte usage, byte[] value)
    {
        Usage = usage;
        Value = value;
    }
}
public class KeyCredentialInfo
{
    //values coming from record
    public UInt32 Version { get; private set; }
    public KeyCredentialEntry[] OtherEntries;
    public string DN { get; private set; }
    //values retrieved from subrecords
    public byte[] KeyId { get; private set; }
    public byte[] KeyHash { get; private set; }
    public byte[] KeyMaterial { get; private set; }
    public KeyUsage KeyUsage { get; private set; }
    public KeySource KeySource { get; private set; }
    public Guid DeviceId { get; private set; }
    public CustomKeyInformation KeyCustomInfo { get; private set; }
    public DateTime KeyLastLogonTime { get; private set; }
    public DateTime KeyCreatedTime { get; private set; }

    public override string ToString()
    {
        return string.Format("{0}:{1}:{2}", (Version >> 8), KeySource, KeyUsage);
    }

    public KeyCredentialInfo(string value)
    {
        var vals = value.Split(':');
        DN = vals[3];
        string blob = vals[2];
        List<KeyCredentialEntry> list = new List<KeyCredentialEntry>();
        int start = 0;
        var s = blob.Substring(start, 8);
        s = ReverseByteArrayString(s);
        Version = Convert.ToUInt32(s, 16);

        start += 8;
        while(start < blob.Length)
        {
            var length = Convert.ToUInt16(
                ReverseByteArrayString(
                    blob.Substring(start, 4)
                    ),
                16)*2;
            
            byte usage =Convert.ToByte(blob.Substring(start + 4, 2));
            string rawValue = blob.Substring(start + 6, length);
            start += ((length) + 4 + 2);
            switch (usage)
            {
                case 1:
                    KeyId = ByteArrayStringToByteArray(rawValue);
                    break;
                case 2:
                    KeyHash = ByteArrayStringToByteArray(rawValue);
                    break;
                case 3:
                    KeyMaterial = ByteArrayStringToByteArray(rawValue);
                    break;
                case 4:
                    try
                    {
                        KeyUsage = (KeyUsage)Convert.ToByte(rawValue);
                    }
                    catch (Exception)
                    {

                        KeyUsage = KeyUsage.OTHER;
                    }
                    break;
                case 5:
                    try
                    {
                        KeySource = (KeySource)Convert.ToByte(rawValue);
                    }
                    catch (Exception)
                    {
                        KeySource = KeySource.OTHER;
                    }
                    break;
                case 6:
                    DeviceId = new Guid(ByteArrayStringToByteArray(rawValue));
                    break;
                case 7:
                    if (rawValue.Length == 4)
                        KeyCustomInfo = new CustomKeyInformation(rawValue);
                    else
                        KeyCustomInfo = new CustomKeyInformation2(rawValue);
                    break;
                case 8:
                    switch (KeySource)
                    {
                        case KeySource.AD:
                            KeyLastLogonTime = DateTime.FromFileTime(LongFromByteArrayString(rawValue));
                            break;
                        case KeySource.AzureAD:
                            KeyLastLogonTime = DateTime.FromBinary(LongFromByteArrayString(rawValue));
                            break;
                    }
                    break;
                case 9:
                    switch (KeySource)
                    {
                        case KeySource.AD:
                            KeyCreatedTime = DateTime.FromFileTime(LongFromByteArrayString(rawValue));
                            break;
                        case KeySource.AzureAD:
                            KeyCreatedTime = DateTime.FromBinary(LongFromByteArrayString(rawValue));
                            break;
                    }
                    break;
                default:
                    list.Add(new KeyCredentialEntry(usage, ByteArrayStringToByteArray(rawValue)));
                    break;
            }
        }
        OtherEntries = list.ToArray();
    }

    #region Helpers
    protected static long LongFromByteArrayString(string s)
    {
        byte[] b = ByteArrayStringToByteArray(s);
        Int64 ft = BitConverter.ToInt64(b, 0);
        return ft;
    }
    protected static byte[] ByteArrayStringToByteArray(string s)
    {
        int idx = 0;
        List<byte> list = new List<byte>();
        while (idx < s.Length - 1)
        {
            list.Add(Convert.ToByte(s.Substring(idx, 2), 16));
            idx += 2;
        }
        return list.ToArray();
    }

    protected static string ReverseByteArrayString(string s)
    {
        int idx = s.Length;
        StringBuilder sb = new StringBuilder();
        while (idx > 0)
        {
            idx -= 2;
            sb.Append(s.Substring(idx, 2));
        }
        return sb.ToString();
    }

    #endregion
}
'@
}

#add attributes that can be used with this transform
$SupportedAttributes = @('msDs-KeyCredentialLink')

# This is mandatory definition of transform that is expected by transform architecture
$codeBlock= New-LdapAttributeTransformDefinition -SupportedAttributes $SupportedAttributes

$codeBlock.OnLoad = { 
    param(
    [string[]]$Values
    )
    Process
    {
        foreach($Value in $Values)
        {
            new-object KeyCredentialInfo($Value)
        }
    }
}

$codeBlock

