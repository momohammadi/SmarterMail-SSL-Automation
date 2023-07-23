#Smartermail enum value for IPBindingType
enum IPBindingType {
SMTP
POP
IMAP
}
#use for refresh Smartermail Access token or refresh current Access token and rerun request with all parametere
function checkAuth {
    param (
        [String]$section,
        [String]$action,
        [String]$moreUri,
        [Object]$body,
        [String]$type = "Post",
        [Bool]$convertToJson=$true
    )
    smtmAuth
    smtmRequest -type $type -section $section -action $action -body $body -convertToJson:$convertToJson
}

#refresh smartermail access token
function refreshToken {
    Write-Log -DebugType "Info" -Message "Refreshing Smartermail API Token..."

    try{    
        $Auth=@{
            token=$refreshToken
        }
        $header = @{
            Authorization="Bearer $accessToken"
        }
        $Auth = $Auth | ConvertTo-Json
        $refreshToken = $SmarterMailUrl + "/api/v1/auth/refresh-token"
        $response=Invoke-RestMethod  -ContentType $contentType -Uri $refreshToken -Method $type -Body $Auth
        $Global:accessToken = $response.accessToken
        $Global:refreshToken = $response.refreshToken

        Write-Log -DebugType "Info" -Message "access token refreshed Successfully"         

    }catch{
        $error = $_.Exception
        Write-Log -DebugType "Error" -Message "Unknown error occurred in API connection $error.Message"      
    }

}

#Authonticate to Smartermail api
function smtmAuth {
    param(
        [Object]$request
    )

    $contentType='application/json'
    $type="Post"

   try{
       if(!($refreshToken) -or ($refreshToken.Length -lt 10)){
            Write-Log -DebugType "Info" -Message "Authonticating to Smartermail API..."

            $Auth=@{
                username=$apiUser
                password=$apiPass
            }
            $Auth = $Auth | ConvertTo-Json
            $getToken = $SmarterMailUrl + "/api/v1/auth/authenticate-user"
            $response=Invoke-RestMethod  -ContentType $contentType -Uri $getToken -Method $type -body $Auth
            $Global:accessToken = $response.accessToken
            $Global:refreshToken = $response.refreshToken

            Write-Log -DebugType "Info" -Message "Authonticated Successfully"

       }else{
            Write-Log -DebugType "Error" -forceStop:$false -Message "Error make Auth smartermail API, trying refresh token"
            refreshToken
       }     
   }catch{
        $error = $_.Exception

        if ($error.Response -and $error.Response.StatusCode -eq "Unauthorized") {
            Write-Log -DebugType "Error" -Message "Authorization Failed check API Username and password"
        }
        else {
            $errorMessage = $error.Message
            Write-output $error.Response
            Write-Log -DebugType "Error" -Message "Error make Auth smartermail API $errorMessage"
        }

    }
}

#send request to the Smartermail API
function smtmRequest {
    param (
        [String]$section,
        [String]$action,
        [String]$moreUri,
        [Object]$body,
        [String]$type = "Post",
        [Bool]$convertToJson=$true
    )
    Write-Log -DebugType "Info" -Message "Sending Request ($section $action) to Smartermail API..."
       
    $contentType='application/json'
    $url = $SmarterMailUrl + "/api/v1/$section/$action"
    if($convertToJson -eq $true){
        $body = $body | ConvertTo-Json 
    }        
    $header = @{
        Authorization="Bearer $accessToken"
    }

    try{
        Start-Sleep -s 2
        $response = Invoke-RestMethod -Uri $url -Method $type  -ContentType $contentType -Headers $header -body $body
        Write-Log -DebugType "Info" -Message "Request Sent Successfully"
    }catch{        
        $error = $_.Exception
        if ($error.Response -and $error.Response.StatusCode -eq "Unauthorized") {
            Write-Log -DebugType "Error" -forceStop:$false -Message "Error on Auth smartermail API, trying Re-Authenticating..."
            checkAuth -type "Get" -section "settings/sysadmin" -action "ip-binding-manager" -body $body
        }
        else {
            $errorMessage = $error.Message
            Write-Log -DebugType "Error" -Message "Error make Auth smartermail API $errorMessage"
        }
    }

    return $response
}

#get enaumvalue (read Smartermail API Docs)
function enumValue{
    param(
        [String]$name
    )
    switch($name){
        'IPBindingType' {
            $enumValues = @{
                    'SMTP'=0
                    'POP'=1
                    'IMAP'=2
                    0='SMTP'
                    1='POP'
                    2='IMAP'
            }
        }
    }
    return $enumValues
}

#Get currenct Binding port from Smartermail
function smtmBindingList {
	Write-Log -DebugType "Info" -Message "Receiving port Bindings from Smartermail..."
	
    $bindList = smtmRequest -section "settings/sysadmin" -action "ip-binding-manager" -type "Get"
    $bindingPorts = $bindList.bindingManager.bindingPorts
    $bindingIps = $bindList.bindingManager.bindingInfo
    $smtmBindings=@()
    foreach($bindingPort in $bindingPorts){
        foreach($bindingIp in $bindingIps){
            if($bindingPort.id -in $bindingIp.portIDs ){
                $ip +=@($bindingIp.ipAddress)                   
            }
        }
        
        $smtmBindings += [PSCustomObject]@{
            name = $bindingPort.name
            port = $bindingPort.port
            type = $bindingPort.type
            description= $bindingPort.description                      
            isTls = $bindingPort.isTls
            isSSL = $bindingPort.isSSL
            certificatePath = $bindingPort.certificatePath
            password = $bindingPort.password
            id= $bindingPort.id
            # Add 'ipaddress' property
            ipaddress = $ip
        } 
        $ip=@()
    }
	Write-Log -DebugType "Info" -Message "end Receive port Bindings from smartermail"
    return $smtmBindings
}

#generate Free Port for the Smartermail Binding
function smtmFreePort{
	Write-Log -DebugType "Info" -Message "Finding free ports..."
    if($smtpPort -and $popPort -and $imapPort){
        $ports = @{
            smtp=$smtpPort
            pop=$popPort
            imap=$imapPort
        }
		Write-Log -DebugType "Info" -Message "set exact port by user from config file"
        return $ports
    }

    $ports = @{}      
    $bindings= smtmBindingList
	Write-Log -DebugType "Info" -Message "Set the same ports if the domain has already been defined, based on its previous ports."
    foreach($binding in $bindings){
        if(!($ports.usedPorts)){
            $ports.add('usedPorts',@($binding.port))
        }else{
            $ports.usedPorts +=@($binding.port)
        }
        
        if($binding.name -like "*$domain*"){
            $protocol = (enumValue -name 'IPBindingType')[$binding.type]
            if($ports.$protocol.Count -eq 0){
                $ports +=@{$protocol=$binding.port}                
            }
            smtmRemoveBinding -id $binding.id -port $binding.port
        }

    }

    if($ports.Count -lt 4 ){
        $min = 1024
        $max = 6553
        $previousPort = Get-Random -Minimum $min -Maximum $max
		Write-Log -DebugType "Info" -Message "generating random ports..."
        foreach ($i in 1..50) {            
            $nextPort = $previousPort + 1

            if ($nextPort -ge $max) {
                $nextPort = $min
            }
            $previousPort = $nextPort

            if(!($nextPort -in $usedPorts)){
                 if(!($ports.SMTP)){
                    $ports.Add('SMTP',[String]$nextPort)
					Write-Log -DebugType "Info" -Message "$nextPort find for SMTP"
                }elseif(!($ports.POP)){
                    $ports.Add('POP',[String]$nextPort)
					Write-Log -DebugType "Info" -Message "$nextPort find for POP"
                }elseif(!($ports.IMAP)){
                    $ports.Add('IMAP',[String]$nextPort)
					Write-Log -DebugType "Info" -Message "$nextPort find for IMAP"
                }
            }

            if($ports.Count -eq 4){
                break
            }
        }    
    }
	Write-Log -DebugType "Info" -Message "All ports find successfully"
    return $ports
}

#add New Binding port to the Smartermail
function smtmAddBinding{
    param (        
        [String]$ssl='false',
        [String]$tls='false',
        [IPBindingType]$protocol,
        [String]$port
    )
    Write-Log -DebugType "Info" -Message 'adding new port to smartermail Binding...'

    if($tls -eq 'true' -and $ssl -eq 'true'){
		Write-Log -DebugType "Error" -Message 'Invalid Request Param (SSL and TLS can not be true same time)'
    }elseif($tls -eq 'true'){
        $encryption='TLS'
    }elseif($ssl -eq 'true'){
        $encryption='SSL'
    }

    $name= $protocol.ToString() + ' ' + $encryption +' '+ $domain + ' by API'
    # Create an array of bound IP addresses
    $certpath = $certpath | ConvertTo-Json
$body=@"
{
    "toAdd":  [
                  {
                      "boundIpAddresses":  ["$mailOutputIp"],
                      "id":  null,
                      "Type":  "$protocol",
                      "isTls":  "$tls",
                      "password":  "$password",
                      "description":  "$name",
                      "name":  "$name",
                      "port":  "$port",
                      "isSSL":  "$ssl",
                      "certificatePath":  $certpath
                  }
              ]
}
"@

    $response = smtmRequest -section "settings/sysadmin" -action "ip-binding-ports" -body $body -type "Post" -convertToJson:$false
    
    if($response.success){
        addFirewallRule -port $port -domain $domain
        Write-Log -DebugType "Info" -Message "$port $encryption $protocol added for $domain successfully"
    }else{
        Write-Log -DebugType "Error" -Message "failed to add smartermail Binding $port $protocol for $domain"
    }
}

#Remove the binding from Smartermail ports binding
function smtmRemoveBinding{
    param (        
        [String]$id,
        [String]$port=$null
    )
    Write-Log -DebugType "Info" -Message 'Removing curent ports from smartermail Binding...'

    $body=@{
        toRemove = @(
            @($id)
        )
    }

    $response = smtmRequest -section "settings/sysadmin" -action "ip-binding-ports" -body $body -type "Post"

    if($response.success){
        Write-Log -DebugType "Info" -Message "$port $protocol removed for $domain successfully"
    }else{
        Write-Log -DebugType "Error" -Message "failed to remove smartermail Binding $port $protocol for $domain"
    }
}

#Show and save formatted information for use in email applications (e.g., Outlook).
#saved file located in $workingDir\Info Directory
function showInfo {
    param(
        [Object]$freePorts
    )
    $protocols=enumValue -name 'IPBindingType'
    $table=for ($i = 0; $i -lt 3; $i++)
        {
            $protocol = $protocols.$i
            $port = $freePorts.($protocol)
            new-object psobject -Property @{
                Address = $domain
                Protocol = $protocol
                Port = $port
                Encryption = "SSL\TLS"
            }
        }
	$output = $table | Format-Table Address,Encryption,Protocol,Port -AutoSize
	saveOutput -object $output
}