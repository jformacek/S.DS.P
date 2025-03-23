<#
    Retrieves search results as single search request
    Total # of search requests produced is 1
#>
function GetResultsDirectlyInternal
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
        [switch]$NoAttributes
    )
    begin
    {
        $template=InitializeItemTemplateInternal -props $PropertiesToLoad -additionalProps $AdditionalProperties
    }
    process
    {
        $pagedRqc=$rq.Controls | Where-Object{$_ -is [System.DirectoryServices.Protocols.PageResultRequestControl]}
        if($NoAttributes) {
            $rq.Attributes.Add('1.1') | Out-Null
        } else {
            $rq.Attributes.AddRange($propertiesToLoad) | Out-Null
        }
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
                if($null -ne $_.Exception.Response -and $_.Exception.Response.ResultCode -eq 'SizeLimitExceeded')
                {
                    #size limit exceeded
                    $rsp = $_.Exception.Response
                }
                else
                {
                    throw $_.Exception
                }
            }

            foreach ($sr in $rsp.Entries)
            {
                $data=$template.Clone()
                
                foreach($attrName in $sr.Attributes.AttributeNames) {
                    $targetAttrName = GetTargetAttr -attr $attrName
                    if($targetAttrName -in $IgnoredProperties) {continue}
                    if($targetAttrName -ne $attrName)
                    {
                        Write-Warning "Value of attribute $targetAttrName not completely retrieved as it exceeds query policy. Use ranged retrieval. Range hint: $attrName"
                    }
                    else
                    {
                        if($null -ne $data[$attrName])
                        {
                            #we may have already loaded partial results from ranged hint
                            continue
                        }
                    }
                    
                    $transform = $script:RegisteredTransforms[$targetAttrName]
                    $BinaryInput = ($null -ne $transform -and $transform.BinaryInput -eq $true) -or ($targetAttrName -in $BinaryProperties)
                    try {
                        if($null -ne $transform -and $null -ne $transform.OnLoad)
                        {
                            if($BinaryInput -eq $true) {
                                $data[$targetAttrName] = (& $transform.OnLoad -Values ($sr.Attributes[$attrName].GetValues([byte[]])))
                            } else {
                                $data[$targetAttrName] = (& $transform.OnLoad -Values ($sr.Attributes[$attrName].GetValues([string])))
                            }
                        } else {
                            if($BinaryInput -eq $true) {
                                $data[$targetAttrName] = $sr.Attributes[$attrName].GetValues([byte[]])
                            } else {
                                $data[$targetAttrName] = $sr.Attributes[$attrName].GetValues([string])
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
            #the response may contain paged search response. If so, we will need a cookie from it
            [System.DirectoryServices.Protocols.PageResultResponseControl] $prrc=$rsp.Controls | Where-Object{$_ -is [System.DirectoryServices.Protocols.PageResultResponseControl]}
            if($null -ne $prrc -and $prrc.Cookie.Length -ne 0 -and $null -ne $pagedRqc) {
                #pass the search cookie back to server in next paged request
                $pagedRqc.Cookie = $prrc.Cookie;
            } else {
                #either non paged search or we've processed last page
                break;
            }
        }
    }
}
