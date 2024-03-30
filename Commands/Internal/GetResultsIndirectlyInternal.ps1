<#
    Retrieves search results as series of requests: first request just returns list of returned objects, and then each object's props are loaded by separate request.
    Total # of search requests produced is N+1, where N is # of objects found
#>

function GetResultsIndirectlyInternal
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
        $PropertiesToLoad=@(),

        [parameter()]
        [String[]]
        $AdditionalProperties=@(),

        [parameter(Mandatory = $false)]
        [System.DirectoryServices.Protocols.DirectoryControl[]]
            #additional controls that caller may need to add to request
        $AdditionalControls=@(),

        [parameter()]
        [String[]]
        $BinaryProperties=@(),

        [parameter()]
        [Timespan]
        $Timeout
    )
    begin
    {
        $template=InitializeItemTemplateInternal -props $PropertiesToLoad -additionalProps $AdditionalProperties
    }
    process
    {
        $pagedRqc=$rq.Controls | Where-Object{$_ -is [System.DirectoryServices.Protocols.PageResultRequestControl]}
        $rq.Attributes.AddRange($propertiesToLoad) | Out-Null
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
                $rqAttr.Attributes.AddRange($sr.Attributes.AttributeNames) | Out-Null
                $rspAttr = $LdapConnection.SendRequest($rqAttr)
                foreach ($srAttr in $rspAttr.Entries) {
                    foreach($attrName in $srAttr.Attributes.AttributeNames) {
                        $targetAttrName = GetTargetAttr -attr $attrName
                        if($targetAttrName -ne $attrName)
                        {
                            Write-Warning "Value of attribute $targetAttrName not completely retrieved as it exceeds query policy. Use ranged retrieval. Range hint: $attrName"
                        }
                        else
                        {
                            if($data[$attrName].Count -gt 0)
                            {
                                #we may have already loaded partial results from ranged hint
                                continue
                            }
                        }

                        $transform = $script:RegisteredTransforms[$targetAttrName]
                        $BinaryInput = ($null -ne $transform -and $transform.BinaryInput -eq $true) -or ($attrName -in $BinaryProperties)
                        #protecting against LDAP servers who don't understand '1.1' prop
                        if($null -ne $transform -and $null -ne $transform.OnLoad)
                        {
                            if($BinaryInput -eq $true) {
                                $data[$targetAttrName] = (& $transform.OnLoad -Values ($srAttr.Attributes[$attrName].GetValues([byte[]])))
                            } else {
                                $data[$targetAttrName] = (& $transform.OnLoad -Values ($srAttr.Attributes[$attrName].GetValues([string])))
                            }
                        } else {
                            if($BinaryInput -eq $true) {
                                $data[$targetAttrName] = $srAttr.Attributes[$attrName].GetValues([byte[]])
                            } else {
                                $data[$targetAttrName] = $srAttr.Attributes[$attrName].GetValues([string])
                            }                                    
                        }
                    }
                }
                if($data['distinguishedName'].Count -eq 0) {
                    #dn has to be present on all objects
                    $data['distinguishedName']=$sr.DistinguishedName
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
