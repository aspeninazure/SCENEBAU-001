Param(

   [Parameter (Mandatory = $true)]
   [string]$MasterResourceGroup,
   [Parameter (Mandatory = $true)]
   [string]$MasterNetworkName,
   [Parameter (Mandatory = $true)]
   [string]$MasterStorageAccountName,
   [Parameter (Mandatory = $true)]
   [string]$NewResourceGroupName,
   [Parameter (Mandatory = $true)]
   [string]$NewSubnetName,
   [Parameter (Mandatory = $true)]
   [string]$NewSubnetAdressSpace,
   [Parameter (Mandatory = $true)]
   [string]$VMname,
   #[Parameter (Mandatory = $true)]
   #[string]$NewStorageAccountName,
   [Parameter (Mandatory = $true)]
   [string]$VMContainerName,
   [Parameter (Mandatory = $true)]
   [string]$Location,
   [string]$ScriptToRun,
   [string]$ScriptToRunContainer,
   [Parameter (Mandatory = $true)]
   [string]$OSImageURI,
   [Parameter (Mandatory = $true)]
   [string]$VMSize,
   [Parameter (Mandatory = $true)]
   [string]$localAdmincredentialAsset,
   [Parameter (Mandatory = $true)]
   [string]$DomainJoinCredentialAsset,
   [string]$DomainName = 'aspen.local',
   [string]$DomainOUPath = 'OU=EMEA,OU=AZ_SIT_UAT,OU=CLOUD,DC=aspen,DC=local'
)
#Azure Login Code
$connectionName = 'AzureRunAsConnection'
try
{
    # Get the connection AzureRunAsConnection
    $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         

    "Logging in to Azure..."
    Add-AzureRmAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
}
catch {
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else{
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}
  
Select-AzureRMSubscription -SubscriptionID '74e2b4ae-eb36-45cc-bfbf-067c41f7dcfe'
#"Starting VM Creation"
"Set new storage account as default"
Set-AzureRmCurrentStorageAccount -ResourceGroupName $MasterResourceGroup -StorageAccountName $MasterStorageAccountName 
"Get Master Storage Account"
$MasterStorageAcc = Get-AzureRmStorageAccount -ResourceGroupName $MasterResourceGroup -AccountName $MasterStorageAccountName
"Get new Storage Account"
#$NewStorageAccountObj = Get-AzureRmStorageAccount -Name $NewStorageAccountName -ResourceGroupName $NewResourceGroupName
"Get Master Storage Account Key 1"
$MasterStorKey = (Get-AzureRmStorageAccountKey -Name $MasterStorageAccountName -ResourceGroupName $MasterResourceGroup ).Value[0]
#"Create VM Container on the Storage Account"
#New-AzureStorageContainer -Name $VMContainerName -Permission Off
"Getting Master vNet"
$MastervNetObj = Get-AzureRmVirtualNetwork -name $MasterNetworkName -ResourceGroupName $MasterResourceGroup
"Getting New Subnet"
$SubnetObj = Get-AzureRmVirtualNetworkSubnetConfig -Name $NewSubnetName -VirtualNetwork $MastervNetObj
"Creating VM NIC"
$nic = New-AzureRmNetworkInterface -Name $VMname -ResourceGroupName $NewResourceGroupName -Location $Location -Subnet $SubnetObj
"Collecting local admin credentials from secure store"
$LocalAdminCredObj = Get-AutomationPSCredential -Name $localAdminCredentialAsset
"Setting VM Size"
$vmObj = New-AzureRmVMConfig -VMName $VMname -VMSize $VMSize
"Setting up VM OS"
$vmObj = Set-AzureRmVMOperatingSystem -VM $vmObj -Windows -ComputerName $VMname -Credential $LocalAdminCredObj -ProvisionVMAgent -EnableAutoUpdate
#"Setting Image to use"
#$vmObj = Set-AzureRmVMSourceImage -VM $vmObj -PublisherName MicrosoftWindowsServer -Offer WindowsServer -Skus $OSImage  -Version 'latest'
"Allocating NIC to VM"
$vmObj = Add-AzureRmVMNetworkInterface -VM $vmObj -Id $nic.Id
"Create VM Storage Paths"
$blobPath = $VMContainerName + '/' + $VMname +'.vhd'
$osDiskUri = $MasterStorageAcc.PrimaryEndpoints.Blob.ToString() + $blobPath
"Setup VM Disk"
$vmObj = Set-AzureRmVMOSDisk -VM $vmObj -Name $VMname -VhdUri $osDiskUri -CreateOption fromImage -SourceImageUri $OSImageURI -Windows
"Spawn VM"
New-AzureRmVM -ResourceGroupName $NewResourceGroupName -Location $location -VM $vmObj

#$vm = Get-AzureRmVM -Name $vmname -ResourceGroupName $NewResourceGroupName

"Wait for the VM agent to sort its self out"



#"Domain Joining VM"
#$DomainJoinCredObj = Get-AutomationPSCredential -Name $DomainJoinCredentialAsset
#$domjoinpass = $DomainJoinCredObj.GetNetworkCredential().password
#$DomainJoinAdminName = $DomainJoinCredObj.GetNetworkCredential().UserName	
	

#Set-AzureRMVMExtension -VMName $VMName -ResourceGroupName $NewResourceGroupName -Name 'JoinAD' -ExtensionType 'JsonADDomainExtension' -Publisher 'Microsoft.Compute' -TypeHandlerVersion '1.0' -Location $Location -Settings @{ 'Name' = $DomainName; 'OUPath' = $DomainOUPath; 'User' = $DomainJoinAdminName; 'Restart' = 'true'; 'Options' = 3} -ProtectedSettings @{'Password' = $domjoinpass}



#"run custom script"
#Set-AzureRmVMCustomScriptExtension -ResourceGroupName $NewResourceGroupName -VMName $VMName -Name $ScriptToRun -TypeHandlerVersion '1.8' -StorageAccountName $MasterStorageAccountName -ContainerName $ScriptToRunContainer -StorageAccountKey $MasterStorKey -Location $Location -FileName $ScriptToRun -Run $ScriptToRun




