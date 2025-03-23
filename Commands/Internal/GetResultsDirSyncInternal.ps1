<#
    Retrieves search results as dirsync request
#>
function GetResultsDirSyncInternal
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [System.DirectoryServices.Protocols.SearchRequest]
        $rq,
        [parameter(Mandatory)]
        [System.DirectoryServices.Protocols.LdapConnection]
        $conn,
        [parameter()]
        [String[]]
        $PropertiesToLoad=@(),
        [parameter()]
        [String[]]
        $AdditionalProperties=@(),
        [parameter()]
        [String[]]
        $IgnoredProperties=@(),
        [parameter()]
        [String[]]
        $BinaryProperties=@(),
        [parameter()]
        [Timespan]
        $Timeout,
        [Switch]$ObjectSecurity,
        [switch]$Incremental
    )
    begin
    {
        $template=InitializeItemTemplateInternal -props $PropertiesToLoad -additionalProps $AdditionalProperties
    }
    process
    {
        $DirSyncRqc= new-object System.DirectoryServices.Protocols.DirSyncRequestControl(,$script:DirSyncCookie)
        $DirSyncRqc.Option = [System.DirectoryServices.Protocols.DirectorySynchronizationOptions]::ParentsFirst
        if($ObjectSecurity)
        {
            $DirSyncRqc.Option = $DirSyncRqc.Option -bor [System.DirectoryServices.Protocols.DirectorySynchronizationOptions]::ObjectSecurity
        }
        if($Incremental)
        {
            $DirSyncRqc.Option = $DirSyncRqc.Option -bor [System.DirectoryServices.Protocols.DirectorySynchronizationOptions]::IncrementalValues
        }
        $rq.Controls.Add($DirSyncRqc) | Out-Null
        $rq.Attributes.AddRange($propertiesToLoad) | Out-Null
        
        while($true)
        {
            try
            {
                if($Timeout -ne [timespan]::Zero)
                {
                    $rsp = $conn.SendRequest($rq, $Timeout) -as [System.DirectoryServices.Protocols.SearchResponse]
                }
                else
                {
                    $rsp = $conn.SendRequest($rq) -as [System.DirectoryServices.Protocols.SearchResponse]
                }
            }
            catch [System.DirectoryServices.Protocols.DirectoryOperationException]
            {
                #just throw as we do not have need case for special handling now
                throw $_.Exception
            }

            foreach ($sr in $rsp.Entries)
            {
                $data=$template.Clone()
                
                foreach($attrName in $sr.Attributes.AttributeNames) {
                    $targetAttrName = GetTargetAttr -attr $attrName
                    if($IgnoredProperties -contains $targetAttrName) {continue}
                    if($attrName -ne $targetAttrName)
                    {
                        if($null -eq $data[$targetAttrName])
                        {
                            $data[$targetAttrName] = [PSCustomObject]@{
                                Add=@()
                                Remove=@()
                            }
                        }
                        #we have multival prop chnage --> need special handling
                        #Windows AD/LDS server returns attribute name as '<attr>;range=1-1' for added values and '<attr>;range=0-0' for removed values on forward-linked attributes
                        if($attrName -like '*;range=1-1')
                        {
                            $attributeContainer = {param($val) $data[$targetAttrName].Add=$val}
                        }
                        else {
                            $attributeContainer = {param($val) $data[$targetAttrName].Remove=$val}
                        }
                    }
                    else
                    {
                        $attributeContainer = {param($val) $data[$targetAttrName]=$val}
                    }
                    
                    $transform = $script:RegisteredTransforms[$targetAttrName]
                    $BinaryInput = ($null -ne $transform -and $transform.BinaryInput -eq $true) -or ($targetAttrName -in $BinaryProperties)
                    try {
                        if($null -ne $transform -and $null -ne $transform.OnLoad)
                        {
                            if($BinaryInput -eq $true) {
                                &$attributeContainer (& $transform.OnLoad -Values ($sr.Attributes[$attrName].GetValues([byte[]])))
                            } else {
                                &$attributeContainer (& $transform.OnLoad -Values ($sr.Attributes[$attrName].GetValues([string])))
                            }
                        } else {
                            if($BinaryInput -eq $true) {
                                &$attributeContainer $sr.Attributes[$attrName].GetValues([byte[]])
                            } else {
                                &$attributeContainer $sr.Attributes[$attrName].GetValues([string])
                            }
                        }
                    }
                    catch {
                        Write-Error -ErrorRecord $_
                    }
                }
                
                if([string]::IsNullOrEmpty($data['distinguishedName'])) {
                    #dn has to be present on all objects
                    #having DN processed at the end gives chance to possible transforms on this attribute
                    $transform = $script:RegisteredTransforms['distinguishedName']
                    try {
                        if($null -ne $transform -and $null -ne $transform.OnLoad)
                        {
                            $data['distinguishedName'] = & $transform.OnLoad -Values $sr.DistinguishedName
                        } else {
                            $data['distinguishedName']=$sr.DistinguishedName
                        }
                    }
                    catch {
                        Write-Error -ErrorRecord $_
                    }
                }
                $data
            }
            #the response may contain dirsync response. If so, we will need a cookie from it
            [System.DirectoryServices.Protocols.DirSyncResponseControl] $dsrc=$rsp.Controls | Where-Object{$_ -is [System.DirectoryServices.Protocols.DirSyncResponseControl]}
            if($null -ne $dsrc -and $dsrc.Cookie.Length -ne 0 -and $null -ne $DirSyncRqc) {
                #pass the search cookie back to server in next paged request
                $DirSyncRqc.Cookie = $dsrc.Cookie;
                $script:DirSyncCookie = $dsrc.Cookie
                if(-not $dsrc.MoreData)
                {
                    break;
                }
            } else {
                #either non paged search or we've processed last page
                break;
            }
        }
    }
}
