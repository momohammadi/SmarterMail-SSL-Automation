#write log of installation proccess
function Write-Log {
    param (
        [Bool]$forceStop=$true,
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Message,
        [ValidateSet("Info", "Error")]
        [String]$DebugType = 'Info'		
    )
    $date=Get-Date -Format "yyyy-MM-dd"
    $fileName="log_$date.txt"
    $LogFile = "$workingDir\Logs\$filename"
    $DateTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "$DateTime - $DebugType"+": "+"$Message"
	$LogEntry | Out-File -Append -FilePath $LogFile
    
  if($Debug -eq 'true'){
		Write-Host $LogEntry
	}elseif ($Debug -eq "Info" -and $DebugType -eq "Info") {
        Write-Host $LogEntry
    }elseif($Debug -eq "Error" -and $DebugType -eq "Error"){
		Write-Host $LogEntry		
	}
	if($DebugType -eq "Error" -and $forceStop){
		checkRunningState -forceStop:$true
	}
}

#save you wanted text or object in the file
function saveOutput (){
	param(
    [String]$text,
		[Object]$object
	)
    $date=Get-Date -Format "yyyy-MM-dd"
    $fileName="Port_info_$date.txt"
    $savedFile = "$workingDir\Info\$filename"
	if($text){
		$text | Out-File -Append -FilePath $savedFile
		if($Debug){
			$text
		}
	}else{
		$object | Out-File -Append -FilePath $savedFile
		if($Debug){
			$object
		}		
	}
}

# Check if the disable file exists; stop and exit the script if found. Create the file when runtime finishes.
function checkRunningState {
    param(
        [bool]$finish = $false,
        [bool]$forceStop = $false
    )
    $filePath="$workingDir/disable.lock"

    if(Test-Path $filePath){        
        Exit
    }elseif($finish){
        Write-Log -DebugType "Info" -Message "Script runtime ended."
        New-Item -ItemType File -Path $filePath | Out-Null
        Exit
    }elseif($forceStop){
        Write-Log -DebugType "Error" -Message "force stoped check log file"
        Exit
    }
}

function extractXml {
    param (
        [xml]$xmlContent,
        [String]$expectedField,
        [String]$mainNode,
        [String]$filter="0"
    )
    Write-Log -DebugType "Info" -Message "Parse XML Response for ${mainNode} and Receive ${expectedField} with filter $filter"
    $namespaces = New-Object System.Xml.XmlNamespaceManager($xmlContent.NameTable)
    $namespaces.AddNamespace("ns", "http://tempuri.org/")
    if($filter -ne "0"){
        $fields = $xmlContent.SelectNodes("//ns:$mainNode[$filter]/ns:$expectedField", $namespaces) | ForEach-Object { $_.InnerText }
    }else{
        $fields = $xmlContent.SelectNodes("//ns:$mainNode/ns:$expectedField", $namespaces) | ForEach-Object { $_.InnerText }
    }

    if(($fields -is [array] -or $fields -is [Object]) -and $fields.Count -gt 10){       
        Write-Log -DebugType "Info" -Message "Parse Result is big array or object"
    }elseif($fields.Length -gt 60){                
        $fields=$fields.substring(0,60)+" ..."
        Write-Log -DebugType "Info" -Message "Parse Result is $fields"
    }else{
        Write-Log -DebugType "Info" -Message "Parse Result is $fields"
    }

    return $fields
}

# Run Script
function AutoInstallSSL {
	if($Debug){
		Write-Log -DebugType "Info" -Message "############# Script Runtime Start."
		$messageForIisProccess="+++++++++++++ Install  for IIS Website: $website | IIS Bind IP: $iisIPaddress | Domain: $domain | IIS Bind Port: $iisPort"
		$messageForStartSmartermailProcess="+++++++++++++ Start Smartermail communication"
		Write-Log -DebugType "Info" -Message $messageForIisProccess		
	}
	
    $certThumbPrint, $certStorePath = installPfx -certPath $certPath -certPassword $password
    setupBinding -bindingInfo $bindingObject -certThumbPrint $certThumbPrint -certStorePath $certStorePath
    #add smartermail binding        
    Write-Log -DebugType "Info" -Message $messageForStartSmartermailProcess        
    $freePorts = smtmFreePort -domain $domain
    $protocols=enumValue -name 'IPBindingType'
    for ($i = 0; $i -lt 3; $i++)
    {
        $protocol = $protocols.$i
        $port = $freePorts.($protocol)
        smtmAddBinding -ssl 'true' -protocol ([IPBindingType]::$protocol) -port $port -convertTojson:$false
        smtmAddBinding -tls 'true' -protocol ([IPBindingType]::$protocol) -port $port
    }
    showInfo -freePorts $freePorts
    checkRunningstate -finish:$true
}

function addFirewallRule(){
    param(
        [String]$port,
        [String]$domain
    )
    $name = "$domain Port: $port"
    Write-Log -DebugType "Info" -Message "adding Firewall rule for Port $port"
    $firewallRules = Get-NetFirewallRule |
        Where-Object { ($PSItem | Get-NetFirewallPortFilter).LocalPort -eq $port }

    if ($firewallRules) {
        Write-Log -DebugType "Error" -forceStop:$false -Message "Port number $port already exist in Firewall rules with name $firewallRules.DisplayName"
    }else{
        try{
            New-NetFirewallRule -Group "Smartermail Users" -Name "$name" -DisplayName "$name" -Direction Inbound -Protocol TCP -LocalPort $port -Action Allow -OutVariable rule | Out-Null
            Write-Log -DebugType "Info" -Message "Port number $port added to Firewall rule"
        }catch{
            $errorMessage = $_.Exception.Message
            Write-Log -DebugType "Error" -Message "Error On adding Firewall rule with message $errormessage"
        }
    }
    Write-Log -DebugType "Error" -Message "End Firewall rule adding for Port $port"
}