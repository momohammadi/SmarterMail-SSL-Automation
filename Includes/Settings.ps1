$smarterMailUrl = "https://smartermail-url.com"
#username for use Smartermail API Connection
$apiUser        = "apiuser"
#password for use Smartermail API Connection
$apiPass        = 'apipass'
#self location of script
$workingDir     = "C:\scripts\AutoInstallSSL"
#pfx files directory
$pfxLocation    = "C:\SSL"
#IIS Binding Port for users hostname
$iisPort        = "443"
#IIS Website name
$website        = "Smartermail"







############# Do Not Edit bellow codes ###############
if($pfxPath){
	$certPath=$pfxPath
}

if($pfxPass){
	$password=$pfxPass
}

if($hostname){
	$domain=$hostname
}

if($smtp){
	$smtpPort=$smtp
}

if($imap){
	$imapPort=$imap
}

if($pop){
	$popPort=$pop
}

if($smtmOutboundIp){
	$mailOutputIp=$smtmOutboundIp
}



if(!($iisIPaddress)){
    $iisIPaddress="*"
}

if($iisIp){
  $iisIPaddress=$iisIp
}

if(!($password)){
    $fileName=(Get-ChildItem $pfxLocation |  Where { ! $_.PSIsContainer -and $_.Name -like "*$domain*" }).Basename
    $password=($fileName -split "_")[1]
}

if(!($certPath)){
    $certPath = "$pfxLocation\$domain" + "_" + "$password.pfx"
}

$bindingObject  = New-Object System.Object
$bindingObject | Add-Member -MemberType NoteProperty -name "Website" -value  $website
$bindingObject | Add-Member -MemberType NoteProperty -name "Ipaddress" -value  $iisIPaddress
$bindingObject | Add-Member -MemberType NoteProperty -name "Port" -value  $iisPort
$bindingObject | Add-Member -MemberType NoteProperty -name "Domain" -value  $domain
$bindingObject | Add-Member -MemberType NoteProperty -name "Protocol" -value  'https'