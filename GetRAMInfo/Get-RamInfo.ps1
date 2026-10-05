<#
.SYNOPSIS
    Lists the installed RAM modules: slot, brand, part number, size,
    DDR type and frequency.

.DESCRIPTION
    Queries WMI (Win32_PhysicalMemory class). No administrator rights required.
    Compatible from Windows 7 (PowerShell 2.0) up to Windows 11 (PowerShell 5.1 and 7).

    When Windows does not report the DDR type (common on Windows 7), it is
    inferred from the module's part number, or failing that from its speed,
    and the value is then followed by "(estimated)".

    Frequency: the "MHz" value shown is the marketing figure (e.g. DDR4-2666),
    which is actually a data rate in MT/s. The real bus clock is half of it
    (the one CPU-Z shows as "DRAM Frequency").

    Virtual machines (VirtualBox, VMware, Hyper-V, QEMU/KVM, Xen, Parallels...)
    are recognized from the system manufacturer and model. Their memory modules
    are emulated: their type is shown as "Virtual" instead of being estimated,
    and the RAM allocated to the VM, as seen by Windows, is shown as well (some
    hypervisors, VirtualBox by default, expose no module at all).

.PARAMETER CsvPath
    Optional path of a CSV file to export the result to.

.EXAMPLE
    .\Get-RamInfo.ps1

.EXAMPLE
    .\Get-RamInfo.ps1 -CsvPath .\ram.csv
#>
param(
    [string]$CsvPath
)

# JEDEC manufacturer codes as Windows reports them (bank byte + identifier)
$JedecVendors = @{
    '80CE' = 'Samsung';   '80AD' = 'SK Hynix';   '802C' = 'Micron'
    '859B' = 'Crucial';   '0198' = 'Kingston';   '029E' = 'Corsair'
    '04CD' = 'G.Skill';   '04EF' = 'Team Group'; '04CB' = 'ADATA'
    '0443' = 'Ramaxel';   '830B' = 'Nanya';      '80FE' = 'Elpida'
    '8551' = 'Qimonda';   '80C1' = 'Infineon';   '014F' = 'Transcend'
    '017A' = 'Apacer';    '0125' = 'Kingmax';    '8502' = 'Patriot'
    '01BA' = 'PNY'
}

# Part number prefix -> manufacturer, used when the manufacturer code is empty
$PartNumberVendors = @(
    @('^M[34][0-9]{2}[A-Z]', 'Samsung'),
    @('^(HMT|HMA|HMC|HYMP)', 'SK Hynix'),
    @('^MT[AC]?[0-9]', 'Micron'),
    @('^(CT[0-9]|BLS?[0-9])', 'Crucial'),
    @('^(KVR|KHX|KF[0-9]|KCP|KTD|KTH|KTL|KCM|ACR[0-9]|9905|99U5|HX[0-9])', 'Kingston'),
    @('^CM[A-Z]', 'Corsair'),
    @('^F[2-5]-', 'G.Skill'),
    @('^(AD[2-5]|AX[2-5])', 'ADATA'),
    @('^NT[0-9]', 'Nanya'),
    @('^EB[EJ]', 'Elpida'),
    @('^RM[ST]', 'Ramaxel')
)

# SMBIOSMemoryType property (Windows 10+): raw values from the SMBIOS spec
$SmbiosTypes = @{
    15 = 'SDRAM';  17 = 'RDRAM';  18 = 'DDR';    19 = 'DDR2';   20 = 'DDR2 FB-DIMM'
    24 = 'DDR3';   25 = 'FBD2';   26 = 'DDR4';   27 = 'LPDDR';  28 = 'LPDDR2'
    29 = 'LPDDR3'; 30 = 'LPDDR4'; 32 = 'HBM';    33 = 'HBM2';   34 = 'DDR5'
    35 = 'LPDDR5'; 36 = 'HBM3'
}

# MemoryType property (legacy, the only one available on Windows 7): CIM enumeration
$CimTypes = @{ 17 = 'SDRAM'; 19 = 'RDRAM'; 20 = 'DDR'; 21 = 'DDR2'; 22 = 'DDR2 FB-DIMM'; 24 = 'DDR3'; 25 = 'FBD2'; 26 = 'DDR4' }

# ROM / Flash memories (e.g. the BIOS "SYSTEM ROM") that some firmwares report as memory modules
$SmbiosRomTypes = @(8, 9, 10, 11, 12)
$CimRomTypes = @(10, 11, 12, 13, 14)

$FormFactors = @{ 7 = 'SIMM'; 8 = 'DIMM'; 11 = 'RIMM'; 12 = 'SO-DIMM' }

# "Manufacturer Model" of the system -> hypervisor
$Hypervisors = @(
    @('virtualbox|innotek', 'VirtualBox'),
    @('vmware', 'VMware'),
    @('microsoft corporation virtual machine', 'Hyper-V'),
    @('parallels', 'Parallels'),
    @('qemu|bochs|standard pc \(|openstack|ovirt|rhev|proxmox|(^| )kvm( |$)', 'QEMU/KVM'),
    @('(^| )xen( |$)|hvm domu', 'Xen'),
    @('virtualmac|apple virtualization', 'Apple Virtualization'),
    @('bhyve', 'bhyve'),
    @('amazon ec2', 'Amazon EC2'),
    @('google compute engine', 'Google Compute Engine')
)

function Get-WmiData([string]$Class) {
    if (Get-Command Get-CimInstance -ErrorAction SilentlyContinue) {
        Get-CimInstance -ClassName $Class
    } else {
        Get-WmiObject -Class $Class
    }
}

function Resolve-Vendor([string]$Raw, [string]$PartNumber) {
    $m = "$Raw".Trim()
    $isPlaceholder = (-not $m) -or ($m -match '^(0+|F+|Unknown|Undefined|Not ?Specified|Not Available|Manufacturer[0-9]*|To Be Filled.*)$')

    $hex = $null
    if (-not $isPlaceholder) {
        $upper = $m.ToUpper()
        if ($upper -match '0X([0-9A-F]{4})') { $hex = $matches[1] }           # e.g. "Unknown - [0x9B85]" (HP BIOS)
        elseif ($upper -match '^[0-9A-F]{4,16}$') { $hex = $upper }
        else { return $m }                                                    # already a plain name

        $candidates = @(
            $hex.Substring(0, 4),                          # "80CE...": standard format
            ($hex.Substring(2, 2) + $hex.Substring(0, 2)), # "9B85": swapped bytes
            ('80' + $hex.Substring(0, 2))                  # "CE00...": bank 1 without the bank byte
        )
        foreach ($code in $candidates) {
            if ($JedecVendors.ContainsKey($code)) { return $JedecVendors[$code] }
        }
    }

    $p = "$PartNumber".Trim().ToUpper()
    if ($p) {
        foreach ($entry in $PartNumberVendors) {
            if ($p -match $entry[0]) { return "$($entry[1]) (estimated)" }
        }
    }

    if ($hex) { return "JEDEC code $hex" }
    return 'Unknown'
}

function Get-DdrFromPartNumber([string]$PartNumber) {
    $p = "$PartNumber".Trim().ToUpper()
    if (-not $p) { return $null }

    if ($p -match 'LPDDR([2-5])')          { return "LPDDR$($matches[1])" }
    if ($p -match 'DDR([2-5])')            { return "DDR$($matches[1])" }
    if ($p -match 'PC([2-5])L?-')          { return "DDR$($matches[1])" }   # e.g. PC3L-12800
    if ($p -match '^F([2-5])-')            { return "DDR$($matches[1])" }   # G.Skill
    if ($p -match '^HYMP')                 { return 'DDR2' }                # SK Hynix
    if ($p -match '^HMT')                  { return 'DDR3' }
    if ($p -match '^HMA')                  { return 'DDR4' }
    if ($p -match '^HMC')                  { return 'DDR5' }
    if ($p -match '^M[34][0-9]{2}([TBAR])') {                                # Samsung
        switch ($matches[1]) { 'T' { return 'DDR2' } 'B' { return 'DDR3' } 'A' { return 'DDR4' } 'R' { return 'DDR5' } }
    }
    if ($p -match '^MT[0-9]+H')            { return 'DDR2' }                # Micron
    if ($p -match '^MT[0-9]+[JK]')         { return 'DDR3' }
    if ($p -match '^MTA')                  { return 'DDR4' }
    if ($p -match '^MTC')                  { return 'DDR5' }
    if ($p -match '^CT[0-9]+B[ADF][0-9]')  { return 'DDR3' }                # Crucial
    if ($p -match '^CT[0-9]+G4[A-Z]')      { return 'DDR4' }
    if ($p -match '^CT[0-9]+G[0-9]{2}C[0-9]{2}[SU]5') { return 'DDR5' }
    if ($p -match '^KVR(13|16|18)[A-Z]')   { return 'DDR3' }                # Kingston
    if ($p -match '^KVR(21|24|26|29|32)[A-Z]') { return 'DDR4' }
    if ($p -match '^KVR(48|52|56|64)[A-Z]') { return 'DDR5' }
    return $null
}

function Get-DdrFromSpeed([int]$Mts) {
    if ($Mts -le 0)    { return $null }
    if ($Mts -lt 200)  { return 'SDRAM' }
    if ($Mts -le 400)  { return 'DDR' }
    if ($Mts -le 667)  { return 'DDR2' }
    if ($Mts -le 1066) { return 'DDR2 or DDR3' }
    if ($Mts -le 1866) { return 'DDR3' }
    if ($Mts -lt 4800) { return 'DDR4' }
    return 'DDR5'
}

function Get-DdrType($Module, [bool]$Virtual) {
    if ($Module.SMBIOSMemoryType) {
        $t = [int]$Module.SMBIOSMemoryType
        if ($SmbiosTypes.ContainsKey($t)) { return $SmbiosTypes[$t] }
    }
    if ($Module.MemoryType) {
        $t = [int]$Module.MemoryType
        if ($CimTypes.ContainsKey($t)) { return $CimTypes[$t] }
    }
    if ($Virtual) { return 'Virtual' }      # emulated module: an estimated DDR type would be misleading
    $guess = Get-DdrFromPartNumber $Module.PartNumber
    if (-not $guess) { $guess = Get-DdrFromSpeed ([int]$Module.Speed) }
    if ($guess) { return "$guess (estimated)" }
    return 'Unknown'
}

function Test-RomDevice($Module) {
    ($Module.SMBIOSMemoryType -and ($SmbiosRomTypes -contains [int]$Module.SMBIOSMemoryType)) -or
    ($Module.MemoryType -and ($CimRomTypes -contains [int]$Module.MemoryType))
}

function Get-Hypervisor([string]$Manufacturer, [string]$Model) {
    $text = "$Manufacturer $Model".Trim()
    foreach ($entry in $Hypervisors) {
        if ($text -match $entry[0]) { return $entry[1] }
    }
    return $null
}

function Format-Speed($Value) {
    if ($Value -and [int]$Value -gt 0) { return [int]$Value }
    return '?'
}

# --- Collection ---------------------------------------------------------------

$sticks = @(Get-WmiData 'Win32_PhysicalMemory' | Where-Object { -not (Test-RomDevice $_) })
$computer = @(Get-WmiData 'Win32_ComputerSystem')[0]
$arrays = @(Get-WmiData 'Win32_PhysicalMemoryArray' | Where-Object { $_.Use -eq 3 })   # 3 = system memory

$pcVendor = "$($computer.Manufacturer)".Trim()
$pcModel = "$($computer.Model)".Trim()
$hypervisor = Get-Hypervisor $pcVendor $pcModel
$osGb = [math]::Round([double]$computer.TotalPhysicalMemory / 1GB, 1)   # RAM visible to Windows

$modules = foreach ($m in $sticks) {
    $slot = "$($m.DeviceLocator)".Trim()
    if (-not $slot) { $slot = "$($m.BankLabel)".Trim() }

    $format = ''
    if ($m.FormFactor -and $FormFactors.ContainsKey([int]$m.FormFactor)) { $format = $FormFactors[[int]$m.FormFactor] }

    $gb = '?'                                                       # size not reported by the firmware
    if ([double]$m.Capacity -gt 0) { $gb = [math]::Round([double]$m.Capacity / 1GB, 1) }

    $brand = Resolve-Vendor $m.Manufacturer $m.PartNumber
    if ($hypervisor -and $brand -eq 'Unknown') { $brand = $hypervisor }

    New-Object PSObject -Property @{
        'Slot'  = $slot
        'Brand'       = $brand
        'Part number'    = "$($m.PartNumber)".Trim()
        'GB'           = $gb
        'Type'         = Get-DdrType $m ([bool]$hypervisor)
        'Form factor'       = $format
        'Nominal MHz'  = Format-Speed $m.Speed
        'Current MHz'   = Format-Speed $m.ConfiguredClockSpeed
    }
}
$modules = @($modules | Select-Object 'Slot', 'Brand', 'Part number', 'GB', 'Type', 'Form factor', 'Nominal MHz', 'Current MHz')

# --- Output -------------------------------------------------------------------

Write-Host ''
if ($hypervisor) {
    Write-Host ("VM: {0} {1} ({2}) - hypervisor: {3}" -f $pcVendor, $pcModel, $env:COMPUTERNAME, $hypervisor) -ForegroundColor Cyan
} else {
    Write-Host ("PC: {0} {1} ({2})" -f $pcVendor, $pcModel, $env:COMPUTERNAME) -ForegroundColor Cyan
}

if ($modules.Count -eq 0) {
    if ($hypervisor) {
        Write-Host 'No memory module exposed by the hypervisor.' -ForegroundColor Yellow
    } else {
        Write-Host 'No RAM module reported by WMI (virtual machine?).' -ForegroundColor Yellow
    }
    if ($osGb -gt 0) { Write-Host "RAM visible to the OS: $osGb GB" -ForegroundColor Cyan }
    Write-Host ''
    return
}

$modules | Format-Table -AutoSize | Out-Host

$totalGb = [math]::Round(([double]($sticks | Measure-Object -Property Capacity -Sum).Sum) / 1GB, 1)
if ($hypervisor) {
    # The slot count and maximum capacity of a virtual firmware are meaningless
    $summary = "Total: $totalGb GB in $($modules.Count) virtual module(s)"
    if ($osGb -gt 0) { $summary += " - RAM visible to the OS: $osGb GB" }
} else {
    $summary = "Total: $totalGb GB in $($modules.Count) module(s)"
    if ($arrays.Count -gt 0) {
        $slots = [int]($arrays | Measure-Object -Property MemoryDevices -Sum).Sum
        if ($slots -gt 0) { $summary += " - $($modules.Count)/$slots slot(s) used" }
        $maxKb = 0
        foreach ($a in $arrays) {
            $kb = [double]$a.MaxCapacityEx
            if ($kb -le 0) { $kb = [double]$a.MaxCapacity }
            $maxKb += $kb
        }
        if ($maxKb -gt 0) { $summary += " - BIOS official max: $([math]::Round($maxKb / 1MB)) GB" }
    }
}
Write-Host $summary -ForegroundColor Cyan
Write-Host ''

if ($CsvPath) {
    $modules | Export-Csv -Path $CsvPath -NoTypeInformation -UseCulture -Encoding UTF8
    Write-Host "Exported to $CsvPath" -ForegroundColor Green
}
