#Requires -Version 5.1
<#
.SYNOPSIS
    PyStudio Installer for Windows
.DESCRIPTION
    Installs PyStudio into the current working directory by default.
    Expects run.bat for one-command launch.
.NOTES
    Save as UTF-8 WITH BOM. The script also builds all non-ASCII glyphs from
    code points at runtime, so it survives re-saving without a BOM.
#>

[CmdletBinding()]
param(
    [string]$InstallDir = (Get-Location).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ============================================================
#  GLYPHS BUILT AT RUNTIME (immune to file-encoding corruption)
# ============================================================
$script:Block      = [string][char]0x2588   # block
$script:GlyphCheck = [string][char]0x2713   # check
$script:GlyphCross = [string][char]0x2717   # cross
$script:BoxTL      = [string][char]0x256D   # top-left corner
$script:BoxTR      = [string][char]0x256E   # top-right corner
$script:BoxBL      = [string][char]0x2570   # bottom-left corner
$script:BoxBR      = [string][char]0x256F   # bottom-right corner
$script:BoxH       = [string][char]0x2500   # horizontal bar
$script:BoxV       = [string][char]0x2502   # vertical bar

# ============================================================
#  ANSI COLOR ENGINE
# ============================================================
$script:Esc = [char]27

function Test-AnsiSupport {
    if ($env:NO_COLOR) { return $false }
    if ([Console]::IsOutputRedirected) { return $false }
    try {
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            return $Host.UI.SupportsVirtualTerminal
        }
        if ($env:TERM -eq 'dumb') { return $false }
        return $true
    } catch {
        return $false
    }
}

$script:UseAnsi = Test-AnsiSupport

function New-Ansi {
    param([string]$Code)
    if (-not $script:UseAnsi) { return '' }
    return "$($script:Esc)[$($Code)m"
}

$script:C_RESET        = New-Ansi '0'
$script:C_BOLD         = New-Ansi '1'
$script:C_DIM          = New-Ansi '2'
$script:C_EMBER        = New-Ansi '38;5;166'
$script:C_ORANGE       = New-Ansi '38;5;208'
$script:C_AMBER        = New-Ansi '38;5;214'
$script:C_GOLD         = New-Ansi '38;5;220'
$script:C_WARM         = New-Ansi '38;5;178'
$script:C_BRIGHT_WHITE = New-Ansi '1;38;5;231'
$script:C_WHITE        = New-Ansi '38;5;255'
$script:C_CREAM        = New-Ansi '38;5;253'
$script:C_DIM_ORANGE   = New-Ansi '38;5;130'

# ============================================================
#  LOGGING
# ============================================================
$script:LogFile   = Join-Path ([System.IO.Path]::GetTempPath()) ("pystudio-install.{0}.log" -f [guid]::NewGuid().ToString('N'))
$script:LogStream = $null

function Write-Log {
    param([string]$Message)
    if (-not $script:LogStream) {
        $script:LogStream = [System.IO.File]::CreateText($script:LogFile)
    }
    $script:LogStream.WriteLine(("{0:yyyy-MM-dd HH:mm:ss} {1}" -f (Get-Date), $Message))
    $script:LogStream.Flush()
}

function Close-Log {
    if ($script:LogStream) {
        $script:LogStream.Dispose()
        $script:LogStream = $null
    }
}

# ============================================================
#  BANNER — glyphs built from $script:Block
# ============================================================
function Show-Banner {
    $B = $script:Block
    $O = "$($script:C_BOLD)$($script:C_AMBER)"
    $W = "$($script:C_BOLD)$($script:C_BRIGHT_WHITE)"
    $R = $script:C_RESET

    # P  Y  S  T  U  D  I  O
    $rows = @(
        @("$B$B$B$B ", "$B   $B", " $B$B$B$B", "$B$B$B$B$B", "$B   $B", "$B$B$B$B ", "$B$B$B$B$B", " $B$B$B "),
        @("$B   $B", "$B   $B", "$B    ", "  $B  ", "$B   $B", "$B   $B", "  $B  ", "$B   $B"),
        @("$B$B$B$B ", " $B$B$B ", " $B$B$B ", "  $B  ", "$B   $B", "$B   $B", "  $B  ", "$B   $B"),
        @("$B    ", "  $B  ", "    $B", "  $B  ", "$B   $B", "$B   $B", "  $B  ", "$B   $B"),
        @("$B    ", "  $B  ", "$B$B$B$B ", "  $B  ", "$B$B$B$B$B", "$B$B$B$B ", "$B$B$B$B$B", " $B$B$B ")
    )

    Write-Host ''
    foreach ($row in $rows) {
        $parts = @()
        for ($i = 0; $i -lt $row.Count; $i++) {
            $color = if ($i % 2 -eq 0) { $O } else { $W }
            $parts += "$color$($row[$i])$R"
        }
        Write-Host ("  " + ($parts -join ' '))
    }
    Write-Host ''
}

# ============================================================
#  STATUS HELPERS
# ============================================================
function Write-Info {
    param([string]$Message)
    Write-Host ("  {0}[*]{1} {2}{3}{1}" -f "$($script:C_BOLD)$($script:C_ORANGE)", $script:C_RESET, $script:C_WHITE, $Message)
}

function Write-Ok {
    param([string]$Message)
    Write-Host ("  {0}[{1}]{2} {3}{4}{2}" -f "$($script:C_BOLD)$($script:C_GOLD)", $script:GlyphCheck, $script:C_RESET, $script:C_WHITE, $Message)
}

function Write-Warn {
    param([string]$Message)
    Write-Host ("  {0}[!]{1} {2}{3}{1}" -f "$($script:C_BOLD)$($script:C_AMBER)", $script:C_RESET, $script:C_CREAM, $Message)
}

function Write-Fail {
    param([string]$Message)
    [Console]::Error.WriteLine(("  {0}[{1}]{2} {3}{4}{2}" -f "$($script:C_BOLD)$($script:C_EMBER)", $script:GlyphCross, $script:C_RESET, $script:C_CREAM, $Message))
}

function Write-SectionHeader {
    param([string]$Title, [string]$Accent = $script:C_AMBER)
    $width = 40
    Write-Host ''
    Write-Host ("{0}========================================{1}" -f $Accent, $script:C_RESET)
    if ($Title.Length -ge $width) {
        Write-Host ("{0}{1}{2}" -f "$($script:C_BOLD)$($script:C_BRIGHT_WHITE)", $Title, $script:C_RESET)
    } else {
        $totalPad = $width - $Title.Length
        $padLeft  = [int][math]::Floor($totalPad / 2)
        $padRight = $totalPad - $padLeft
        Write-Host ("{0}{1}{2}{3}{4}" -f (' ' * $padLeft), "$($script:C_BOLD)$($script:C_BRIGHT_WHITE)", $Title, $script:C_RESET, (' ' * $padRight))
    }
    Write-Host ("{0}========================================{1}" -f $Accent, $script:C_RESET)
    Write-Host ''
}

function Stop-Install {
    param([string]$Message)
    Write-Fail $Message
    Write-Log "FATAL: $Message"
    if (Test-Path $script:LogFile) {
        Write-Host ''
        Write-Host ("  {0}Log file:{1} {2}{3}{1}" -f $script:C_DIM, $script:C_RESET, "$($script:C_BOLD)$($script:C_AMBER)", $script:LogFile)
        Write-Host ("  {0}Last 30 lines:{1}" -f $script:C_DIM, $script:C_RESET)
        Get-Content $script:LogFile -Tail 30 | ForEach-Object {
            Write-Host ("    {0}{1}{2}" -f $script:C_CREAM, $_, $script:C_RESET)
        }
    }
    Close-Log
    exit 1
}

# ============================================================
#  PROJECT DETECTION
# ============================================================
function Test-ProjectDir {
    param([string]$Path)
    return (Test-Path (Join-Path $Path 'app.py')) -and (Test-Path (Join-Path $Path 'requirements.txt'))
}

# ============================================================
#  DOWNLOAD & EXTRACT
# ============================================================
function Get-RepositoryZip {
    param([string]$Destination)
    $zipUrl  = 'https://github.com/Codez-suriya/PyStudio/archive/refs/heads/main.zip'
    $zipPath = Join-Path ([System.IO.Path]::GetTempPath()) ("pystudio-{0}.zip" -f [guid]::NewGuid().ToString('N'))

    Write-Info "Downloading PyStudio from GitHub..."
    Write-Log "Download URL: $zipUrl"

    try {
        if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
            & curl.exe -L --fail --silent --show-error -o $zipPath $zipUrl 2>&1 | ForEach-Object { Write-Log $_ }
            if ($LASTEXITCODE -ne 0) { throw "curl.exe failed with exit code $LASTEXITCODE" }
        } else {
            Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
        }
    } catch {
        Write-Log "Download failed: $_"
        Stop-Install "Could not download the repository ZIP. Check your network connection."
    }

    Write-Ok "Repository ZIP downloaded."

    Write-Info "Extracting..."
    $extractDir = Join-Path ([System.IO.Path]::GetTempPath()) ("pystudio-extract-{0}" -f [guid]::NewGuid().ToString('N'))
    try {
        Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force
    } catch {
        Write-Log "Extraction failed: $_"
        Stop-Install "Could not extract the repository ZIP."
    } finally {
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
    }

    $candidates  = @(Get-ChildItem -Path $extractDir -Directory)
    $projectRoot = $null
    foreach ($c in $candidates) {
        if (Test-ProjectDir $c.FullName) { $projectRoot = $c.FullName; break }
    }
    if (-not $projectRoot) {
        if (Test-ProjectDir $extractDir) { $projectRoot = $extractDir }
        else { Stop-Install "Could not locate a valid PyStudio project (app.py + requirements.txt) in the extracted archive." }
    }

    if (-not (Test-Path $Destination)) {
        New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    }

    Write-Info "Copying project files (overwriting conflicts)..."
    
    # Copy the repo files. -Force ensures that if a file (like app.py) 
    # or folder (like static/) already exists, it gets overwritten.
    $repoItems = Get-ChildItem -Path $projectRoot -Force
    foreach ($item in $repoItems) {
        $targetPath = Join-Path $Destination $item.Name
        if ($item.PSIsContainer) {
            # It's a directory (e.g., static, templates)
            if (Test-Path $targetPath) {
                Write-Host "  -> Updating folder: $($item.Name)" -ForegroundColor DarkGray
            }
            Copy-Item -Path $item.FullName -Destination $Destination -Recurse -Force
        } else {
            # It's a file (e.g., app.py, requirements.txt)
            if (Test-Path $targetPath) {
                Write-Host "  -> Overwriting file: $($item.Name)" -ForegroundColor DarkGray
            }
            Copy-Item -Path $item.FullName -Destination $Destination -Force
        }
    }

    Remove-Item $extractDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Ok "Repository extracted to $Destination."
}

# ============================================================
#  PYTHON DISCOVERY
# ============================================================
function Get-PythonVersionString {
    param(
        [string]$Exe,
        [string[]]$PrefixArgs = @()
    )
    $payload = 'import sys;print(sys.version_info[0],sys.version_info[1])'
    try {
        $args = @()
        if ($PrefixArgs) { $args += $PrefixArgs }
        $args += @('-c', $payload)
        $raw = & $Exe @args 2>&1 | Out-String
        $raw = $raw.Trim()
        if ($raw -match '^(\d+)\s+(\d+)$') {
            return @{ Major = [int]$Matches[1]; Minor = [int]$Matches[2]; Raw = $raw }
        }
        Write-Log ("Version probe for {0} returned unexpected output: {1}" -f $Exe, $raw)
        return $null
    } catch {
        Write-Log ("Version probe for {0} threw: {1}" -f $Exe, $_)
        return $null
    }
}

function Find-Python {
    param([int]$MinMajor = 3, [int]$MinMinor = 8)
    $candidates = @()

    # 1. py.exe launcher
    $py = Get-Command py.exe -ErrorAction SilentlyContinue
    if ($py) {
        $v = Get-PythonVersionString -Exe 'py.exe' -PrefixArgs @('-3')
        if ($v -and ($v.Major -gt $MinMajor -or ($v.Major -eq $MinMajor -and $v.Minor -ge $MinMinor))) {
            $candidates += @{ Path = 'py.exe'; Args = @('-3'); Version = ("{0}.{1}" -f $v.Major, $v.Minor) }
        }
    }

    # 2. python.exe / python3.exe on PATH (skip the Store stub in WindowsApps)
    foreach ($name in @('python.exe', 'python3.exe')) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if (-not $cmd) { continue }
        if ($cmd.Source -and $cmd.Source -like '*\WindowsApps\*') { continue }
        $v = Get-PythonVersionString -Exe $cmd.Source
        if ($v -and ($v.Major -gt $MinMajor -or ($v.Major -eq $MinMajor -and $v.Minor -ge $MinMinor))) {
            $candidates += @{ Path = $cmd.Source; Args = @(); Version = ("{0}.{1}" -f $v.Major, $v.Minor) }
        }
    }

    # 3. Common install locations
    $commonPaths = @(
        "$env:LOCALAPPDATA\Programs\Python\Python313\python.exe",
        "$env:LOCALAPPDATA\Programs\Python\Python312\python.exe",
        "$env:LOCALAPPDATA\Programs\Python\Python311\python.exe",
        "$env:LOCALAPPDATA\Programs\Python\Python310\python.exe",
        "$env:LOCALAPPDATA\Programs\Python\Python39\python.exe",
        "$env:ProgramFiles\Python313\python.exe",
        "$env:ProgramFiles\Python312\python.exe",
        "$env:ProgramFiles\Python311\python.exe",
        "$env:ProgramFiles\Python310\python.exe"
    )
    foreach ($p in $commonPaths) {
        if (-not (Test-Path $p)) { continue }
        $v = Get-PythonVersionString -Exe $p
        if ($v -and ($v.Major -gt $MinMajor -or ($v.Major -eq $MinMajor -and $v.Minor -ge $MinMinor))) {
            $candidates += @{ Path = $p; Args = @(); Version = ("{0}.{1}" -f $v.Major, $v.Minor) }
        }
    }

    if ($candidates.Count -eq 0) { return $null }
    return $candidates | Sort-Object { [version]$_.Version } -Descending | Select-Object -First 1
}

function Install-PythonViaWinget {
    Write-Info "Python 3.8+ is required but was not found."
    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if (-not $winget) {
        Stop-Install "Python is missing and winget is unavailable. Install Python 3.8+ from https://python.org and re-run this installer."
    }

    $answer = Read-Host "Install Python 3.12 via winget? [Y/n]"
    if ($answer -match '^[Nn]') {
        Stop-Install "Python installation skipped by user. Install Python 3.8+ and re-run."
    }

    Write-Info "Installing Python 3.12 via winget..."
    & winget install --id Python.Python.3.12 --source winget --accept-package-agreements --accept-source-agreements 2>&1 | ForEach-Object { Write-Log $_ }
    $exit = $LASTEXITCODE

    if ($exit -ne 0 -and $exit -ne -1978335189 -and $exit -ne -1978335226) {
        Stop-Install "winget Python installation failed (exit code $exit)."
    }
    Write-Ok "Python available via winget (or already installed)."
}

# ============================================================
#  MAIN
# ============================================================
try {
    Write-Log "PyStudio Windows installer started."

    $scriptDir = $PSScriptRoot
    if (Test-ProjectDir $scriptDir) {
        $projectDir = $scriptDir; $reuseExisting = $true
    } elseif (Test-ProjectDir $InstallDir) {
        $projectDir = $InstallDir; $reuseExisting = $true
    } else {
        $projectDir = $InstallDir; $reuseExisting = $false
    }

    Show-Banner
    Write-SectionHeader 'PyStudio Installer' $script:C_AMBER

    Write-Host ("  {0}[*]{1} {2}Project directory{3} {4}{5}{3}" -f `
        "$($script:C_BOLD)$($script:C_ORANGE)", $script:C_RESET, `
        $script:C_DIM_ORANGE, $script:C_RESET, `
        "$($script:C_BOLD)$($script:C_GOLD)", $projectDir)

    Write-SectionHeader 'PYTHON ENVIRONMENT' $script:C_AMBER

    $python = Find-Python -MinMajor 3 -MinMinor 8
    if (-not $python) {
        Install-PythonViaWinget
        $python = Find-Python -MinMajor 3 -MinMinor 8
        if (-not $python) {
            Stop-Install "Python 3.8+ still not found after installation attempt. Restart your terminal and re-run."
        }
    }
    Write-Ok "Python $($python.Version) detected at $($python.Path)."
    Write-Log "Python: $($python.Path) $($python.Args -join ' ') version $($python.Version)"

    if (-not $reuseExisting) {
        if (Test-Path $projectDir) {
            $ignoredNames = @('install.ps1', 'run.bat', 'run.log', 'install.py', 'README.md', '.gitignore')
            $items = @(
                Get-ChildItem $projectDir -Force -ErrorAction SilentlyContinue |
                Where-Object { $ignoredNames -notcontains $_.Name -and $_.Name -notlike '*.log' }
            )
            if ($items.Count -gt 0) {
                Stop-Install "Destination exists but is not a valid PyStudio project: $projectDir. Remove unrelated files or choose another directory."
            }
        }
        Get-RepositoryZip -Destination $projectDir
    } else {
        Write-Ok 'Existing PyStudio project detected; reusing.'
    }

    if (-not (Test-ProjectDir $projectDir)) {
        Stop-Install "Project validation failed: app.py or requirements.txt is missing in $projectDir."
    }

    Write-Host ("  {0}[{1}]{2} {3}Working directory{2} {4}{5}{2}" -f `
        "$($script:C_BOLD)$($script:C_GOLD)", $script:GlyphCheck, $script:C_RESET, `
        $script:C_DIM_ORANGE, `
        "$($script:C_BOLD)$($script:C_AMBER)", $projectDir)

    $venvDir    = Join-Path $projectDir '.venv'
    $venvPython = Join-Path $venvDir 'Scripts\python.exe'

    if (Test-Path $venvPython) {
        $v = Get-PythonVersionString -Exe $venvPython
        if ($v -and ($v.Major -gt 3 -or ($v.Major -eq 3 -and $v.Minor -ge 8))) {
            Write-Ok 'Reusing existing virtual environment.'
        } else {
            Write-Warn 'Existing virtual environment is incompatible; recreating.'
            Remove-Item $venvDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    if (-not (Test-Path $venvPython)) {
        Write-Info 'Creating virtual environment...'
        $pyArgs = @()
        if ($python.Args) { $pyArgs += $python.Args }
        $pyArgs += @('-m', 'venv', $venvDir)
        & $python.Path @pyArgs 2>&1 | ForEach-Object { Write-Log $_ }
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path $venvPython)) {
            Stop-Install 'Virtual environment creation failed.'
        }
        Write-Ok 'Virtual environment created.'
    }

    if (-not (Test-Path $venvPython)) {
        Stop-Install 'Virtual environment Python not found after creation.'
    }

    Write-SectionHeader 'DEPENDENCIES' $script:C_GOLD

    Write-Info 'Upgrading pip...'
    & $venvPython -m pip install --upgrade pip 2>&1 | ForEach-Object { Write-Log $_ }
    if ($LASTEXITCODE -ne 0) { Stop-Install 'pip upgrade failed.' }

    $requirements = Join-Path $projectDir 'requirements.txt'
    Write-Info 'Installing requirements...'
    & $venvPython -m pip install -r $requirements 2>&1 | ForEach-Object { Write-Log $_ }
    if ($LASTEXITCODE -ne 0) { Stop-Install 'Dependency installation failed. See log for details.' }
    Write-Ok 'Dependencies installed.'

    & $venvPython -c 'import flask,uvicorn,asgiref' 2>&1 | ForEach-Object { Write-Log $_ }
    if ($LASTEXITCODE -ne 0) {
        Stop-Install 'Essential imports failed (flask/uvicorn/asgiref). Check requirements.txt.'
    }
    Write-Ok 'Flask, Uvicorn, and ASGI bridge verified.'

    Write-SectionHeader 'LAUNCHER' $script:C_WARM

    $runSh = Join-Path $projectDir 'run.sh'
    if (-not (Test-Path $runSh)) {
        Write-Warn 'run.sh is missing. run.bat will still start the app.'
    } else {
        Write-Ok 'run.sh is present.'
        $runContent = Get-Content $runSh -Raw
        if ($runContent -match 'app:asgi_app') {
            Write-Ok 'run.sh targets app:asgi_app via Uvicorn.'
        } else {
            Write-Warn 'run.sh does not explicitly reference app:asgi_app. Verify manually.'
        }
    }

    $runBat = Join-Path $projectDir 'run.bat'
    if (Test-Path $runBat) {
        Write-Ok 'run.bat is ready.'
    } else {
        Write-Warn 'run.bat is missing from the project files!'
    }

    Write-SectionHeader 'INSTALLATION COMPLETE' $script:C_GOLD

    $pyVersionOut = & $venvPython --version 2>&1
    Write-Host ("  {0}Project directory{1}   {2}{3}{1}" -f $script:C_DIM_ORANGE, $script:C_RESET, "$($script:C_BOLD)$($script:C_GOLD)", $projectDir)
    Write-Host ("  {0}Python runtime{1}      {2}{3}{1}" -f $script:C_DIM_ORANGE, $script:C_RESET, "$($script:C_BOLD)$($script:C_AMBER)", $pyVersionOut)
    Write-Host ("  {0}Virtualenv{1}          {2}{3}{1}" -f $script:C_DIM_ORANGE, $script:C_RESET, $script:C_ORANGE, $venvDir)
    Write-Host ("  {0}Dependencies{1}        {2}Flask / Uvicorn / asgiref{1}" -f $script:C_DIM_ORANGE, $script:C_RESET, $script:C_WARM)

    Write-Host ''
    Write-Host ("  {0}Start PyStudio{1}" -f "$($script:C_BOLD)$($script:C_BRIGHT_WHITE)", $script:C_RESET)
    Write-Host ''
    Write-Host ("    {0}>{1} {2} By double clicking run.bat{3}" -f `
        $script:C_AMBER, $script:C_RESET, "$($script:C_BOLD)$($script:C_GOLD)", $script:C_RESET)
    Write-Host ''

    $innerWidth = 46
    $bar        = $script:BoxH * $innerWidth
    $message    = "  $($script:GlyphCheck)  PyStudio is ready to launch!  "
    $leftPad    = [int][math]::Floor(($innerWidth - $message.Length) / 2)
    $rightPad   = $innerWidth - $message.Length - $leftPad
    $cardLine   = "$(' ' * $leftPad)$message$(' ' * $rightPad)"

    Write-Host ("  {0}{1}{2}{3}{4}" -f $script:C_GOLD, $script:BoxTL, $bar, $script:BoxTR, $script:C_RESET)
    Write-Host ("  {0}{1}{2}{3}{4}{5}{6}" -f `
        $script:C_GOLD, $script:BoxV, $script:C_RESET, `
        "$($script:C_BOLD)$($script:C_GOLD)", $cardLine, `
        $script:C_GOLD, "$($script:BoxV)$($script:C_RESET)")
    Write-Host ("  {0}{1}{2}{3}{4}" -f $script:C_GOLD, $script:BoxBL, $bar, $script:BoxBR, $script:C_RESET)
    Write-Host ''

    Write-Ok 'Installation finished successfully.'

    Write-Host ''
    Write-Host ("  {0}Launch PyStudio now?{1} {2}[Y/n]{1} " -f `
        "$($script:C_BOLD)$($script:C_AMBER)", $script:C_RESET, $script:C_BRIGHT_WHITE) -NoNewline

    $launchChoice = 'n'
    if (-not [Console]::IsInputRedirected) { $launchChoice = Read-Host }
    else { Write-Host 'n' }

    if ($launchChoice -match '^[Yy]') {
        Write-Host ''
        Write-Host ("  {0}Launching PyStudio...{1}" -f "$($script:C_BOLD)$($script:C_AMBER)", $script:C_RESET)
        Write-Host ''
        if (Test-Path $runBat) {
            & cmd.exe /c $runBat
        } else {
            Push-Location $projectDir
            try { & $venvPython -m uvicorn 'app:asgi_app' }
            finally { Pop-Location }
        }
    } else {
        Write-Host ''
        Write-Host ("  {0}PyStudio is installed and ready whenever you are.{1}" -f $script:C_BRIGHT_WHITE, $script:C_RESET)
        Write-Host ("  {0}Run it by double-clicking:{1} run.bat" -f $script:C_AMBER, $script:C_RESET)
        Write-Host ''
    }

} catch {
    Write-Log "UNHANDLED: $_"
    Stop-Install "An unexpected error occurred: $_"
} finally {
    Close-Log
    if (Test-Path $script:LogFile) {
        Remove-Item $script:LogFile -Force -ErrorAction SilentlyContinue
    }
}
