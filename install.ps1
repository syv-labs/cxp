Param(
  [string]$Repo = $env:CXP_REPO,
  [string]$Version = $env:CXP_VERSION,
  [string]$InstallDir = $env:CXP_INSTALL_DIR
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Repo)) {
  $Repo = "syv-labs/cxp"
}

if ([string]::IsNullOrWhiteSpace($Version)) {
  $Version = "latest"
}

if ([string]::IsNullOrWhiteSpace($InstallDir)) {
  $InstallDir = Join-Path $env:LOCALAPPDATA "ContextPool\bin"
}

$BinName = "cxp.exe"
$PkgName = "cxp"

function Get-LatestTag([string]$Repo) {
  $url = "https://api.github.com/repos/$Repo/releases/latest"
  $resp = Invoke-RestMethod -Uri $url -Headers @{ "User-Agent" = "contextpool-installer" }
  return $resp.tag_name
}

if ($Version -eq "latest") {
  $Tag = Get-LatestTag -Repo $Repo
} else {
  if ($Version.StartsWith("v")) { $Tag = $Version } else { $Tag = "v$Version" }
}

if ([string]::IsNullOrWhiteSpace($Tag)) {
  throw "Could not determine release tag. Set CXP_VERSION=0.1.0 or publish a GitHub Release."
}

$VersionNoV = $Tag.TrimStart("v")

switch ($env:PROCESSOR_ARCHITECTURE) {
  "AMD64" { $Target = "x86_64-pc-windows-msvc" }
  "ARM64" { $Target = "aarch64-pc-windows-msvc" }
  default { throw "Unsupported architecture: $env:PROCESSOR_ARCHITECTURE" }
}

$Asset = "$PkgName-v$VersionNoV-$Target.zip"
$BaseUrl = "https://github.com/$Repo/releases/download/$Tag"
$ArchiveUrl = "$BaseUrl/$Asset"
$ChecksumUrl = "$BaseUrl/checksums.txt"

$Tmp = Join-Path $env:TEMP ("contextpool-" + [Guid]::NewGuid().ToString("n"))
New-Item -ItemType Directory -Path $Tmp | Out-Null

try {
  Write-Host "Downloading $Asset from $Repo ($Tag)"
  Invoke-WebRequest -Uri $ArchiveUrl -OutFile (Join-Path $Tmp $Asset)

  $ChecksumsPath = Join-Path $Tmp "checksums.txt"
  $checksumDownloaded = $true
  try {
    Invoke-WebRequest -Uri $ChecksumUrl -OutFile $ChecksumsPath | Out-Null
  } catch {
    $checksumDownloaded = $false
  }

  if ($checksumDownloaded) {
    $expected = $null
    foreach ($line in (Get-Content $ChecksumsPath)) {
      if ([string]::IsNullOrWhiteSpace($line)) { continue }
      $parts = $line.Trim() -split "\s+", 2
      if ($parts.Count -eq 2 -and $parts[1] -eq $Asset) {
        $expected = $parts[0]
        break
      }
    }

    if ($expected) {
      $actual = (Get-FileHash -Algorithm SHA256 (Join-Path $Tmp $Asset)).Hash.ToLowerInvariant()
      if ($actual -ne $expected.ToLowerInvariant()) {
        throw "Checksum verification failed for $Asset"
      }
    } else {
      Write-Warning "No checksum entry found for $Asset; skipping verification"
    }
  } else {
    Write-Warning "checksums.txt not found; skipping checksum verification"
  }

  $Extract = Join-Path $Tmp "extract"
  Expand-Archive -Path (Join-Path $Tmp $Asset) -DestinationPath $Extract -Force

  $SrcBin = Join-Path $Extract $BinName
  if (!(Test-Path $SrcBin)) {
    throw "Expected $BinName inside archive, but not found."
  }

  New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
  Copy-Item -Path $SrcBin -Destination (Join-Path $InstallDir $BinName) -Force

  Write-Host "Installed cxp to $(Join-Path $InstallDir $BinName)"
  Write-Host ""
  Write-Host "Add to PATH (PowerShell):"
  Write-Host "  `$env:Path = '$InstallDir;' + `$env:Path"
  Write-Host ""
  Write-Host "Or permanently (User PATH) via System Settings."
}
finally {
  Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue
}
