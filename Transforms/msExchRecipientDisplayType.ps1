[CmdletBinding()]
param (
    [Parameter()]
    [Switch]
    $FullLoad
)

if($FullLoad)
{
# From http://blog.petersenit.co.uk/2017/07/msexchrecipientdisplaytype-and.html
Add-Type @'
using System;
public enum RecipientType
{
    SharedMailbox = 0x0,
    MailUniversalDistributionGroup = 0x1,
    MailContact = 0x6,
    RoomMailbox = 0x7,
    EquipmentMailbox = 0x8,
    ACLableMailboxUser = 1073741824,
    MailUniversalSecurityGroup = 1073741833,
    SyncedMailboxUser = -2147483642,
    SyncedUDGasUDG = -2147483391,
    SyncedUDGasContact = -2147483386,
    SyncedPublicFolder = -2147483130,
    SyncedDynamicDistributionGroup = -2147482874,
    SyncedRemoteMailUser = -2147482106,
    SyncedConferenceRoomMailbox = -2147481850,
    SyncedEquipmentMailbox = -2147481594,
    SyncedUSGasUDG = -2147481343,
    SyncedUSGasContact = -2147481338,
    ACLableSyncedMailboxUser = -1073741818,
    ACLableSyncedRemoteMailUser = -1073740282,
    ACLableSyncedUSGasContact = -1073739514,
    SyncedUSGasUSG = -1073739511
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
            [RecipientType].GetEnumValues().ForEach({if([int]$Value -eq $_) {$_}})
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
