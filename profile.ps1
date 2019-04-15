function I-Forget {
	Write-Host "`n
	Encode-ImageToBase64`n
	Generate-RandomString`n
	AmIRoot`n
	Login-ToExchangeOnline`n
	Restore-AzureRmVmSnapshot`n
	Restore-AzureRmVmSnapshot`n
	"
}

function Encode-ImageToBase64 ([String]$FilePath, [String]$Prefix="data:image/png;base64"){
	$rawImageToByteString = [convert]::ToBase64String((Get-Content $FilePath -Encoding byte))
	$formattedImageFromByteStringToBase64 = "`"$Prefix,$rawImageToByteString`""
	return $formattedImageFromByteStringToBase64
}

function Generate-RandomString ([int]$Length = 8, [switch]$SelectedSpecials, [switch]$AlphaCaps, [switch]$AlphaLowers, [switch]$Numerals) {
    if ($Length -le 0) {
        throw "Error! Nonsensical Length"
    } else {
        if ($SelectedSpecials -ne $true) {
            $keyspace += [char[]]([char]33 + [char]126 + [char]64 + [char]46 + [char]94 + [char]35 + [char]95)
        } 

        if ($Numerals -ne $true) {
            $keyspace += [char[]]([char]48..[char]57)
        }
    
        if ($AlphaCaps -ne $true) {
            $keyspace += [char[]]([char]65..[char]90)
        }

        if ($AlphaLowers -ne $true) {
            $keyspace += [char[]]([char]97..[char]122)
        }

        if ($keyspace.Length -le 0) {
            throw "Keyspace Error! No character pool! Increase Empathy!!!!" 
        } else { 
            $ResultString = (1..$Length | % {$keyspace | Get-Random}) -join "" 
            return $ResultString
        }
    }
}

function AmIRoot {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if ( $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) ) {
        return 0
    } else {
        return 1
    }
}

function Login-ToExchangeOnline ( [switch]$gvt, [ValidateSet($null, "IEConfig", "WinHttpConfig", "AutoDetect")]$Proxy = $null, [switch]$NoChRoot ){
    $tenement = "https://outlook.office365.com/powershell-liveid/"

    if ([switch]$gvt) {
        $tenement = "https://outlook.office365.us/powershell-liveid/"
    }

    if ($Proxy -ne $null) {
        $ProxyOptions = New-PSSessionOption -ProxyAccessType $Proxy
        try {
            $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $tenement -Credential (Get-Credential) -Authentication Basic -AllowRedirection -SessionOption $ProxyOptions -ErrorAction Inquire
        } catch {
            Write-Host "$_ Retrying...." 
            $UserCredential = $null
            Login-ToExchangeOnline $args
        }
    }
    
    try {
        $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $tenement -Credential (Get-Credential) -Authentication Basic -AllowRedirection -ErrorAction Inquire
    } catch {
        Write-Host "Retrying...." 
        $UserCredential = $null
        Login-ToExchangeOnline $args
    }

    If ( !($NoChRoot).IsPresent ) {
    Import-PSSession $Session -DisableNameChecking
    }

    return $Session
}

function logout ($Session = $null) {
    if ($Session -eq $null) {
        Get-PSSession | Remove-PSSession -ErrorAction Inquire
    }

    try {
        Remove-PSSession $Session -ErrorAction Continue
    } catch {
        Throw $_ 
    }
}

<# Credit to Adam Bertram from Techsnips for these Azure Framework gems which I have made better with a little error handling
Requirements:
Install az tools with  `Install-Module -Name Az -AllowClobber`
Enable powershell az aliases with `Enable-AzureRmAlias` #>

function New-AzureRmVmSnapshot {
    param(
     [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$VmName,
     [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ResourceGroup,
     [Parameter()][ValidateNotNullOrEmpty()]         [string]$SnapshotName,
     [Parameter()][ValidateNotNullOrEmpty()]         [switch]$RemoveOriginalDisk
    )
    $currentDate = (Get-Date -UFormat %Y%m%d%H%M%s).Replace(".","")

    try {
        $vm = Get-AzureRmVM -Name $VmName -ResourceGroupName $ResourceGroup
    } catch {
        Throw "$_ :: Or :: Error getting VM Object"
    }

    #not sure why this is necessary, seems redundant
    $stopParams = @{
        ResourceGroupName = $ResourceGroup
        Force = $true
    }
    try { 
        $vm | Stop-AzureRmVm -ResourceGroupName $ResourceGroup -Force
    } catch {
        throw "$_ :: or :: Unable to stop Azure VM"
    }

    $diskName = $vm.StorageProfile.OSDisk.Name
    $osDisk = Get-AzureRmDisk -ResourceGroupName $ResourceGroup -DiskName $diskname 
    $snapConfig = New-AzureRmSnapshotConfig -SourceUri $osDisk.Id -CreateOption Copy -Location $vm.Location 
    if ($SnapshotName) {
        $SnapshotNamePost = $SnapshotName
    } else {
        $SnapshotNamePost = '{0}-{1}' -f $vm.Name,$currentDate
    }
    New-AzureRmSnapshot -Snapshot $snapConfig -SnapshotName $SnapshotNamePost -ResourceGroupName $ResourceGroup
}

function Restore-AzureRmVmSnapshot {
    param ([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$VmName,
           [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ResourceGroup,
           [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$SnapshotName,
           [Parameter()][ValidateNotNullOrEmpty()]         [switch]$RemoveOriginalDisk
    )
 
    try {
        $vm = Get-AzureRmVM -Name $VmName -ResourceGroupName $ResourceGroup
    } catch {
        Throw "$_ :: Or :: Error getting VM Object"
    }

    if ( !($vm) ) {
        Throw "$_ VM not found"
    } else { 
        ## Find the OS disk on the VM to get the storage type
        $osDiskName = $vm.StorageProfile.OsDisk.name
        $oldOsDisk = Get-AzureRmDisk -Name $osDiskName -ResourceGroupName $ResourceGroup
        $storageType = $oldOsDisk.sku.name
 
        ## Create the new disk from the snapshot
        $snapshot = Get-AzureRmSnapshot -ResourceGroupName $ResourceGroup | Where-Object { $_.Name -eq $SnapshotName }
        $diskconf = New-AzureRmDiskConfig -AccountType $storagetype -Location $oldOsdisk.Location -SourceResourceId $snapshot.Id -CreateOption Copy
        $newDisk = New-AzureRmDisk -Disk $diskconf -ResourceGroupName $resourceGroup -DiskName "$($vm.Name)-$((New-Guid).ToString())"
 
        # Set the VM configuration to point to the new disk
        try {
            Set-AzureRmVMOSDisk -VM $vm -ManagedDiskId $newDisk.Id -Name $newDisk.Name
        } catch {
            throw "$_ :: or :: Failed to attach new OS disk from snapshot"
        }
 
        # Update the VM with the new OS disk
        try {
            Update-AzureRmVM -ResourceGroupName $resourceGroup -VM $vm 
        } catch {
            throw "$_ :: or ::Failed to update new configuration "
        }
 
        # Start the VM 
        Start-AzureRmVM -Name $vm.Name -ResourceGroupName $resourceGroup
 
        if ([switch]$RemoveOriginalDisk.IsPresent) {
            try {
                Remove-AzureRmDisk -ResourceGroupName $ResourceGroup -DiskName $oldOsDisk.Name
            } catch {
                throw "$_ :: or :: Failed to delete outdated disk"
            }
        }
    }
}
