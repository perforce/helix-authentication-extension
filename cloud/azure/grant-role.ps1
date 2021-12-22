<#
Grant the system-assigned managed identity permission to call the application
using the PowerShell module, at least until the web portal supports this feature.

AzureAD module is only supported on Microsoft Windows platforms.
#>

Install-Module AzureAD

<#
Replace the values below for your particular environment.
#>
$TenantID = '719d88f3-f957-44cf-9aa5-0a1a3a44f7b9'
$GraphAppId = '25b17cdb-4c8d-434c-9a21-86d67ac501d1'
$DisplayNameOfMSI = 'managed-vm'
$PermissionName = 'Perforce.Call'

Connect-AzureAD -TenantId $TenantID
$MSI = (Get-AzureADServicePrincipal -Filter "displayName eq '$DisplayNameOfMSI'")
Start-Sleep -Seconds 10
$GraphServicePrincipal = Get-AzureADServicePrincipal -Filter "appId eq '$GraphAppId'"
$AppRole = $GraphServicePrincipal.AppRoles | Where-Object {$_.Value -eq $PermissionName -and $_.AllowedMemberTypes -contains "Application"}
New-AzureAdServiceAppRoleAssignment -ObjectId $MSI.ObjectId -PrincipalId $MSI.ObjectId -ResourceId $GraphServicePrincipal.ObjectId -Id $AppRole.Id
