$ErrorActionPreference = 'Stop'
$frontend = Split-Path $PSScriptRoot -Parent
$repo = Split-Path $frontend -Parent
$tauri = Join-Path $frontend 'src-tauri'
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$vsInstall = (& $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath).Trim()
$vcvars = Join-Path $vsInstall 'VC/Auxiliary/Build/vcvars64.bat'
cmd /c "call `"$vcvars`" >nul 2>&1 && set" | ForEach-Object {
  if ($_ -match '^([^=]+)=(.*)$') { [Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process') }
}
$llvm = & (Join-Path $PSScriptRoot 'bootstrap-llvm18.ps1') | Select-Object -Last 1
$env:LIBCLANG_PATH = Join-Path $llvm 'bin'
$env:CMAKE_GENERATOR = 'Ninja'
Remove-Item Env:CMAKE_GENERATOR_INSTANCE -ErrorAction SilentlyContinue
$env:PATH = "$(Join-Path $vsInstall 'Common7/IDE/CommonExtensions/Microsoft/CMake/Ninja');$env:PATH"
$env:PNPM_CONFIG_ENABLE_GLOBAL_VIRTUAL_STORE = 'false'
$env:NEXT_TELEMETRY_DISABLED = '1'
$env:ORT_LIB_LOCATION = Join-Path $tauri 'binaries/onnxruntime'
$target = 'x86_64-pc-windows-msvc'
New-Item -ItemType Directory -Force (Join-Path $tauri 'runtime-deps'), (Join-Path $tauri 'installer-variants'), (Join-Path $tauri 'binaries') | Out-Null
Set-Content (Join-Path $tauri 'installer-variants/README.txt') 'Ultra CPU release; no optional GPU variants are staged.'
Push-Location $repo
try {
  cargo build --locked --release -p llama-helper --target $target
  if ($LASTEXITCODE -ne 0) { throw 'llama-helper build failed' }
  Copy-Item "target/$target/release/llama-helper.exe" "$tauri/binaries/llama-helper-$target.exe" -Force
  Push-Location $frontend
  try {
    pnpm exec tauri build --target $target --no-bundle -- --no-default-features --features custom-protocol
    if ($LASTEXITCODE -ne 0) { throw 'Ultra application build failed' }
    foreach ($file in Get-ChildItem "$tauri/binaries/onnxruntime" -File) { Copy-Item $file.FullName (Join-Path $tauri 'runtime-deps') -Force }
    $vcRedist = Join-Path $tauri 'runtime-deps/vc_redist.x64.exe'
    Invoke-WebRequest 'https://aka.ms/vs/17/release/vc_redist.x64.exe' -OutFile $vcRedist
    $signature = Get-AuthenticodeSignature -LiteralPath $vcRedist
    if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'Microsoft Corporation') { throw 'Visual C++ redistributable signature is invalid' }
    pnpm exec tauri bundle --target $target --bundles nsis
    if ($LASTEXITCODE -ne 0) { throw 'Ultra installer packaging failed' }
  } finally { Pop-Location }
  $env:PATH = "$tauri/binaries/onnxruntime;$env:PATH"
  cargo test --locked --release -p meetily --lib --target $target --no-default-features --features custom-protocol
  if ($LASTEXITCODE -ne 0) { throw 'Native regression tests failed' }
  python frontend/scripts/verify-ultra-release.py windows $target
  if ($LASTEXITCODE -ne 0) { throw 'Installer verification failed' }
} finally { Pop-Location }
