<#
    Helper that creates output object template used by Find-LdapObject command, based on required properties to be returned
#>
Function InitializeItemTemplateInternal
{
    param
    (
        [string[]]$props,
        [string[]]$additionalProps
    )

    process
    {
        $template=@{}
        foreach($prop in $additionalProps) {$template[$prop]= $null}
        foreach($prop in $props) {$template[$prop]=$null}
        $template
    }
}
