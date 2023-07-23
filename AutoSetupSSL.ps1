<#
.SYNOPSIS
    This script automates the installation of SSL certificates on IIS and configures
    SmarterMail bindings with SSL and TLS encryption.

.DESCRIPTION
    This PowerShell script automates SSL certificate installation on IIS and configures SmarterMail bindings with SNI. It enables SSL/TLS encryption for the SmarterMail binding port. The script is compatible with Windows Server 2012 and higher.

    Customize the configuration in 'Includes\Setting.ps1' and 'Config\conf.ps1' files before running the script. After each run, a 'disable.lock' file is created to prevent accidental reruns via Task Scheduler. To run the script again for a different domain or SSL renewal, remove 'disable.lock'.

.PARAMETER pfxPath
    (Optional) Specifies the file path of the SSL certificate (PFX file) that will be installed on IIS.

.PARAMETER pfxPass
    (Optional) Specifies the password for the PFX file.

.PARAMETER hostname
    (Optional) Specifies the domain name for which the SSL certificate will be installed.

.PARAMETER smtp
    (Optional) Specifies the SMTP port for the SmarterMail website's binding.

.PARAMETER imap
    (Optional) Specifies the IMAP port for the SmarterMail website's binding.

.PARAMETER pop
    (Optional) Specifies the POP port for the SmarterMail website's binding.

.PARAMETER iisIp
    (Optional) Specifies the IP for the hostname binding On the IIS Smartermail Website.

.PARAMETER smtpOutboundIp
    (Optional) Specifies the IP for the SmarterMail website's binding.
 

.INPUTS
    None. You can't pipe objects to Update-Month.ps1.

.OUTPUTS
    The script can output installation logs, depending on the Debug parameter value.
    Debug parameter: If set, installation logs will be shown; otherwise, the script will run silently.

.EXAMPLE
    PS> .\AutoSetupSSL.ps1
    This example uses the default settings from Include/Settings.ps1 and Conf/Conf.ps1 as parameter values.

.EXAMPLE
    PS> .\AutoSetupSSL.ps1 -hostname "domainaddress"
    This example uses the default settings from Include/Settings.ps1 as permanent values and generates an auto PFX path with the structure C:\SSL\domainaddress_pfxpass.pfx. The password of the PFX file is obtained after the first '_' character from the PFX file. The script uses the IMAP, POP3, and SMTP ports from the current binding ports of SmarterMail if they exist or generates random ports if they do not exist. If the ports are defined in Conf/Conf.ps1 as $smtpPort, $imapPort, $popPort values, it uses those values instead.

.EXAMPLE
    PS> .\AutoSetupSSL.ps1 -hostname "domainaddress" -pfxPath "/location/of/pfx/file" -pfxPass "pfxpassword"
    This example sets the PFX path and password directly as input parameters. The script uses the IMAP, POP3, and SMTP ports from the current binding ports of SmarterMail if they exist or generates random ports if they do not exist. If the ports are defined in Conf/Conf.ps1 as $smtpPort, $imapPort, $popPort values, it uses those values instead.

.EXAMPLE
    PS> .\AutoSetupSSL.ps1 -hostname "domainaddress" -pfxPath "/location/of/pfx/file" -pfxPass "pfxpassword" -smtp "465" -imap "993" -pop "995" -iisIp "*" -smtpOutboundIp "192.168.1.1"
    This example defines all parameters explicitly. Each parameter can be defined in Conf/Conf.ps1, Include/Settings.ps1, or as input parameters from the command line.

.NOTES
    Author: Morteza Saeed Mohammadi
    Email: m.mohammadi721@gmail.com
    GitHub: [Github Profile](https://github.com/momohammadi)
    RELATED LINKS
    GitHub Repository: [Github Repository](https://github.com/momohammadi)

#>

param (
    [String]$pfxPath,
    [String]$pfxPass,
    [String]$hostname,
    [String]$smtp,
    [String]$imap,
    [String]$pop,
    [String]$smtpOutboundIp,
    [String]$iisIp
)

# Script code goes here...


. ".\Includes\autoload.ps1" 
checkRunningState

if ($Debug){
    Write-Log -DebugType "Info" -Message "############# Script Runtime Start."

    $messageForIisProccess="+++++++++++++ Install  for IIS Website: $website | IIS Bind IP: $iisIPaddress | Domain: $domain | IIS Bind Port: $iisPort | PFX password: $password | mail outbound ip: $mailOutputIp"
    $messageForStartSmartermailProcess="+++++++++++++ Start Smartermail communication"
    Write-Log -DebugType "Info" -Message $messageForIisProccess

    $confirmation = Read-Host "Please confirm(Y/N)"

    if ($confirmation -eq "Y" -or $confirmation -eq "y") {      
      AutoSetupSSL
    }else {
        Write-Log -DebugType "Info" -Message "Script Stopped, User Does not Confirmed"
        exit
    }
}else{
  AutoSetupSSL
}