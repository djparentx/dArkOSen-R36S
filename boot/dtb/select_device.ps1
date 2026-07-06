#Requires -Version 5.1
Set-StrictMode -Version Latest

$ErrorActionPreference = 'Stop'
$host.UI.RawUI.WindowTitle = "R36S / Clone / Soysauce DTB Selector"

Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "   R36S DTB Firmware Selector"                   -ForegroundColor Cyan
Write-Host "==================================================`n" -ForegroundColor Cyan

# Determine root folder
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if ((Split-Path -Leaf $scriptDir) -eq "dtb") {
    $rootDir = Split-Path -Parent $scriptDir
} else {
    $rootDir = $scriptDir
}

Write-Host "Root folder: $rootDir" -ForegroundColor DarkCyan

# Find INI
$iniCandidates = @(
    (Join-Path $rootDir "r36_devices.ini"),
    (Join-Path $rootDir "dtb\r36_devices.ini")
)

$iniPath = $null
foreach ($candidate in $iniCandidates) {
    if (Test-Path $candidate) {
        $iniPath = $candidate
        Write-Host "Using INI: $iniPath" -ForegroundColor Green
        break
    }
}

if (-not $iniPath) {
    Write-Host "ERROR: r36_devices.ini not found" -ForegroundColor Red
    Pause
    exit 1
}

# Parse INI
Write-Host "`nReading devices..." -ForegroundColor Yellow

$sections = [ordered]@{}
$currentSection = $null

Get-Content $iniPath -Encoding UTF8 | ForEach-Object {
    $line = $_.Trim()
    if ($line -match '^\[(.+)\]$') {
        $currentSection = $matches[1].Trim()
        $sections[$currentSection] = @{}
    }
    elseif ($currentSection -and $line -match '^\s*([^=]+?)\s*=\s*(.+?)\s*$') {
        $key   = $matches[1].Trim()
        $value = $matches[2].Trim()
        $sections[$currentSection][$key] = $value
    }
}

if ($sections.Count -eq 0) {
    Write-Host "ERROR: No devices found in INI" -ForegroundColor Red
    Pause
    exit 1
}

# Group by variant
$grouped = [ordered]@{}

foreach ($dev in $sections.Keys) {
    $v = $sections[$dev]['variant']
    if (-not $v) { $v = "unknown" }

    if (-not $grouped.Contains($v)) {
        $grouped[$v] = New-Object System.Collections.ArrayList
    }
    $null = $grouped[$v].Add($dev)
}

$variantDisplayOrder = @("r36s", "clone", "soysauce")
$sortedVariants = $variantDisplayOrder | Where-Object { $grouped.Contains($_) }
$sortedVariants += ($grouped.Keys | Where-Object { $_ -notin $variantDisplayOrder })

# Two-column menu
Write-Host "`nAvailable devices:" -ForegroundColor Cyan
Write-Host ""

$globalIndex = 1
$deviceList = @{}

foreach ($variant in $sortedVariants) {
    $devicesInGroup = $grouped[$variant]

    if ($devicesInGroup.Count -eq 0) { continue }

    Write-Host "Variant: $variant" -ForegroundColor Magenta
    Write-Host ("-" * 70) -ForegroundColor DarkGray

    $half = [math]::Ceiling($devicesInGroup.Count / 2)
    $left  = $devicesInGroup[0..($half-1)]
    $right = $devicesInGroup[$half..($devicesInGroup.Count-1)]

    for ($row = 0; $row -lt $half; $row++) {
        $leftPart = ""
        $rightPart = ""

        if ($row -lt $left.Count) {
            $num = $globalIndex
            $leftPart = "{0,4}. {1}" -f $num, $left[$row]
            $deviceList[$num] = $left[$row]
            $globalIndex++
        }

        if ($row -lt $right.Count) {
            $num = $globalIndex
            $rightPart = "{0,4}. {1}" -f $num, $right[$row]
            $deviceList[$num] = $right[$row]
            $globalIndex++
        }

        Write-Host ("{0,-40}{1}" -f $leftPart, $rightPart)
    }

    Write-Host ""
}

Write-Host ("=" * 70) -ForegroundColor DarkGray
Write-Host "Total: $($sections.Count) devices" -ForegroundColor Cyan

# Selection
Write-Host "`nSelect number (1-$($sections.Count))" -ForegroundColor Cyan
$rawInput = Read-Host
$selection = $rawInput.Trim()

if ($selection -eq '' -or $selection -notmatch '^\d+$') {
    Write-Host "Please enter a valid number." -ForegroundColor Red
    Pause
    exit 1
}

$selNum = [int]$selection

if ($selNum -lt 1 -or $selNum -gt $sections.Count) {
    Write-Host "Number must be between 1 and $($sections.Count)" -ForegroundColor Red
    Pause
    exit 1
}

$chosen  = $deviceList[$selNum]
$variant = $sections[$chosen]['variant']

if (-not $variant) {
    Write-Host "ERROR: No 'variant' defined for $chosen" -ForegroundColor Red
    Pause
    exit 1
}

Write-Host "`nSelected : $chosen" -ForegroundColor Green
Write-Host "Variant  : $variant" -ForegroundColor Green

# Build path
$sourceFolder = "$rootDir\dtb\$variant\$chosen"

if (-not (Test-Path $sourceFolder -PathType Container)) {
    Write-Host "ERROR: Folder not found: $sourceFolder" -ForegroundColor Red
    Pause
    exit 1
}

Write-Host "`nWill copy files from:" -ForegroundColor Cyan
Write-Host "  $($sourceFolder.Replace('\\','\'))" -ForegroundColor White

# Files to be copied
Write-Host "`nFiles that will be copied from source folder:"
$filesToCopy = @(Get-ChildItem -Path $sourceFolder -File -ErrorAction SilentlyContinue)

if ($filesToCopy.Count -eq 0) {
    Write-Host "  WARNING: No files found in source folder!" -ForegroundColor Yellow
} else {
    $filesToCopy | ForEach-Object { "  $($_.Name)" }
}

# Files in root that will be deleted/overwritten (only .dtb files)
Write-Host "`n.dtbfiles in root that will be deleted/overwritten:"
$existingDtbs = @(Get-ChildItem -Path $rootDir -File -Filter "*.dtb" -ErrorAction SilentlyContinue)

if ($existingDtbs.Count -eq 0) {
    Write-Host "  (none currently present)"
} else {
    $existingDtbs | ForEach-Object { "  $($_.Name)" }
}

Write-Host ""

$confirm = Read-Host "Proceed with copy? (Y/N)"
if ($confirm -notmatch '^[Yy]$') {
    Write-Host "Cancelled." -ForegroundColor Yellow
    Pause
    exit 0
}

# Delete old .dtb files only (no boot.ini)
Write-Host "`nDeleting old .dtb files in root..." -ForegroundColor Yellow

$deleted = @(Get-ChildItem -Path $rootDir -File -Filter "*.dtb" -ErrorAction SilentlyContinue)

if ($deleted.Count -gt 0) {
    $deleted | Remove-Item -Force -ErrorAction SilentlyContinue
    Write-Host "Deleted:"
    $deleted | ForEach-Object { "  $($_.Name)" }
} else {
    Write-Host "  No .dtb files to delete"
}

# Copy new files
Write-Host "`nCopying new files to root..." -ForegroundColor Yellow

$copied = @(Copy-Item -Path "$sourceFolder\*" -Destination $rootDir -Force -PassThru -ErrorAction Stop)

if ($copied.Count -gt 0) {
    Write-Host "Copied:"
    $copied | ForEach-Object { "  $($_.Name)" }
} else {
    Write-Host "  No files were copied (source may be empty)" -ForegroundColor Yellow
}

Write-Host "`n==================================================" -ForegroundColor Green
Write-Host "   SUCCESS - DTB files updated for:"           -ForegroundColor Green
Write-Host "   $chosen"                                     -ForegroundColor White
Write-Host "   Variant: $variant"                           -ForegroundColor White
Write-Host "==================================================`n" -ForegroundColor Green