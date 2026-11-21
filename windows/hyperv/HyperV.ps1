function Import-HyperVHost {
    if (-not (Get-Module -ListAvailable -Name Hyper-V)) {
        throw 'The Hyper-V PowerShell module is unavailable. Install Hyper-V and its PowerShell management tools.'
    }

    Import-Module Hyper-V
    $service = Get-Service -Name vmms -ErrorAction SilentlyContinue
    if ($null -eq $service -or $service.Status -ne 'Running') {
        throw 'The Hyper-V Virtual Machine Management service (vmms) is unavailable or stopped.'
    }
}

function Get-LocalPath {
    param([string] $Path)

    if ($Path -cnotmatch '^[a-zA-Z]:[\\/]' -or $Path.Substring(2).Contains(':')) {
        throw "Expected a fully qualified path on a local drive: '$Path'."
    }

    return [System.IO.Path]::GetFullPath($Path)
}

function Get-ImagePath {
    param([string] $Path, [string] $Extension)

    $localPath = Get-LocalPath $Path
    if ([System.IO.Path]::GetExtension($localPath) -ine $Extension -or
        -not (Test-Path -LiteralPath $localPath -PathType Leaf)) {
        throw "Expected an existing $Extension file: '$localPath'."
    }

    return $localPath
}

function Copy-Vhdx {
    param([string] $Source, [string] $Destination)

    $sourceStream = [System.IO.File]::Open($Source, 'Open', 'Read', 'Read')
    try {
        $destinationStream = [System.IO.File]::Open($Destination, 'CreateNew', 'Write', 'None')
        try {
            $sourceStream.CopyTo($destinationStream)
        }
        finally {
            $destinationStream.Dispose()
        }
    }
    finally {
        $sourceStream.Dispose()
    }
}

function Remove-EmptyDirectories {
    param([string] $Path)

    if ([System.IO.File]::GetAttributes($Path) -band [System.IO.FileAttributes]::ReparsePoint) {
        throw "Refusing to clean up a directory with a reparse point: '$Path'."
    }

    foreach ($child in [System.IO.Directory]::GetDirectories($Path)) {
        Remove-EmptyDirectories $child
    }

    # The nonrecursive overload preserves any unexpected files.
    [System.IO.Directory]::Delete($Path)
}

function New-DevelopmentVm {
    param($Request)

    $name = [string] $Request.name
    if ($name -cnotmatch '^[a-zA-Z0-9][a-zA-Z0-9_-]{0,62}\z' -or
        $name -match '^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])\z') {
        throw "Invalid VM name: '$name'."
    }

    $storageRoot = Get-LocalPath $Request.storageRoot
    if (-not (Test-Path -LiteralPath $storageRoot -PathType Container)) {
        throw "The storage directory does not exist: '$storageRoot'."
    }

    $isoPath = $null
    $sourceVhdx = $null
    if ([bool] $Request.isoPath -eq [bool] $Request.sourceVhdxPath) {
        throw 'Specify exactly one ISO or source VHDX.'
    }

    if ($Request.isoPath) {
        $isoPath = Get-ImagePath $Request.isoPath '.iso'
    }
    else {
        $sourceVhdx = Get-ImagePath $Request.sourceVhdxPath '.vhdx'
        $image = Get-VHD -Path $sourceVhdx
        if ($image.ParentPath -or $image.VhdType -eq 'Differencing' -or $image.Attached) {
            throw 'The source VHDX must be detached and have no parent disk.'
        }
    }

    $vmParameters = @{
        Name = $name
        Generation = 2
        MemoryStartupBytes = [long] $Request.memoryBytes
    }
    $switchName = $null
    if ($Request.switchName) {
        $switches = @(Get-VMSwitch | Where-Object Name -EQ $Request.switchName)
        if ($switches.Count -ne 1) {
            throw "Expected one Hyper-V switch named '$($Request.switchName)'. Run 'check' to list switches."
        }

        $switchName = $switches[0].Name
        $vmParameters.SwitchName = $switchName
    }

    $vmPath = [System.IO.Path]::Combine($storageRoot, $name)
    $diskPath = [System.IO.Path]::Combine($vmPath, 'system.vhdx')
    $vmParameters.Path = $vmPath
    $vmParameters.VHDPath = $diskPath

    $mutex = [System.Threading.Mutex]::new($false, "Global\ougsi.hyperv.$($name.ToUpperInvariant())")
    $locked = $false
    $directoryCreated = $false
    $vmCreationAttempted = $false
    $vm = $null
    try {
        try {
            $locked = $mutex.WaitOne(0)
        }
        catch [System.Threading.AbandonedMutexException] {
            $locked = $true
        }

        if (-not $locked) {
            throw "A Hyper-V create operation for '$name' is already running."
        }

        if (Get-VM | Where-Object Name -EQ $name) {
            throw "A Hyper-V VM named '$name' already exists."
        }

        # No -Force. Claim the directory before any VHDX or VM changes.
        New-Item -ItemType Directory -Path $vmPath | Out-Null
        $directoryCreated = $true

        if ($sourceVhdx) {
            Copy-Vhdx -Source $sourceVhdx -Destination $diskPath
        }
        else {
            New-VHD -Path $diskPath -Dynamic -SizeBytes ([long] $Request.diskBytes) | Out-Null
        }

        $vmCreationAttempted = $true
        $vm = New-VM @vmParameters
        Set-VMMemory -VM $vm -DynamicMemoryEnabled $false
        Set-VMProcessor -VM $vm -Count ([int] $Request.cpuCount) `
            -ExposeVirtualizationExtensions ([bool] $Request.nestedVirtualization)

        $disk = Get-VMHardDiskDrive -VM $vm
        $bootOrder = @($disk)
        if ($isoPath) {
            $dvd = Add-VMDvdDrive -VM $vm -Path $isoPath -Passthru
            $bootOrder = @($dvd, $disk)
        }

        if ($Request.secureBootTemplate) {
            Set-VMFirmware -VM $vm -BootOrder $bootOrder -EnableSecureBoot On `
                -SecureBootTemplate $Request.secureBootTemplate
        }
        else {
            Set-VMFirmware -VM $vm -BootOrder $bootOrder -EnableSecureBoot Off
        }

        if ($Request.start) {
            Start-VM -VM $vm
        }

        $result = Get-VM -Id $vm.Id
        return @{
            id = [string] $result.Id
            name = $result.Name
            state = [string] $result.State
            generation = $result.Generation
            path = $vmPath
            diskPath = $diskPath
            switchName = $switchName
        }
    }
    catch {
        $failure = $_
        try {
            if ($null -ne $vm) {
                $createdVm = Get-VM -Id $vm.Id
                if ($createdVm.State -ne 'Off') {
                    Stop-VM -VM $createdVm -TurnOff -Force
                }

                Remove-VM -VM $createdVm -Force
            }
            elseif ($vmCreationAttempted -and (Get-VM | Where-Object Name -EQ $name)) {
                # New-VM did not return an ID. Never remove an unverified VM or its disk.
                throw "Hyper-V reports a VM named '$name' without a confirmed ID. Inspect it before retrying."
            }

            if ($directoryCreated) {
                if ([System.IO.File]::GetAttributes($vmPath) -band [System.IO.FileAttributes]::ReparsePoint) {
                    throw "Refusing to clean up a directory with a reparse point: '$vmPath'."
                }

                [System.IO.File]::Delete($diskPath)
                Remove-EmptyDirectories $vmPath
            }
        }
        catch {
            throw "$($failure.Exception.Message) Cleanup incomplete for '$vmPath': $($_.Exception.Message)"
        }

        throw $failure
    }
    finally {
        if ($locked) {
            $mutex.ReleaseMutex()
        }

        $mutex.Dispose()
    }
}

# Windows PowerShell 5.1 entry point. Read one JSON request and write one JSON result.
if ($MyInvocation.InvocationName -eq '.') {
    return
}

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$WarningPreference = 'SilentlyContinue'
$InformationPreference = 'SilentlyContinue'
[Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

try {
    $request = ConvertFrom-Json -InputObject ([Console]::In.ReadToEnd())
    Import-HyperVHost

    $response = switch ($request.operation) {
        'check' {
            Get-VM | Out-Null
            @{
                available = $true
                switches = @(Get-VMSwitch | Select-Object -ExpandProperty Name | Sort-Object)
            }
        }
        'create' { New-DevelopmentVm $request }
        default { throw "Unsupported Hyper-V operation: '$($request.operation)'." }
    }

    [Console]::WriteLine((ConvertTo-Json -InputObject $response -Compress))
}
catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}
