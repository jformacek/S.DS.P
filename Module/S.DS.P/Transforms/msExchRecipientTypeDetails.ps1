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
public enum RecipientTypeDetails: long
{
    UserMailbox = 0x1,
    LinkedMailbox = 0x2,
    SharedMailbox = 0x4,
    RoomMailbox = 0x10,
    EquipmentMailbox = 0x20,
    MailContact = 0x40,
    MailUser = 0x80,
    MailUniversalDistributionGroup = 0x100,
    MailNonUniversalGroup = 0x200,
    MailUniversalSecurityGroup = 0x400,
    DynamicDistributionGroup = 0x800,
    PublicFolder = 0x1000,
    SystemAttendantMailbox = 0x2000,
    SystemMailbox = 0x4000,
    MailForestContact = 0x8000,
    User = 0x10000,
    Contact = 0x20000,
    UniversalDistributionGroup = 0x40000,
    UniversalSecurityGroup = 0x80000,
    NonUniversalGroup = 0x100000,
    DisabledUser = 0x200000,
    MicrosoftExchange = 0x400000,
    ArbitrationMailbox = 0x800000,
    MailboxPlan = 0x1000000,
    LinkedUser = 0x2000000,
    RoomList = 0x4000000,
    DiscoveryMailbox = 0x8000000,

    RoleGroup = 1073741824,  //hex does not work here
    RemoteUserMailbox = 2147483648,
    TeamMailbox = 137438953472,
    RemoteTeamMailbox = 274877906944,
    MonitoringMailbox = 549755813888,
    GroupMailbox = 1099511627776,
    RemoteRoomMailbox = 8589934592,
    RemoteEquipmentMailbox = 17179869184,
    RemoteSharedMailbox = 34359738368
}
'@
}

#add attributes that can be processed by this transform
$SupportedAttributes = @('msExchRecipientTypeDetails')

# This is mandatory definition of transform that is expected by transform architecture
$codeBlock = New-LdapAttributeTransformDefinition -SupportedAttributes $SupportedAttributes
$codeBlock.OnLoad = { 
    param(
    [object[]]$Values
    )
    Process
    {
        foreach($Value in $Values)
        {
            [RecipientTypeDetails].GetEnumValues().ForEach({if([Int64]$Value -eq $_) {$_}})
        }
    }
}
$codeBlock.OnSave = { 
    param(
    [RecipientTypeDetails[]]$Values
    )
    
    Process
    {
        foreach($value in $values)
        {
            [BitConverter]::ToInt64([BitConverter]::GetBytes([Int64]$value),0)
        }
    }
}
$codeBlock
