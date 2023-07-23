function smarterMailRequest {
    param (
        [String]$action,        
        [Object]$body,
        [String]$type = "Post"
    )

    Write-Log -DebugType "Info" -Message "Sending Request (${action}) to Smartermail API..."
    $contentType= if($type -eq "Post"){ 'application/x-www-form-urlencoded' } else {'text/xml'}
    $url = $SmarterMailUrl + "/services/svcServerAdmin.asmx/" + $action
    
    Start-Sleep -s 2
    try{                   
        Invoke-WebRequest -Uri $url -Method $type -Body $body -ContentType $contentType
        Write-Log -DebugType "Info" -Message "Request Sent Successfully"
    }catch{
        $errorMessage = $_.Exception.Message
        Write-Log -DebugType "Info" -Message "Error in sending Request $errorMessage"
        checkRunningstate -forceStop:$true
    }    
}

function smartermailListBindingPort {    
    $listPort= @{
            authUsername=$apiUser
            authPassword=$apiPass
        }    
    $response = smarterMailRequest -body $listPort -action "ListServerPorts"
    return [xml]$response.Content  
}

function findFreePort{
    if($smtpPort -and $popPort -and $imapPort){
        $ports = @{
            smtp=$smtpPort
            pop=$popPort
            imap=$imapPort
        }
        return $ports
    }
    $ports = @{}
    $portlist=smartermailListBindingPort
    $portName=@()
    $portName+=extractXml -xmlContent $portlist -expectedField "Name" -mainNode "ServerPortResult"   
    foreach($name in $portName){    
        if($name -like "*$domain*"){
            $smtp = extractXml -xmlContent $portlist -expectedField "Port" -filter "ns:Name='$name' and ns:Protocol='SMTP'" -mainNode "ServerPortResult"
            if($smtp -and !$ports.smtp.Length -ge 1){
                $smtp = $smtp | Get-Unique
                $ports.Add('smtp',$smtp)
            }
            $pop = extractXml -xmlContent $portlist -expectedField "Port" -filter "ns:Name='$name' and ns:Protocol='POP'" -mainNode "ServerPortResult"
            if($pop -and !$ports.pop.Length -ge 1){
                $pop = $pop | Get-Unique
                $ports.Add('pop',$pop)
            }
            $imap = extractXml -xmlContent $portlist -expectedField "Port" -filter "ns:Name='$name' and ns:Protocol='IMAP'" -mainNode "ServerPortResult"
            if($imap -and !$ports.imap.Length -ge 1){
                $imap = $imap | Get-Unique
                $ports.Add('imap',$imap)
            }
        }
    }
    if($ports.Count -lt 3 ){

        $min = 1024
        $max = 6553
        $previousPort = Get-Random -Minimum $min -Maximum $max        
        $usedPorts = extractXml -xmlContent $portlist -expectedField "Port" -mainNode "ServerPortResult"

        foreach ($i in 1..50) {
            $nextPort = $previousPort + 1
            if ($nextPort -ge $max) {
                $nextPort = $min
            }
            $previousPort = $nextPort       
            if(!($nextNumber -in $usedPorts)){
                if(!$ports.smtp.Length -ge 1){
                    $ports.Add('smtp',[String]$nextPort)
                }elseif(!$ports.pop.Length -ge 1){
                    $ports.Add('pop',[String]$nextPort)
                }elseif(!$ports.imap.Length -ge 1){
                    $ports.Add('imap',[String]$nextPort)
                }
            }
            if($ports.Count -eq 3){
                break
            }
        }    
    }
    return $ports
}

function mailProtocol{
    $freePorts = findFreePort
    $mailProtocol = @{
        "SMTP"= @{       
                "port"=$freePorts.smtp     
        }
        "POP"= @{
            "port"=$freePorts.pop
        }
        "IMAP"= @{
            "port"=$freePorts.imap
        }
    }
    return $mailProtocol
}

function smartermailRemoveBindingPort {
    param (
        [String]$protocol,
        [String]$port
    )
    Write-Log -DebugType "Info" -Message "Removing Current binding if it exist"   
    
    $serverPortsXml = smartermailListBindingPort
    $portIds =@()
    $portIds += extractXML -xmlContent $serverPortsXml -mainNode "ServerPortResult" -expectedField 'ID' -filter "ns:Port='$port' and ns:Protocol='$protocol'"
    if($portIds.length -ge 1 ){
        foreach($portId in $portIds){
            Write-Log -DebugType "Info" -Message "Removing current binding port $port and portId $portId"
            $deletePortBody = @{
                    authUsername=$apiUser
                    authPassword=$apiPass
                    portId=$portId
            }
            $deletedPortXml = smarterMailRequest -action "DeleteServerPort" -body  $deletePortBody        
            $result = extractXml -xmlContent $deletedPortXml -mainNode "GenericResult" -expectedField "Result" 
            if($result -eq "true"){
                Write-Log -DebugType "Info" -Message "Port Removed Successsfully"
            }else{
                $message = extractXml -xmlContent $deletedPortXml -mainNode "GenericResult" -expectedField "Message"
                Write-Log -DebugType "Info" -Message "Error in remove port with message $message"
            }
        }
    }else{
        Write-Log -DebugType "Info" -Message "could not find port id, port does not exist or error occurred finding port"
    }
}

function smarterMailAddBinding {
    param (
        [String]$encryption,
        [String]$mailProtocol,
        [String]$protocol,
        [String]$port
    )
    
    $name=$protocol + ' ' + $encryption + ' for '+ $domain
    Write-Log -DebugType "Info" -Message "adding smartermail port binding $name port $port"

    smartermailRemoveBindingPort -protocol $protocol -port $port
        
    $addServerPortBody = @{
        authUsername=$apiUser
        authPassword=$apiPass
        protocol=$protocol
        certificatePath=$certPath
        encryption=$encryption
        name= $name
        port=$port
        password=$password
        description=$name
    }

    $response = smarterMailRequest -action "AddServerPort" -body $addServerPortBody
   
    $xmlResponse = [xml]$response.Content
    $portId = extractXML -xmlContent $xmlResponse -expectedField 'NewID' -mainNode "AddServerPortResult" -filter "ns:Result='true'"
    if ($portId){
        Write-Log -DebugType "Info" -Message "Port added to smartermail binding successfully, assigning port to IP address..."
        $assignPortToIPBody = @{
            authUsername=$apiUser
            authPassword=$apiPass
            portID=$portId
            ipAddress=$mailOutputIp
        }
        $response = SmartermailRequest -action "AssignPortToIP" -body $assignPortToIPBody
        $xmlResponse = [xml]$response.Content
        $resultStatus = extractXML -xmlContent $xmlResponse -expectedField 'Result' -mainNode "GenericResult"
        if($resultStatus -eq "true"){
            Write-Log -DebugType "Info" -Message "Port assigned to Smartermail IP address successfully"
            #addFirewallRule -port $port -domain $domain
        }else{
            $message = extractXML -xmlContent $xmlResponse -expectedField 'Message' -mainNode "GenericResult"
            Write-Log -DebugType "Info" -Message "Error on assign Smartermail port to IP address with message: $message"
        }   
    }else{
        $message = extractXML -xmlContent $xmlResponse -expectedField 'Message' -mainNode "AddServerPortResult"
        Write-Log -DebugType "Info" -Message "Error on add port to binding with message: $message"
    }
    Write-Log -DebugType "Info" -Message "smarterMailAddBinding end."    
}

function showInfo {
    param(
        [Object]$mailProtocol
    )
$table=foreach ($protocol in $mailProtocol.GetEnumerator()) {
        $protocolName = $protocol.Name
        $port = $mailProtocol[$protocol.Name].port
       
        new-object psobject -Property @{
            Address = $domain
            Protocol = $protocolName
            Port = $port
            Encryption = "SSL\TLS"
        }
    }
$table | Format-Table Address,Encryption,Protocol,port -AutoSize
}