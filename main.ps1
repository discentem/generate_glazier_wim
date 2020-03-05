Param(
    [Parameter(Mandatory=$False)] [bool]$discard = $False
)

function LogOutput {
    Param(
        [Parameter(Mandatory=$True)][string]$message
    )
    $output = $message

    Write-Output $output
}


function EnsureFile {
    Param(
        [string]$file_path,
        [string]$full_destination_path
    )

    if(-Not (Test-Path ($full_destination_path))) {
        Copy-Item $file_path -Destination $full_destination_path
        LogOutput -message "Copying $file_path to $full_destination_path"
    } else {
        LogOutput -message "$file_path already exists at $full_destination_path. Skipping..."
    }
    return $output
}

function EnsureWimMount {
    Param(
        [Parameter(Mandatory=$True)][string]$boot_wim,
        [Parameter(Mandatory=$True)][string]$wim_mount,
        [bool]$discard = $False
    )
    if ($discard) {
        LogOutput -message '$discart=$True: Dismounting and remounting...'
        Dismount-WindowsImage -Path $wim_mount -Discard
        Mount-WindowsImage -ImagePath $boot_wim -Index 1 -Path $wim_mount

    } else {
        if(Test-Path $wim_mount) {
            LogOutput -message "Skipping, WIM already mounted to $wim_mount"
        } else {
            LogOutput -message "Mounting $boot_wim to $wim_mount..."
            Mount-WindowsImage -ImagePath $boot_wim -Index 1 -Path $wim_mount
        }
    }
}


function main {
    $dism_dir = 'C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\DISM'
    $dism_module = $dism_dir
    $dism = "$dism_dir\dism.exe"
    # Adding $dism_dir to path allows this to run from Admin Powershell instead of Admin ADK Shell
    $env:Path = "$dism_dir;" + $env:Path
    Import-Module ($dism_module)

   #[string[]] $winpe_base_paths = @("C:\WinPE_x86", "C:\WinPE_amd64")
    [string[]] $winpe_base_paths = @("C:\WinPE_amd64")
    foreach ($winpe_base_path in $winpe_base_paths) {
        $boot_wim = ($winpe_base_path + '\media\sources\boot.wim')
        $wim_mount = ($winpe_base_path + '\mount')
        
        EnsureWimMount -boot_wim $boot_wim -wim_mount $wim_mount -discard $discard
        $shutdown_exe_destination = ($wim_mount + "\Windows\System32\shutdown.exe")
        EnsureFile -file_path "C:\Windows\System32\shutdown.exe" -full_destination_path $shutdown_exe_destination

    }

        # $shutdown_exe = "C:\Windows\System32\shutdown.exe"
        # $shutdown_exe_destination = ($winpe_path + "\mount\Windows\System32\shutdown.exe")
        # $output = copyShutdownToWinPE -destination_path $shutdown_exe_destination
        # Write-Output $output

        # $winpe_ocs_base = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment"
        # if ($winpe_path -contains "x86") {
        #     $winpe_ocs = ($winpe_ocs_base + "\x86\WinPE_OCs")
        # } else {
        #     $winpe_ocs = ($winpe_ocs_base + "\amd64\WinPE_OCs")
        # }
       
    #         Dism /Add-Package /Image:"$winpe_path\mount" /PackagePath:"$winpe_ocs\WinPE-WMI.cab"
    #         Dism /Add-Package /Image:"$winpe_path\mount" /PackagePath:"$winpe_ocs\en-us\WinPE-WMI_en-us.cab"
    #         Dism /Add-Package /Image:"$winpe_path\mount" /PackagePath:"$winpe_ocs\WinPE-NetFX.cab"
    #         Dism /Add-Package /Image:"$winpe_path\mount" /PackagePath:"$winpe_ocs\en-us\WinPE-NetFX_en-us.cab"
    #         Dism /Add-Package /Image:"$winpe_path\mount" /PackagePath:"$winpe_ocs\WinPE-Scripting.cab"
    #         Dism /Add-Package /Image:"$winpe_path\mount" /PackagePath:"$winpe_ocs\en-us\WinPE-Scripting_en-us.cab"
    #         Dism /Add-Package /Image:"$winpe_path\mount" /PackagePath:"$winpe_ocs\WinPE-PowerShell.cab"
    #         Dism /Add-Package /Image:"$winpe_path\mount" /PackagePath:"$winpe_ocs\en-us\WinPE-PowerShell_en-us.cab"
    #         Dism /Add-Package /Image:"$winpe_path\mount" /PackagePath:"$winpe_ocs\WinPE-StorageWMI.cab"
    #         Dism /Add-Package /Image:"$winpe_path\mount" /PackagePath:"$winpe_ocs\en-us\WinPE-StorageWMI_en-us.cab"
    #         Dism /Add-Package /Image:"$winpe_path\mount" /PackagePath:"$winpe_ocs\WinPE-DismCmdlets.cab"
    #         Dism /Add-Package /Image:"$winpe_path\mount" /PackagePath:"$winpe_ocs\en-us\WinPE-DismCmdlets_en-us.cab"
    }

main