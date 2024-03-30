param
(
    [string]$rootPath = '.',
    [string]$moduleName = "S.DS.P"
)
$moduleFile = "$rootPath\Module\$moduleName\$moduleName.psm1"
'#region Public commands' | Out-File -FilePath $moduleFile
foreach($file in Get-ChildItem -Path "$rootPath\Commands\Public")
{
    Get-Content $file.FullName | Out-File -FilePath $moduleFile -Append
}
'#endregion Public commands' | Out-File -FilePath $moduleFile -Append
'' | Out-File -FilePath $moduleFile -Append

'#region Internal commands' | Out-File -FilePath $moduleFile -Append
foreach($file in Get-ChildItem -Path "$rootPath\Commands\Internal")
{
    Get-Content $file.FullName | Out-File -FilePath $moduleFile -Append
}
'#endregion Internal commands' | Out-File -FilePath $moduleFile -Append
'' | Out-File -FilePath $moduleFile -Append

'#region Module initialization' | Out-File -FilePath $moduleFile -Append
Get-Content "$rootPath\Commands\ModuleInitialization.ps1" | Out-File -FilePath $moduleFile -Append
'#endregion Module initialization' | Out-File -FilePath $moduleFile -Append
