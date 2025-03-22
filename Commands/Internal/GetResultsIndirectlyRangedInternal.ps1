<#
    Retrieves search results as series of requests: first request just returns list of returned objects, and then each property of each object is loaded by separate request.
    When there is a lot of values in multivalued property (such as 'member' attribute of group), property may be loaded by multiple requests
    Total # of search requests produced is at least (N x P) + 1, where N is # of objects found and P is # of properties loaded for each object
#>
function GetResultsIndirectlyRangedInternal
{
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
        $PropertiesToLoad,

        [parameter()]
        [String[]]
        $AdditionalProperties=@(),

        [parameter()]
        [System.DirectoryServices.Protocols.DirectoryControl[]]
            #additional controls that caller may need to add to request
        $AdditionalControls=@(),

        [parameter()]
        [String[]]
        $IgnoredProperties=@(),

        [parameter()]
        [String[]]
        $BinaryProperties=@(),

        [parameter()]
        [Timespan]
        $Timeout,

        [parameter()]
        [Int32]
        $RangeSize
    )
    begin
    {
        $template=InitializeItemTemplateInternal -props $PropertiesToLoad -additionalProps $AdditionalProperties
    }
    process
    {
        $pagedRqc=$rq.Controls | Where-Object{$_ -is [System.DirectoryServices.Protocols.PageResultRequestControl]}
        $rq.Attributes.AddRange($PropertiesToLoad)
        #load only attribute names now and attribute values later
        $rq.TypesOnly=$true
        while ($true)
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

            #now process the returned list of distinguishedNames and fetch required properties directly from returned objects
            foreach ($sr in $rsp.Entries)
            {
                $data=$template.Clone()

                $rqAttr=new-object System.DirectoryServices.Protocols.SearchRequest
                $rqAttr.DistinguishedName=$sr.DistinguishedName
                $rqAttr.Scope="Base"
                $rqAttr.Controls.AddRange($AdditionalControls)

                #loading just attributes indicated as present in first search
                foreach($attrName in $sr.Attributes.AttributeNames) {
                    $targetAttrName = GetTargetAttr -attr $attrName
                    if($IgnoredProperties -contains $targetAttrName) {continue}
                    if($targetAttrName -ne $attrName)
                    {
                        #skip paging hint
                        Write-Verbose "Skipping paging hint: $attrName"
                        continue
                    }
                    $transform = $script:RegisteredTransforms[$attrName]
                    $BinaryInput = ($null -ne $transform -and $transform.BinaryInput -eq $true) -or ($attrName -in $BinaryProperties)
                    $start=-$rangeSize
                    $lastRange=$false
                    while ($lastRange -eq $false) {
                        $start += $rangeSize
                        $rng = "$($attrName.ToLower());range=$start`-$($start+$rangeSize-1)"
                        $rqAttr.Attributes.Clear() | Out-Null
                        $rqAttr.Attributes.Add($rng) | Out-Null
                        $rspAttr = $LdapConnection.SendRequest($rqAttr)
                        foreach ($srAttr in $rspAttr.Entries) {
                            #LDAP server changes upper bound to * on last chunk
                            $returnedAttrName=$($srAttr.Attributes.AttributeNames)
                            #load binary properties as byte stream, other properties as strings
                            if($BinaryInput) {
                                $data[$attrName]+=$srAttr.Attributes[$returnedAttrName].GetValues([byte[]])
                            } else {
                                $data[$attrName] += $srAttr.Attributes[$returnedAttrName].GetValues([string])
                            }
                            if($returnedAttrName.EndsWith("-*") -or $returnedAttrName -eq $attrName) {
                                #last chunk arrived
                                $lastRange = $true
                            }
                        }
                    }

                    #perform transform if registered
                    if($null -ne $transform -and $null -ne $transform.OnLoad)
                    {
                        $data[$attrName] = (& $transform.OnLoad -Values $data[$attrName])
                    }
                }
                if([string]::IsNullOrEmpty($data['distinguishedName'])) {
                    #dn has to be present on all objects
                    $transform = $script:RegisteredTransforms['distinguishedName']
                    if($null -ne $transform -and $null -ne $transform.OnLoad)
                    {
                        $data['distinguishedName'] = & $transform.OnLoad -Values $sr.DistinguishedName
                    } else {
                        $data['distinguishedName']=$sr.DistinguishedName
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
