# Internal holder of registered transforms
Function Register-LdapAttributeTransform
{
<#
.SYNOPSIS
    Registers attribute transform logic

.DESCRIPTION
    Registered attribute transforms are used by various cmdlets to convert value to/from format used by LDAP server to/from more convenient format
    Sample transforms can be found in GitHub repository, including template for creation of new transforms

.OUTPUTS
    Nothing

.EXAMPLE
$Ldap = Get-LdapConnection -LdapServer "mydc.mydomain.com" -EncryptionType Kerberos
#get list of available transforms
Get-LdapAttributeTransform -ListAvailable

#register transform for specific attributes only
Register-LdapAttributeTransform -Name Guid -AttributeName objectGuid
Register-LdapAttributeTransform -Name SecurityDescriptor -AttributeName ntSecurityDescriptor

#register for all supported attributes
Register-LdapAttributeTransform -Name Certificate

#find objects, applying registered transforms as necessary
# Notice that for attributes processed by a transform, there is no need to specify them in -BinaryProps parameter: transform 'knows' if it's binary or not
Find-LdapObject -LdapConnection $Ldap -SearchBase "cn=User1,cn=Users,dc=mydomain,dc=com" -SearchScope Base -PropertiesToLoad 'cn','ntSecurityDescriptor','userCert,'userCertificate'

Decription
----------
This example registers transform that converts raw byte array in ntSecurityDescriptor property into instance of System.DirectoryServices.ActiveDirectorySecurity
After command completes, returned object(s) will have instance of System.DirectoryServices.ActiveDirectorySecurity in ntSecurityDescriptor property

.EXAMPLE
$Ldap = Get-LdapConnection -LdapServer "mydc.mydomain.com" -EncryptionType Kerberos
#register all available transforms
Get-LdapAttributeTransform -ListAvailable | Register-LdapAttributeTransform
#find objects, applying registered transforms as necessary
# Notice that for attributes processed by a transform, there is no need to specify them in -BinaryProps parameter: transform 'knows' if it's binary or not
Find-LdapObject -LdapConnection $Ldap -SearchBase "cn=User1,cn=Users,dc=mydomain,dc=com" -SearchScope Base -PropertiesToLoad 'cn','ntSecurityDescriptor','userCert,'userCertificate'

.LINK
More about System.DirectoryServices.Protocols: http://msdn.microsoft.com/en-us/library/bb332056.aspx
More about attribute transforms and how to create them: https://github.com/jformacek/S.DS.P/tree/master/Transforms
Template for creation of new transforms: https://github.com/jformacek/S.DS.P/blob/master/TransformTemplate/_Template.ps1
#>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory,ParameterSetName='Name', Position=0)]
        [string]
            #Name of the transform
        $Name,
        [Parameter()]
        [string]
            #Name of the attribute that will be processed by transform
            #If not specified, transform will be registered on all supported attributes
        $AttributeName,
        [Parameter(Mandatory,ValueFromPipeline,ParameterSetName='TransformObject', Position=0)]
        [PSCustomObject]
            #Transform object produced by Get-LdapAttributeTransform
        $Transform,
        [Parameter(Mandatory,ValueFromPipeline,ParameterSetName='TransformFilePath', Position=0)]
        [string]
            #Full path to transform file
        $TransformFile,
        [switch]
            #Force registration of transform, even if the attribute is not contained in the list of supported attributes
        $Force
    )

    Process
    {
        switch($PSCmdlet.ParameterSetName)
        {
            'TransformObject' {
                $TransformFile = "$PSScriptRoot\Transforms\$($transform.TransformName).ps1"
                $Name = $transform.TransformName
                break;
            }
            'Name' {
                $TransformFile = "$PSScriptRoot\Transforms\$Name.ps1"
                break;
            }
            'TransformFile' {
                $Name = [System.IO.Path]::GetFileNameWithoutExtension($transformFile)
                break;
            }
        }

        if(-not (Test-Path -Path "$TransformFile") )
        {
            throw new-object System.ArgumentException "Transform "$TransformFile" not found"
        }

        $SupportedAttributes = (& "$TransformFile").SupportedAttributes
        switch($PSCmdlet.ParameterSetName)
        {
            'Name' {
                if([string]::IsNullOrEmpty($AttributeName))
                {
                    $attribs = $SupportedAttributes
                }
                else
                {
                    if(($supportedAttributes -contains $AttributeName) -or $Force)
                    {
                        $attribs = @($AttributeName)
                    }
                    else {
                        throw new-object System.ArgumentException "Transform $Name does not support attribute $AttributeName"
                    }
                }
                break;
            }
            default {
                $attribs = $SupportedAttributes
                break;
            }
        }
        foreach($attr in $attribs)
        {
            $t = (. "$TransformFile" -FullLoad)
            $script:RegisteredTransforms[$attr] = $t | Add-Member -MemberType NoteProperty -Name 'Name' -Value $Name -PassThru
        }
    }
}
