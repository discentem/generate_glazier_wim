Param(
    [Parameter(Mandatory=$False)] [bool]$discard = $False,
    [Parameter()][string]$global_scratch_dir = "C:\Users\brandon\generate_glazier_wim_scratch"
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
}

function EnsureNewDirectory {
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

function CloneGithubRepo {
    Param(
        [Parameter(Mandatory=$True)][string]$repo,
        [Parameter()][string]$scratch_dir=$global_scratch_dir,
        [Parameter()][string]$destination_in_scratch="glazier_repo"
    )
    if(-Not (Test-Path $scratch_dir)) {
        New-Item -Path $scratch_dir -ItemType "directory"
    }

    git clone $repo "$scratch_dir\$destination_in_scratch"

    return "$scratch_dir\$destination_in_scratch"
}

function DownloadFileAndVerify {
    Param(
        [Parameter(Mandatory=$True)][string]$hash,
        [Parameter(Mandatory=$True)][string]$url,
        [Parameter(Mandatory=$True)][string]$destination
    )
    Invoke-WebRequest $py_url -OutFile "$destination"
    $actual_hash = (Get-FileHash $destination -Algorithm MD5).Hash
    if($hash -eq $actual_hash) {
        LogOutput -message "Downloaded $url to $destination and hashes match..."
    } else {
        Remove-Item $destination
        throw "Hashes don't match"
    }

    return $destination
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
        
        #$WinPE_OCs = ""
        if ($winpe_base_path -Match "x86") {
            # Set-Variable -Name "WinPE_OCs" -Value "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\x86\WinPE_OCs"
            $WinPE_OCs = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\x86\WinPE_OCs"
        } elseif ($winpe_base_path -Match "amd64") {
            # Set-Variable -Name "WinPE_OCs" -Value "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs"
            $WinPE_OCs = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs"
        }
        # AddDismPackages expects base_path to NOT have a trailing slash. Packages are expect not to have a prefix slash either.
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
        AddDismPackages -base_path $WinPE_OCs -wim_mount $wim_mount -packages $cabPackages

        EnsureNewDirectory -folder_path ($wim_mount + "\src")
        EnsureNewDirectory -folder_path ($wim_mount + "\src\glazier")
        # DownloadFilesFromGithubRepo -Owner "google" -Repository "glazier" -Path "glazier" -DestinationPath "$winpe_base_path\src\"
        $repo_destination = (CloneGithubRepo -repo 'https://github.com/google/glazier.git')
        Copy-Item -Path "$repo_destination\glazier\*" -Destination "$wim_mount\src\glazier" -Recurse
        EnsureNewDirectory -folder_path "$global_scratch_dir"
        EnsureNewDirectory -folder_path "$global_scratch_dir\python_installer"
        $py_url = "https://www.python.org/ftp/python/3.8.2/python-3.8.2-amd64.exe"
        $py_exe = DownloadFileAndVerify -hash 'b5df1cbb2bc152cd70c3da9151cb510b' -url $py_url -destination "$global_scratch_dir\python_installer\python.exe"
        EnsureNewDirectory -folder_path "$wim_mount\python"
        ./$py_exe /quiet DefaultJustForMeTargetDir=$wim_mount\python
    }
}
main