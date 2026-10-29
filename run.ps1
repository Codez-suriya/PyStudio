#Requires -Version 5.1
<#
.SYNOPSIS
    Launch PyStudio.
.DESCRIPTION
    Starts the PyStudio Flask app via Uvicorn using the project's .venv.
    Asks for a port, then asks how to expose the server:
      1) Have Domain    - bind 0.0.0.0, user supplies the domain name
      2) Expose Locally - bind 127.0.0.1 (this machine only)
      3) Expose to LAN  - bind the detected LAN IP
#>

[CmdletBinding()]
param(
    [int]$Port,
    [string]$Domain,
    [string]$BindHost,
    [ValidateSet('Domain','Local','Lan','')]
    [string]$Mode,
    [switch]$NonInteractive
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------- colors ----------
$esc     = [char]27
$useAnsi = -not $env:NO_COLOR -and -not [Console]::IsOutputRedirected
$C_RESET = if ($useAnsi) { "$esc[0m" } else { '' }
$C_BOLD  = if ($useAnsi) { "$esc[1m" } else { '' }
$C_AMBER = if ($useAnsi) { "$esc[38;5;214m" } else { '' }
$C_GOLD  = if ($useAnsi) { "$esc[38;5;220m" } else { '' }
$C_EMBER = if ($useAnsi) { "$esc[38;5;166m" } else { '' }
$C_WHITE = if ($useAnsi) { "$esc[38;5;255m" } else { '' }
$C_CREAM = if ($useAnsi) { "$esc[38;5;253m" } else { '' }
$C_DIM   = if ($useAnsi) { "$esc[2m" }     else { '' }

$glyphCheck = [string][char]0x2713
$glyphCross = [string][char]0x2717

function Write-Ok   { param([string]$m) Write-Host ("  {0}[{1}]{2} {3}{4}{2}" -f "$($C_BOLD)$($C_GOLD)",  $glyphCheck, $C_RESET, $C_WHITE, $m) }
function Write-Err  { param([string]$m) [Console]::Error.WriteLine(("  {0}[{1}]{2} {3}{4}{2}" -f "$($C_BOLD)$($C_EMBER)", $glyphCross, $C_RESET, $C_WHITE, $m)) }
function Write-Step { param([string]$m) Write-Host ("  {0}[*]{1} {2}{3}{2}" -f "$($C_BOLD)$($C_AMBER)", $C_RESET, $C_WHITE, $m) }
function Write-Note { param([string]$m) Write-Host ("  {0}{1}{2}" -f $C_CREAM, $m, $C_RESET) }

# ---------- helpers ----------
function Get-LanIp {
    try {
        $ips = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop |
               Where-Object {
                   $_.IPAddress -notlike '127.*' -and
                   $_.IPAddress -notlike '169.254.*' -and
                   $_.PrefixOrigin -ne 'WellKnown'
               } |
               Sort-Object InterfaceMetric |
               Select-Object -ExpandProperty IPAddress -First 1
        if ($ips) { return $ips }
    } catch {
        try {
            $ip = [System.Net.Dns]::GetHostAddresses([System.Net.Dns]::GetHostName()) |
                  Where-Object { $_.AddressFamily -eq 'InterNetwork' -and -not [System.Net.IPAddress]::IsLoopback($_) } |
                  Select-Object -First 1
            if ($ip) { return $ip.ToString() }
        } catch { }
    }
    return '127.0.0.1'
}

function Test-ValidPort {
    param([string]$Value)
    if ($Value -notmatch '^\d+$') { return $false }
    $n = [int]$Value
    return ($n -ge 1 -and $n -le 65535)
}

# ---------- resolve project dir ----------
$projectDir = $PSScriptRoot
if (-not $projectDir) { $projectDir = (Get-Location).Path }

$appPy = Join-Path $projectDir 'app.py'
if (-not (Test-Path $appPy)) {
    Write-Err "app.py not found in $projectDir. Run install.ps1 first."
    exit 1
}

$venvPython = Join-Path $projectDir '.venv\Scripts\python.exe'
if (-not (Test-Path $venvPython)) {
    Write-Err "Virtual environment missing at $venvPython. Run install.ps1 first."
    exit 1
}

Write-Host ''
Write-Host ("  {0}PyStudio launcher{1}" -f "$($C_BOLD)$($C_AMBER)", $C_RESET)
Write-Host ''

# ---------- interactive prompts ----------
$interactive = -not $NonInteractive -and -not [Console]::IsInputRedirected

if ($interactive) {
    # Port
    if (-not $PSBoundParameters.ContainsKey('Port')) {
        Write-Host ("  {0}Port{1} {2}[default 8000]{1}: " -f `
            "$($C_BOLD)$($C_WHITE)", $C_RESET, $C_CREAM) -NoNewline
        $portInput = Read-Host
        if ([string]::IsNullOrWhiteSpace($portInput)) {
            $Port = 8000
        } elseif (Test-ValidPort $portInput) {
            $Port = [int]$portInput
        } else {
            Write-Err "Invalid port '$portInput'. Using 8000."
            $Port = 8000
        }
    }

    # Exposure mode
    if (-not $Mode) {
        Write-Host ''
        Write-Host ("  {0}How should PyStudio be exposed?{1}" -f "$($C_BOLD)$($C_WHITE)", $C_RESET)
        Write-Host ("    {0}1){1} Have Domain      {2}(bind 0.0.0.0, enter domain name){1}" -f $C_AMBER, $C_RESET, $C_CREAM)
        Write-Host ("    {0}2){1} Expose Locally   {2}(bind 127.0.0.1, this machine only){1}" -f $C_AMBER, $C_RESET, $C_CREAM)
        Write-Host ("    {0}3){1} Expose to LAN    {2}(bind detected LAN IP){1}" -f $C_AMBER, $C_RESET, $C_CREAM)
        Write-Host ("  {0}Select [1/2/3, default 3]{1}: " -f "$($C_BOLD)$($C_WHITE)", $C_RESET) -NoNewline
        $modeInput = Read-Host
        switch ($modeInput.Trim()) {
            '1' { $Mode = 'Domain' }
            '2' { $Mode = 'Local' }
            '3' { $Mode = 'Lan' }
            ''  { $Mode = 'Lan' }
            default {
                Write-Err "Invalid choice '$modeInput'. Using LAN."
                $Mode = 'Lan'
            }
        }
    }

    # Domain name (only for mode 1)
    if ($Mode -eq 'Domain' -and -not $Domain) {
        Write-Host ("  {0}Domain name{1} {2}(e.g. myapp.local){1}: " -f `
            "$($C_BOLD)$($C_WHITE)", $C_RESET, $C_CREAM) -NoNewline
        $domainInput = Read-Host
        if ([string]::IsNullOrWhiteSpace($domainInput)) {
            Write-Err "No domain entered. Falling back to LAN mode."
            $Mode = 'Lan'
        } else {
            $Domain = $domainInput.Trim()
        }
    }
}

if (-not $Port) { $Port = 8000 }
if (-not (Test-ValidPort "$Port")) { $Port = 8000 }
if (-not $Mode) { $Mode = 'Lan' }

# ---------- decide bind host ----------
$lanIp = Get-LanIp

if ($BindHost) {
    # Explicit override wins
} elseif ($Mode -eq 'Domain') {
    $BindHost = '0.0.0.0'
} elseif ($Mode -eq 'Local') {
    $BindHost = '127.0.0.1'
} else {
    $BindHost = $lanIp
}

# ---------- build display URL ----------
if ($Mode -eq 'Domain' -and $Domain) {
    $displayUrl = "http://${Domain}:$Port"
    $localUrl   = "http://${lanIp}:$Port"
} elseif ($Mode -eq 'Local') {
    $displayUrl = "http://127.0.0.1:$Port"
    $localUrl   = $displayUrl
} else {
    $displayUrl = "http://${BindHost}:$Port"
    $localUrl   = $displayUrl
}

# ---------- summary ----------
Write-Host ''
Write-Step "Starting PyStudio from $projectDir"
Write-Step "Mode      : $Mode"
Write-Step "Bind host : $BindHost"
Write-Step "Port      : $Port"
Write-Step "URL       : $displayUrl"
switch ($Mode) {
    'Domain' {
        Write-Note "If '$Domain' does not resolve, add it to your hosts file or DNS."
        Write-Note "Direct LAN URL: $localUrl"
    }
    'Local' {
        Write-Note "Accessible only from this machine."
    }
    default {
        Write-Note "Reachable on your LAN at $localUrl"
    }
}
Write-Host ''

# ---------- launch ----------
Push-Location $projectDir
try {
    & $venvPython -m uvicorn 'app:asgi_app' --host $BindHost --port $Port
} catch {
    Write-Err "Failed to start PyStudio: $_"
    exit 1
} finally {
    Pop-Location
}
