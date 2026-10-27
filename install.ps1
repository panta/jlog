# Installs the latest jlog release for Windows, verifying its SHA-256 checksum.
# Usage: irm https://jlog.logging.work/install.ps1 | iex
#        & ([scriptblock]::Create((irm https://jlog.logging.work/install.ps1))) -Minimal -NoPath -Completions
#   -Minimal      the minimal build (no jlog send/receive, no network connections)
#   -NoPath       do not add the install directory to the user PATH
#   -Completions  load tab completion from the PowerShell profile
# Environment: JLOG_INSTALL_DIR (default %LOCALAPPDATA%\Programs\jlog), JLOG_MINIMAL=1.
param([switch]$Minimal, [switch]$NoPath, [switch]$Completions)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue' # the progress bar makes downloads much slower
# Windows PowerShell 5.1 may default to TLS 1.0/1.1.
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$base = if ($env:JLOG_BASE_URL) { $env:JLOG_BASE_URL } else { 'https://jlog.logging.work' }
$dest = if ($env:JLOG_INSTALL_DIR) { $env:JLOG_INSTALL_DIR } else { Join-Path $env:LOCALAPPDATA 'Programs\jlog' }
if ($env:JLOG_MINIMAL) { $Minimal = $true }
$prefix = if ($Minimal) { 'jlog-minimal' } else { 'jlog' }

function Get-Text([string]$Url) {
    $r = Invoke-WebRequest -UseBasicParsing $Url
    if ($r.Content -is [byte[]]) { [Text.Encoding]::UTF8.GetString($r.Content) } else { [string]$r.Content }
}

if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') {
    Write-Host 'jlog: no ARM64 build yet; installing the x86_64 build (runs under emulation)'
}
$version = (Get-Text "$base/latest/VERSION").Trim()
$name = "$prefix-$version-x86_64-pc-windows-msvc"
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('jlog-' + [guid]::NewGuid())
New-Item -ItemType Directory $tmp | Out-Null
try {
    Write-Host "jlog: downloading $name.zip"
    Invoke-WebRequest -UseBasicParsing "$base/latest/$name.zip" -OutFile "$tmp\$name.zip"
    $sums = Get-Text "$base/latest/SHA256SUMS"
    $line = ($sums -split "`r?`n") | Where-Object { $_.EndsWith(" $name.zip") } | Select-Object -First 1
    $expected = if ($line) { ($line -split '\s+')[0].ToLower() } else { '' }
    $actual = (Get-FileHash "$tmp\$name.zip" -Algorithm SHA256).Hash.ToLower()
    if (-not $expected -or $expected -ne $actual) {
        throw "jlog: checksum mismatch for $name.zip; not installing"
    }
    Expand-Archive "$tmp\$name.zip" $tmp
    New-Item -ItemType Directory -Force $dest | Out-Null
    Copy-Item "$tmp\$name\*" $dest -Recurse -Force
    Write-Host "jlog: installed $version to $dest\jlog.exe"

    if (-not $NoPath) {
        $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
        $parts = @(if ($userPath) { $userPath -split ';' | Where-Object { $_ } })
        if ($parts -notcontains $dest) {
            [Environment]::SetEnvironmentVariable('Path', (@($parts) + $dest) -join ';', 'User')
            $env:Path = "$env:Path;$dest"
            Write-Host "jlog: added $dest to your user PATH (new terminals pick it up)"
        }
    }

    $load = ". '$dest\completions\jlog.ps1'"
    if ($Completions) {
        $profilePath = $PROFILE.CurrentUserAllHosts
        New-Item -ItemType Directory -Force (Split-Path $profilePath) | Out-Null
        $current = if (Test-Path $profilePath) { Get-Content -Raw $profilePath } else { '' }
        if ($current -notlike "*$load*") {
            Add-Content $profilePath "`n# jlog tab completion`n$load"
            Write-Host "jlog: tab completion added to $profilePath"
        }
    } else {
        Write-Host "jlog: for tab completion, add this line to your profile (`$PROFILE): $load"
    }
} finally {
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}
