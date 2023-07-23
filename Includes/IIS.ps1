#Get binding object from IIS Website
function getCurrentBindings {
    param (
        [Object]$bindingInfo
    )    
    return $binding = Get-WebBinding -Name $bindingInfo.Website -Port $bindingInfo.Port -Protocol $bindingInfo.Protocol -HostHeader $bindingInfo.Domain -IPAddress $bindingInfo.Ipaddress
}

# Function to install PFX certificate
function installPfx {
    param (
        [string]$certPath,
        [string]$certPassword
    )

    Write-Log -DebugType "Info" -Message "Importing PFX..."
    $cert = Get-Item -Path $certPath
    $password = ConvertTo-SecureString -String $certPassword -AsPlainText -Force
    
    $certStore = "Cert:\LocalMachine\My"
    $certStorePath = Join-Path -Path $certStore -ChildPath $certThumbPrint
    $importStatus = Import-PfxCertificate -FilePath $certPath -CertStoreLocation $certStore -Password $password -Exportable
    $certThumbPrint = $importStatus.Thumbprint

    if($importStatus){
        Write-Log -DebugType "Info" -Message "PFX Imported Successfully"
    }else{
        Write-Log -DebugType "Error" -Message "Error in PFX Import. Script Has been stopped"
    }
    
    return $certThumbPrint, $certStorePath
}

#add certificate to the IIS Binding
function addCertToBinding(){
    param(
    [Object]$binding,
    [String]$certThumbPrint
    )
    try{
        $binding.AddSslCertificate($certThumbPrint,"my")
        Write-Log -DebugType "Info" -Message "SSL Added to IIS Binding Successfully"
    }catch{
        $errorMessage = $_.Exception.Message
        Write-Log -DebugType "Error" -Message "Error occured During Add SSL to IIS Binding: ErrorMessage"        
    }    
}

#add or update binding with SSL certificate
function setupBinding {
    param (
        [Object]$bindingInfo,
        [string]$certThumbPrint,
        [string]$certStorePath
    )

	Write-Log -DebugType "Info" -Message "start setup IIS Binding."
    $binding = getCurrentBindings -bindingInfo $bindingObject

    if ($binding) {
        Write-Log -DebugType "Info" -Message "The binding already exists, trying add SSL to that"
        addCertToBinding -binding $binding -certThumbPrint $certThumbPrint                
    } else {
        Write-Log -DebugType "Info" -Message "Create New Binding..."
        try{
            New-WebBinding -Name $bindingInfo.Website -Protocol $bindingInfo.Protocol -IPAddress $bindingInfo.Ipaddress -Port $bindingInfo.Port -HostHeader $bindingInfo.Domain -SslFlags 1
            Write-Log -DebugType "Info" -Message "IIS Binding added successfully"
        }catch{
            $errorMessage = $_.Exception.Message
            Write-Log -DebugType "Error" -Message "Error occurred while creating binding: $errorMessage"
        }        
        Write-Log -DebugType "Info" -Message "Add SSL to Binding..."
        $binding = getCurrentBindings -bindingInfo $bindingObject
        addCertToBinding -binding $binding -certThumbPrint $certThumbPrint        
    }    
    Write-Log -DebugType "Info" -Message "Setup IIS Binding end"
}