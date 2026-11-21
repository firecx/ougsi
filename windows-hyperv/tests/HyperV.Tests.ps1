$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\HyperV.ps1')

function Assert-That {
    param([bool] $Condition, [string] $Message)

    if (-not $Condition) {
        throw $Message
    }
}

function Assert-Failure {
    param([scriptblock] $Operation, [string] $ExpectedError)

    try {
        & $Operation | Out-Null
    }
    catch {
        if ($_.Exception.Message -like "*$ExpectedError*") {
            return
        }

        throw
    }

    throw "Expected failure: $ExpectedError"
}

# These functions stand in for the Hyper-V cmdlets. Files use real temporary storage.
$vms = @{}
$failFirmware = $false
$lastRemovedId = $null

function Get-VM {
    param($Id)

    if ($Id) { return $vms[$Id] }
    return $vms.Values
}

function New-VM {
    param($Name, $Generation, $MemoryStartupBytes, $Path, $VHDPath, $SwitchName)

    $vm = [pscustomobject] @{
        Id = [guid]::NewGuid()
        Name = $Name
        Generation = $Generation
        State = 'Off'
        DiskPath = $VHDPath
        SwitchName = $SwitchName
        MemoryBytes = $MemoryStartupBytes
        DynamicMemoryEnabled = $true
        CpuCount = $null
        NestedVirtualization = $null
        EnableSecureBoot = $null
        SecureBootTemplate = $null
        BootOrder = $null
    }
    $vms[$vm.Id] = $vm
    return $vm
}

function Get-VMSwitch { [pscustomobject] @{ Name = 'Development [NAT]' } }
function Get-VMHardDiskDrive { param($VM) return $VM.DiskPath }
function Add-VMDvdDrive { param($VM, $Path, [switch] $Passthru) return $Path }
function Start-VM { param($VM) $VM.State = 'Running' }

function Get-VHD {
    param($Path)

    return @{ ParentPath = $null; Attached = $false; VhdType = 'Dynamic' }
}

function New-VHD {
    param($Path, [switch] $Dynamic, $SizeBytes)

    Assert-That $Dynamic 'Expected a dynamic VHDX for the ISO.'
    [System.IO.File]::WriteAllText($Path, [string] $SizeBytes)
}

function Set-VMMemory {
    param($VM, $DynamicMemoryEnabled)

    $VM.DynamicMemoryEnabled = $DynamicMemoryEnabled
}

function Set-VMProcessor {
    param($VM, $Count, $ExposeVirtualizationExtensions)

    $VM.CpuCount = $Count
    $VM.NestedVirtualization = $ExposeVirtualizationExtensions
}

function Set-VMFirmware {
    param($VM, $BootOrder, $EnableSecureBoot, $SecureBootTemplate)

    if ($failFirmware) { throw 'Simulated firmware failure.' }
    $VM.EnableSecureBoot = $EnableSecureBoot
    $VM.SecureBootTemplate = $SecureBootTemplate
    $VM.BootOrder = $BootOrder
}

function Remove-VM {
    param($VM, [switch] $Force)

    $script:lastRemovedId = $VM.Id
    $vms.Remove($VM.Id)
}

$fixtureParent = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\.build'))
New-Item -ItemType Directory -Path $fixtureParent -Force | Out-Null
$fixtureRoot = Join-Path $fixtureParent "hyperv-test-$([guid]::NewGuid())"
New-Item -ItemType Directory -Path $fixtureRoot | Out-Null

try {
    $isoPath = Join-Path $fixtureRoot 'development installer.iso'
    $sourcePath = Join-Path $fixtureRoot 'development template.vhdx'
    [System.IO.File]::WriteAllText($isoPath, 'ISO fixture')
    [System.IO.File]::WriteAllText($sourcePath, 'VHDX fixture')

    $isoRequest = @{
        name = 'iso-test'
        storageRoot = $fixtureRoot
        isoPath = $isoPath
        switchName = 'Development [NAT]'
        cpuCount = 2
        memoryBytes = 2GB
        diskBytes = 20GB
        nestedVirtualization = $true
        secureBootTemplate = 'MicrosoftUEFICertificateAuthority'
        start = $true
    }
    $iso = New-DevelopmentVm $isoRequest
    $isoVm = $vms[[guid] $iso.id]
    Assert-That ($iso.state -eq 'Running' -and $iso.generation -eq 2) 'Expected a running generation 2 VM.'
    Assert-That ($isoVm.BootOrder.Count -eq 2 -and $isoVm.BootOrder[0] -eq $isoPath -and
        $isoVm.BootOrder[1] -eq $iso.diskPath) 'Expected ISO first and system disk second in boot order.'
    Assert-That ([System.IO.File]::ReadAllText($iso.diskPath) -eq '21474836480') 'Expected the requested disk size.'
    Assert-That ($isoVm.CpuCount -eq 2 -and $isoVm.NestedVirtualization -and $isoVm.MemoryBytes -eq 2GB -and
        -not $isoVm.DynamicMemoryEnabled) 'Expected the requested CPU, static memory and nested virtualization.'
    Assert-That ($isoVm.EnableSecureBoot -eq 'On' -and $isoVm.SecureBootTemplate -eq $isoRequest.secureBootTemplate -and
        $isoVm.SwitchName -eq $isoRequest.switchName) 'Expected the requested secure boot template and switch.'

    $cloneRequest = @{
        name = 'clone-test'
        storageRoot = $fixtureRoot
        sourceVhdxPath = $sourcePath
        cpuCount = 1
        memoryBytes = 1GB
        start = $false
    }
    $clone = New-DevelopmentVm $cloneRequest
    $cloneVm = $vms[[guid] $clone.id]
    Assert-That ($clone.state -eq 'Off' -and $cloneVm.BootOrder.Count -eq 1 -and
        $cloneVm.BootOrder[0] -eq $clone.diskPath) 'Expected the clone off with its own disk in the boot order.'
    Assert-That ([System.IO.File]::ReadAllText($clone.diskPath) -eq 'VHDX fixture') 'Expected an independent disk copy.'
    [System.IO.File]::WriteAllText($clone.diskPath, 'changed clone')
    Assert-That ([System.IO.File]::ReadAllText($sourcePath) -eq 'VHDX fixture') 'Expected the source VHDX to be untouched.'

    Assert-Failure { New-DevelopmentVm $cloneRequest } 'already exists'
    Assert-That ([System.IO.File]::ReadAllText($clone.diskPath) -eq 'changed clone') 'Expected a duplicate request to preserve the existing disk.'

    $occupiedRequest = $cloneRequest.Clone()
    $occupiedRequest.name = 'occupied-storage-test'
    $occupiedDirectory = Join-Path $fixtureRoot $occupiedRequest.name
    New-Item -ItemType Directory -Path $occupiedDirectory | Out-Null
    $occupiedDisk = Join-Path $occupiedDirectory 'system.vhdx'
    [System.IO.File]::WriteAllText($occupiedDisk, 'existing file')
    Assert-Failure { New-DevelopmentVm $occupiedRequest } $occupiedRequest.name
    Assert-That ([System.IO.File]::ReadAllText($occupiedDisk) -eq 'existing file') 'Expected an existing storage directory to be untouched.'

    $failFirmware = $true
    $failedRequest = $isoRequest.Clone()
    $failedRequest.name = 'rollback-test'
    Assert-Failure { New-DevelopmentVm $failedRequest } 'Simulated firmware failure'
    Assert-That ($lastRemovedId -and -not $vms.ContainsKey($lastRemovedId) -and $vms.Count -eq 2) 'Expected rollback to remove only the new VM.'
    Assert-That (-not (Test-Path -LiteralPath (Join-Path $fixtureRoot $failedRequest.name))) 'Expected rollback to remove the new VM directory.'

    Write-Output 'Hyper-V backend tests passed: ISO, VHDX, duplicate name, occupied directory, rollback.'
}
finally {
    $resolvedRoot = (Resolve-Path -LiteralPath $fixtureRoot).ProviderPath
    if ($resolvedRoot -eq $fixtureRoot -and [System.IO.Path]::GetDirectoryName($resolvedRoot) -eq $fixtureParent) {
        Remove-Item -LiteralPath $resolvedRoot -Recurse -Force
    }
    else {
        throw "Refusing to remove an unexpected fixture directory: '$resolvedRoot'."
    }
}
