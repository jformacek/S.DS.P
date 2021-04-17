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
public enum RecipientType
{
    SharedMailbox = 0x0,
    MailUniversalDistributionGroup = 0x1,
    MailContact = 0x6,
    RoomMailbox = 0x7,
    EquipmentMailbox = 0x8,
    UserMailbox = 1073741824,
    MailUniversalSecurityGroup = 1073741833,
    RemoteUserMailbox = -2147483642,
    RemoteRoomMailbox = -2147481850,
    RemoteEquipmentMailbox = -2147481594
}
'@
}

#add attributes that can be processed by this transform
$SupportedAttributes = @('msExchRecipientDisplayType')

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
            [RecipientType].GetEnumValues().ForEach({if($Value -eq $_) {$_}})
        }
    }
}
$codeBlock.OnSave = { 
    param(
    [RecipientType[]]$Values
    )
    
    Process
    {
        foreach($Value in $Values)
        {
            [BitConverter]::ToInt32([BitConverter]::GetBytes([Int32]$value),0)
        }
    }
}
$codeBlock
