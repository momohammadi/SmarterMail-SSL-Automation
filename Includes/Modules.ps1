# Import the WebAdministration module
Import-Module WebAdministration
Import-Module NetSecurity
[System.Reflection.Assembly]::LoadFrom("C:\windows\system32\inetsrv\Microsoft.Web.Administration.dll") | Out-Null
[System.Reflection.Assembly]::LoadFrom("C:\windows\system32\inetsrv\Microsoft.Web.Management.dll") | Out-Null
Add-Type -AssemblyName System.Net.Http