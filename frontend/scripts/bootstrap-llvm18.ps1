param([string]$ToolRoot)
$ErrorActionPreference = 'Stop'
$frontend = Split-Path $PSScriptRoot -Parent
$repo = Split-Path $frontend -Parent
if (-not $ToolRoot) { $ToolRoot = Join-Path $repo '.build-tools' }
$llvm = Join-Path $ToolRoot 'llvm-18.1.8-win64'
$libclang = Join-Path $llvm 'bin/libclang.dll'
$clang = Join-Path $llvm 'bin/clang.exe'
$headers = Join-Path $llvm 'lib/clang/18/include/stddef.h'
if ((Test-Path $libclang) -and (Test-Path $clang) -and (Test-Path $headers)) {
  Write-Host "LLVM 18 already ready: $llvm"
  $llvm
  exit 0
}
New-Item -ItemType Directory -Force -Path $ToolRoot | Out-Null
$archive = Join-Path $ToolRoot 'LLVM-18.1.8-win64.exe'
# Official LLVM asset; checksum also published in microsoft/winget-pkgs 18.1.8.
$expected = '94AF030060D88CC17E9F00EF1663EBDC1126B35E16BEBDFA1E807984B70ABD8F'
if (-not (Test-Path $archive)) {
  Write-Host 'Downloading the official LLVM 18 Windows tools package...'
  $partial = "$archive.partial"
  & curl.exe --fail --location --retry 2 --retry-all-errors --retry-max-time 900 --connect-timeout 30 --max-time 600 --output $partial 'https://github.com/llvm/llvm-project/releases/download/llvmorg-18.1.8/LLVM-18.1.8-win64.exe'
  if ($LASTEXITCODE -ne 0) { throw 'LLVM download failed within its timeout' }
  Move-Item -LiteralPath $partial -Destination $archive -Force
}
Write-Host 'Checking LLVM package SHA-256...'
if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne $expected) { throw 'LLVM 18 checksum mismatch' }
$seven = (Get-Command 7z.exe -ErrorAction SilentlyContinue).Source
if (-not $seven) { $seven = 'C:/Program Files/7-Zip/7z.exe' }
if (-not (Test-Path $seven)) { throw '7-Zip is required to extract the LLVM build tools' }
Write-Host 'Extracting only clang, libclang dependencies, and resource headers (no system install)...'
& $seven x $archive "-o$llvm" -y 'bin/*.dll' 'bin/clang.exe' 'lib/clang/*/include/*'
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $libclang) -or -not (Test-Path $clang) -or -not (Test-Path $headers)) { throw 'LLVM subset extraction failed' }
Write-Host "LLVM 18 ready: $llvm"
$llvm
