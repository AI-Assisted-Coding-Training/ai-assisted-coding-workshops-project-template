# Windows PowerShell 5.1+; installs only the pinned repository-local scanner.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$stage = $null
$originalOutputEncoding = $null
Push-Location $root
try {
    if ($env:OS -ne 'Windows_NT') {
        throw 'On macOS/Linux use sh tools/setup-git-hooks.sh.'
    }
    # Git emits UTF-8 paths, including default-hook paths in linked worktrees.
    # Scope decoding to this script instead of relying on the console code page.
    $originalOutputEncoding = [Console]::OutputEncoding
    [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
    Get-Command git -ErrorAction Stop | Out-Null
    $prefix = & git rev-parse --show-prefix
    if ($LASTEXITCODE -ne 0 -or $prefix) {
        throw 'Run setup from this repository.'
    }
    $current = & git config --get core.hooksPath
    if ($LASTEXITCODE -notin @(0, 1)) {
        throw 'Could not read core.hooksPath.'
    }
    if ($current -and $current -ne '.githooks') {
        throw "core.hooksPath is already '$current'; resolve the conflict before setup."
    }
    if (-not $current) {
        $defaultHooks = & git rev-parse --git-path hooks
        if ($LASTEXITCODE -ne 0) { throw 'Could not locate the default hooks directory.' }
        if (Test-Path -LiteralPath $defaultHooks -PathType Container) {
            # Git for Windows does not require the Unix executable bit. Treat
            # every non-sample file conservatively as a possible existing hook.
            $existingHooks = @(Get-ChildItem -LiteralPath $defaultHooks -File -Force |
                Where-Object { $_.Name -notlike '*.sample' })
            if ($existingHooks.Count -gt 0) {
                throw "Existing file in default hooks directory: $($existingHooks[0].FullName); reconcile existing hooks before setup."
            }
        }
    }

    $nativeArch = $env:PROCESSOR_ARCHITEW6432
    if (-not $nativeArch) { $nativeArch = $env:PROCESSOR_ARCHITECTURE }
    $arch = switch ($nativeArch) {
        'AMD64' { 'x64' }
        'ARM64' { 'arm64' }
        default { throw 'Unsupported architecture; expected Windows x64 or ARM64.' }
    }
    $manifest = Get-Content -LiteralPath 'tools/gitleaks-release.txt'
    $version = $manifest[0]
    if ($version -notmatch '^\d+\.\d+\.\d+$') { throw 'Invalid pinned version.' }
    $asset = "gitleaks_${version}_windows_${arch}.zip"
    $entries = @($manifest | Where-Object { ($_ -split '\s+')[-1] -eq $asset })
    if ($entries.Count -ne 1) { throw "Missing or duplicate checksum for $asset." }
    $expected = ($entries[0] -split '\s+')[0]
    if ($expected -notmatch '^[0-9a-f]{64}$') { throw "Invalid checksum for $asset." }

    $base = Join-Path $root '.tools/gitleaks'
    $stage = Join-Path $base ('.install.' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $stage -Force | Out-Null
    $archive = Join-Path $stage $asset
    $url = "https://github.com/gitleaks/gitleaks/releases/download/v$version/$asset"
    # Enable modern TLS on Windows PowerShell without changing machine settings.
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    Write-Host "Downloading Gitleaks $version (windows/$arch)..."
    Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $archive -TimeoutSec 180
    $actual = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $expected) {
        throw 'Checksum mismatch; binary and hook configuration were not changed.'
    }

    # Copy only this entry's bytes; never extract arbitrary paths from the ZIP.
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($archive)
    $binary = Join-Path $stage 'gitleaks.exe'
    try {
        $entry = $zip.GetEntry('gitleaks.exe')
        if (-not $entry) { throw 'Archive does not contain gitleaks.exe.' }
        [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $binary)
    } finally {
        $zip.Dispose()
    }
    $installedVersion = & $binary version
    if ($LASTEXITCODE -ne 0 -or $installedVersion -ne $version) {
        throw 'Downloaded executable has an unexpected version.'
    }

    $target = Join-Path $base $version
    New-Item -ItemType Directory -Path $target -Force | Out-Null
    $destination = Join-Path $target 'gitleaks.exe'
    if (Test-Path -LiteralPath $destination) {
        if ((Get-Item -LiteralPath $destination).Attributes -band [IO.FileAttributes]::ReparsePoint) {
            throw 'Refusing to replace a link at the install destination.'
        }
        [IO.File]::Replace($binary, $destination, $null)
    } else {
        [IO.File]::Move($binary, $destination)
    }
    & git config --local core.hooksPath .githooks
    if ($LASTEXITCODE -ne 0) { throw 'Could not enable repository hooks.' }
    Write-Host "Gitleaks $version installed in $target; repository hooks enabled."
} finally {
    if ($originalOutputEncoding) { [Console]::OutputEncoding = $originalOutputEncoding }
    if ($stage -and (Test-Path -LiteralPath $stage)) {
        Remove-Item -LiteralPath $stage -Recurse -Force
    }
    Pop-Location
}
