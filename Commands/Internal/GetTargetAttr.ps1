<#
    Process ragnged retrieval hints
#>
function GetTargetAttr
{
    param
    (
        [Parameter(Mandatory)]
        [string]$attr
    )

    process
    {
        $targetAttr = $attr
        $m = [System.Text.RegularExpressions.Regex]::Match($attr,';range=.+');  #this is to skip range hints provided by DC
        if($m.Success)
        {
            $targetAttr = $($attr.Substring(0,$m.Index))
        }
        $targetAttr
    }
}
