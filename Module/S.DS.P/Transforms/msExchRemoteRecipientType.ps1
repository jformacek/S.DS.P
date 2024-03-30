[CmdletBinding()]
param (
    [Parameter()]
    [Switch]
    $FullLoad
)

if($FullLoad)
{
# From https://answers.microsoft.com/en-us/msoffice/forum/msoffice_o365admin-mso_exchon-mso_o365b/recipient-type-values/7c2620e5-9870-48ba-b5c2-7772c739c651
Add-Type @'
using System;
[Flags]
public enum RemoteRecipientType
{
    Mailbox = 0x1,
    ProvisionArchive = 0x2,
    Migrated = 0x4,
    DeprovisionMailbox = 0x8,
    DeprovisionArchive = 0x10,
    RoomMailbox = 0x20,
    EquipmentMailbox = 0x40,
    //SharedMailbox = RoomMailbox | EquipmentMailbox
}
'@
}

#add attributes that can be processed by this transform
$SupportedAttributes = @('msExchRemoteRecipientType')

# This is mandatory definition of transform that is expected by transform architecture
$codeBlock = New-LdapAttributeTransformDefinition -SupportedAttributes $SupportedAttributes
$codeBlock.OnLoad = { 
    param(
    [string[]]$Values
    )
    Process
    {
        foreach($Value in $Values)
        {
            [RemoteRecipientType].GetEnumValues().ForEach({if(($Value -band $_) -eq $_) {$_}})
        }
    }
}
$codeBlock.OnSave = { 
    param(
    [RemoteRecipientType[]]$Values
    )
    
    Process
    {
        $retVal = 0
        $Values.ForEach({ $retVal = $retVal -bor $_})
        [BitConverter]::ToInt32([BitConverter]::GetBytes($retVal),0)
    }
}
$codeBlock
