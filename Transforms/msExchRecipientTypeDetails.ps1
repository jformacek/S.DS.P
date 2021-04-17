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
    MailUser = 0x80,
    RemoteUserMailbox = 2147483648, //hex does not work here
    RemoteRoomMailbox = 8589934592,
    RemoteEquipmentMailbox = 17179869184,
    RemoteSharedMailbox = 34359738368
}
'@
}

#add attributes that can be processed by this transform
$SupportedAttributes = @('msExchRemoteRecipientType')

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
