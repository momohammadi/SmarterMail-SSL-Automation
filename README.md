# ![PowerShell Logo](https://raw.githubusercontent.com/PowerShell/PowerShell/master/assets/ps_black_64.svg?sanitize=true)SmarterMail SSL Automation

Automate SSL certificate installation on IIS and configure SmarterMail bindings with SNI, enabling SSL/TLS encryption for the SmarterMail binding port.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![GitHub stars](https://img.shields.io/github/stars/momohammadi/SmarterMail-SSL-Automation)](https://github.com/momohammadi/SmarterMail-SSL-Automation/stargazers)

## Table of Contents
- [Description](#description)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Usage](#usage)
- [Examples](#examples)
- [Configuration](#configuration)
- [Contributing](#contributing)
- [License](#license)

## Description
This PowerShell script automates the process of installing SSL certificates (PFX File) on IIS (Internet Information Services) and configuring bindings with SNI (Server Name Indication) for the IIS SmarterMail website associated with a specific hostname (domain). Additionally, the script enables SSL and TLS encryption for the SmarterMail binding port.
It has been extensively tested on Windows Server 2012 with SmarterMail Professional build 7242 and is expected to be compatible with higher versions as well.

## Features
- Automated SSL certificate installation on Smartermail Website IIS.
- SmarterMail binding configuration with Server Name Indication (SNI).
- SSL and TLS encryption setup for the SmarterMail binding port.
- Simplified usage with command-line parameters.

## Prerequisites
- Windows Server 2012 or higher.
- SmarterMail Professional build 7242 or higher.
- PowerShell 5.1 or later.

## Installation
1. Clone this repository to your local machine.
2. Customize the 'Includes/Settings.ps1' and 'Config/conf.ps1' files to match your specific environment.

## Usage
Run the 'AutoSetupSSL.ps1' script with or without command-line parameters to automate the SSL certificate installation process and SmarterMail binding configuration. The script can also be scheduled using the Windows Task Scheduler for automatic execution.

## Examples


###### EXAMPLE 1
```powershell
PS> .\AutoSetupSSL.ps1
```
This example uses default settings from Include/Settings.ps1 and Conf/Conf.ps1 as parameter values.

###### EXAMPLE 2
```powershell
PS> .\AutoSetupSSL.ps1 -hostname "domainAddress"
```
This example utilizes default settings from Include/Settings.ps1 as permanent values and generates an auto PFX
path with the structure C:\SSL\domainAddress_pfxpass.pfx. The password of the PFX file is extracted after the first
'_' character from the PFX file. The script uses the IMAP, POP3, and SMTP ports from the current binding ports of
SmarterMail if they exist, or generate random ports if they do not exist. If the ports are defined in
Conf/Conf.ps1 as $smtpPort, $imapPort, $popPort values, it uses those values instead to generate random ports.

###### EXAMPLE 3
```powershell
PS> .\AutoSetupSSL.ps1 -hostname "domainAddress" -pfxPath "/location/of/pfx/file" -pfxPass "pfxpassword"
```
This example sets the PFX path and password directly as input parameters. The script uses the IMAP, POP3, and SMTP
ports from the current binding ports of SmarterMail if they exist, or generates random ports if they do not exist.
If the ports are defined in Conf/Conf.ps1 as $smtpPort, $imapPort, $popPort values, it uses those values instead.
###### EXAMPLE 4
```powershell
PS> .\AutoSetupSSL.ps1 -hostname "domainAddress" -pfxPath "/location/of/pfx/file" -pfxPass "pfxpassword" -smtp "465"
-imap "993" -pop "995" -iisIp "*" -smtpOutboundIp "192.168.1.1"
```
This example explicitly defines all parameters. Each parameter can be defined in Conf/Conf.ps1,
Include/Settings.ps1, or as input parameters from the command line.

## Configuration
Before running the script, review and edit the 'setting.ps1' and 'conf.ps1' files to customize the configuration according to your specific requirements. These files contain variables that affect the behavior of the script. Modify the values in these files to match your environment before executing the script.

## Contributing
Contributions are welcome! If you find a bug, have suggestions, or want to add new features, feel free to open an issue or submit a pull request.

## License
This project is licensed under the [MIT License](LICENSE).

[GitHub Repository](https://github.com/momohammadi/SmarterMail-SSL-Automation/)
