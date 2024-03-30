$script:RegisteredTransforms = @{}
$referencedAssemblies=@()
if($PSVersionTable.PSEdition -eq 'Core') {$referencedAssemblies+='System.Security.Principal.Windows'}

#Add compiled helpers. Load only if not loaded previously
$helpers = 'Flattener', 'NamingContext'
foreach($helper in $helpers) {
    if($null -eq ($helper -as [type])) {
        $definition = Get-Content "$PSScriptRoot\Helpers\$helper.cs" -Raw
        Add-Type -TypeDefinition $definition -ReferencedAssemblies $referencedAssemblies -WarningAction SilentlyContinue -IgnoreWarnings
    }
}
