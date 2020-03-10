Param(
    [Parameter(Mandatory=$False)] [bool]$discard = $False
)

function LogOutput {
    Param(
        [Parameter(Mandatory=$True)][string]$message
    )
    Write-Output $message
}

function MountWim {
    Param(
        [Parameter(Mandatory=$True)][string]$boot_wim,
        [Parameter(Mandatory=$True)][string]$wim_mount,
        [bool]$discard = $False
    )
    if ($discard) {
        LogOutput -message '$discard=$True: Dismounting and remounting...'
        Dismount-WindowsImage -Path $wim_mount -Discard
    }
    $freshMount = $True
    foreach ($image in (Get-WindowsImage -Mounted)) {
        if ($image.Path -eq $wim_mount) {
            $freshMount = $False
            if ($image.MountStatus -ne "Ok") {
                Mount-WindowsImage -Path $wim_mount -Remount
                break
            }
        }
    }
    if($freshMount) {
        Mount-WindowsImage -ImagePath $boot_wim -Index 1 -Path $wim_mount
    }
   # Mount-WindowsImage -ImagePath $boot_wim -Index 1 -Path $wim_mount
}

function EnsureDirectory {
    Param(
        [Parameter(Mandatory=$True)][string]$folder_path
    )
    if(-Not (Test-Path $folder_path)) {
        New-Item -Path $folder_path -ItemType "directory"
        LogOutput -message "Creating $folder_path..."
    } else {
        LogOutput -message "$folder_path already exists, skipping creation..."
    }
}


function EnsurePEFolder {
    Param(
        [Parameter(Mandatory=$True)][string]$folder_path
    )
    if(-Not (Test-Path ($folder_path))) {
        if ($folder_path -contains "amd64".ToLower()) {
            # We can't just create a normal folder, we have to use the copype command
            copype amd64 $folder_path
            LogOutput -message "Creating $folder_path..."
        } elseif ($folder_path -contains "x86".ToLower()) {
            # We can't just create a normal folder, we have to use the copype command
            copype x86 $folder_path
            LogOutput -message "Creating $folder_path..."
        } else {
            LogOutput -message "Probably unsupported architecture"
            throw "Probably unsupported architecture"
        }
        
    } else {
        LogOutput -message "$folder_path already exists, skipping copype..."
    }
}


function CopyFileIdempotently {
    Param(
        [string]$file_path,
        [string]$full_destination_path
    )

    if(-Not (Test-Path ($full_destination_path))) {
        Copy-Item $file_path -Destination $full_destination_path
        if(Test-Path ($full_destination_path)) {
            LogOutput -message "Successfully copied $file_path to $full_destination_path"
        } else {
            LogOutput -message "Failed to copy $file_path to $full_destination_path"
        }
    } else {
        LogOutput -message "$file_path already exists at $full_destination_path. Skipping..."
    }
    return $output
}

function EnsureDismPackage {
    Param(
        [Parameter(Mandatory=$True)][string]$mount,
        [string]$PackagePath
    )

    $addPackage = Add-WindowsPackage -Path $mount -PackagePath $PackagePath
    LogOutput -message "Adding $PackagePath to $mount ..."
}

function AddDismPackages {
    Param(
        [Parameter(Mandatory=$True)][string]$base_path,
        [Parameter(Mandatory=$True)][string]$wim_mount,
        [Parameter(Mandatory=$True)][string[]]$packages
    )
    foreach($package in $packages) {
        $PackagePath = "$base_path\$package"
        EnsureDismPackage -mount $wim_mount -PackagePath $PackagePath
    }
}


function main {

    [string[]] $winpe_base_paths = @("C:\WinPE_amd64")
    foreach ($winpe_base_path in $winpe_base_paths) {
        $boot_wim = ($winpe_base_path + '\media\sources\boot.wim')
        $wim_mount = ($winpe_base_path + '\mount')
        
        EnsurePEFolder -folder_path $winpe_base_path
        MountWim -boot_wim $boot_wim -wim_mount $wim_mount -discard $discard
        $shutdown_exe_destination = ($wim_mount + "\Windows\System32\shutdown.exe")
        CopyFileIdempotently -file_path "C:\Windows\System32\shutdown.exe" -full_destination_path $shutdown_exe_destination

        [string[]] $cabPackages = @(
            "WinPE-WMI.cab",
            "en-us\WinPE-WMI_en-us.cab",
            "WinPE-NetFX.cab",
            "en-us\WinPE-NetFX_en-us.cab",
            "WinPE-Scripting.cab",
            "en-us\WinPE-Scripting_en-us.cab",
            "WinPE-PowerShell.cab",
            "en-us\WinPE-PowerShell_en-us.cab",
            "WinPE-StorageWMI.cab",
            "en-us\WinPE-StorageWMI_en-us.cab",
            "WinPE-DismCmdlets.cab",
            "en-us\WinPE-DismCmdlets_en-us.cab"
        )
        
        #$WinPE_OCs = ""
        if ($winpe_base_path -Match "x86") {
            # Set-Variable -Name "WinPE_OCs" -Value "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\x86\WinPE_OCs"
            $WinPE_OCs = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\x86\WinPE_OCs"
        } elseif ($winpe_base_path -Match "amd64") {
            # Set-Variable -Name "WinPE_OCs" -Value "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs"
            $WinPE_OCs = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs"
        }
        # base_path should not have a trailing slash. Packages should not have a prefix slash either.
        AddDismPackages -base_path $WinPE_OCs -wim_mount $wim_mount -packages $cabPackages

        EnsureDirectory -folder_path ($winpe_base_path + "\src")
    }
}
main