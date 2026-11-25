param([switch]$Cuda, [string]$LlvmDir, [string]$VsInstall)

$ErrorActionPreference = 'Stop'
$frontend = Split-Path $PSScriptRoot -Parent
$repo = Split-Path $frontend -Parent
$tauri = Join-Path $frontend 'src-tauri'
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
if (-not $VsInstall) {
  $VsInstall = (& $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath | Select-Object -First 1)
}
if (-not $VsInstall -or -not (Test-Path (Join-Path $VsInstall 'VC/Auxiliary/Build/vcvars64.bat'))) {
  throw 'Visual Studio C++ tools were not discovered. Pass -VsInstall with the supported installation directory.'
}
$vcvars = Join-Path $vsInstall 'VC/Auxiliary/Build/vcvars64.bat'
cmd /c "call `"$vcvars`" >nul 2>&1 && set" | ForEach-Object {
  if ($_ -match '^([^=]+)=(.*)$') { [Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process') }
}
$llvm = $LlvmDir
if (-not $llvm -and (Test-Path 'C:/Program Files/LLVM/bin/clang.exe')) {
  $installedVersion = (& 'C:/Program Files/LLVM/bin/clang.exe' --version | Select-Object -First 1)
  if ($installedVersion -match 'clang version 18\.') { $llvm = 'C:/Program Files/LLVM' }
}
if (-not $llvm) { $llvm = & (Join-Path $PSScriptRoot 'bootstrap-llvm18.ps1') | Select-Object -Last 1 }
$env:LIBCLANG_PATH = Join-Path $llvm 'bin'
$env:CMAKE_GENERATOR = 'Ninja'
Remove-Item Env:CMAKE_GENERATOR_INSTANCE -ErrorAction SilentlyContinue
$env:PATH = "$(Join-Path $vsInstall 'Common7/IDE/CommonExtensions/Microsoft/CMake/Ninja');$env:PATH"
$env:PNPM_CONFIG_ENABLE_GLOBAL_VIRTUAL_STORE = 'false'
$env:NEXT_TELEMETRY_DISABLED = '1'
$env:ORT_LIB_LOCATION = Join-Path $tauri 'binaries/onnxruntime'
$target = 'x86_64-pc-windows-msvc'
$features = 'custom-protocol'
$helperFeatures = @()
$variant = 'cpu'
$cudaDlls = @('cudart64_13.dll', 'cublas64_13.dll', 'cublasLt64_13.dll')
if ($Cuda) {
  if (-not $env:CUDA_PATH -and (Test-Path 'C:/Program Files/NVIDIA GPU Computing Toolkit/CUDA/v13.3')) {
    $env:CUDA_PATH = 'C:/Program Files/NVIDIA GPU Computing Toolkit/CUDA/v13.3'
  }
  if (-not $env:CUDA_PATH -or -not (Test-Path "$env:CUDA_PATH/bin/nvcc.exe")) { throw 'CUDA 13 toolkit is required for -Cuda' }
  $env:CUDA_TOOLKIT_ROOT_DIR = $env:CUDA_PATH
  $env:PATH = "$env:CUDA_PATH/bin;$env:CUDA_PATH/bin/x64;$env:PATH"
  # Ship SASS for desktop RTX 20/30/40/50 and Ampere SM80.
  $env:CMAKE_CUDA_ARCHITECTURES = '75;80;86;89;120'
  $env:CL = '/DCCCL_IGNORE_DEPRECATED_CPP_DIALECT /DCCCL_IGNORE_MSVC_TRADITIONAL_PREPROCESSOR_WARNING /Zc:preprocessor'
  $env:_CL_ = $env:CL
  $env:NVCC_APPEND_FLAGS = '-std=c++17 -Xcompiler=/Zc:preprocessor -DCCCL_IGNORE_MSVC_TRADITIONAL_PREPROCESSOR_WARNING'
  $env:CMAKE_CUDA_FLAGS = '--std=c++17 -DCCCL_IGNORE_DEPRECATED_CPP_DIALECT -DCCCL_IGNORE_MSVC_TRADITIONAL_PREPROCESSOR_WARNING -Xcompiler="/Zc:preprocessor"'
  $features = 'custom-protocol,cuda'
  $helperFeatures = @('--features','cuda')
  $variant = 'cuda'
}
New-Item -ItemType Directory -Force (Join-Path $tauri 'runtime-deps'), (Join-Path $tauri 'installer-variants'), (Join-Path $tauri 'binaries') | Out-Null
Set-Content (Join-Path $tauri 'installer-variants/README.txt') "Ultra $variant release; one explicitly selected backend is bundled."
Push-Location $repo
try {
  cargo build --locked --release -p llama-helper --target $target @helperFeatures
  if ($LASTEXITCODE -ne 0) { throw 'llama-helper build failed' }
  Copy-Item "target/$target/release/llama-helper.exe" "$tauri/binaries/llama-helper-$target.exe" -Force
  Push-Location $frontend
  try {
    & node (Join-Path $frontend 'node_modules/@tauri-apps/cli/tauri.js') build --target $target --no-bundle -- --no-default-features --features $features
    if ($LASTEXITCODE -ne 0) { throw 'Ultra application build failed' }
    foreach ($file in Get-ChildItem "$tauri/binaries/onnxruntime" -File) { Copy-Item $file.FullName (Join-Path $tauri 'runtime-deps') -Force }
    foreach ($name in $cudaDlls) {
      $destination = Join-Path $tauri "runtime-deps/$name"
      if ($Cuda) {
        $source = Join-Path $env:CUDA_PATH "bin/x64/$name"
        if (-not (Test-Path $source)) { $source = Join-Path $env:CUDA_PATH "bin/$name" }
        if (-not (Test-Path $source)) { throw "Required CUDA runtime is missing: $name" }
        Copy-Item -LiteralPath $source -Destination $destination -Force
      } elseif (Test-Path $destination) { Remove-Item -LiteralPath $destination }
    }
    $vcRedist = Join-Path $tauri 'runtime-deps/vc_redist.x64.exe'
    Invoke-WebRequest 'https://aka.ms/vs/18/release/vc_redist.x64.exe' -OutFile $vcRedist
    $signature = Get-AuthenticodeSignature -LiteralPath $vcRedist
    if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'Microsoft Corporation') { throw 'Visual C++ redistributable signature is invalid' }
    $runtimeVersion = [version](Get-Item -LiteralPath $vcRedist).VersionInfo.ProductVersion
    if ($env:VCToolsVersion -and $runtimeVersion -lt [version]$env:VCToolsVersion) {
      throw "Visual C++ runtime $runtimeVersion is older than compiler $env:VCToolsVersion"
    }

    & node (Join-Path $frontend 'node_modules/@tauri-apps/cli/tauri.js') bundle --target $target --bundles nsis
    if ($LASTEXITCODE -ne 0) { throw 'Ultra installer packaging failed' }
  } finally { Pop-Location }
  $env:PATH = "$tauri/binaries/onnxruntime;$env:PATH"
  $hardwareTestArgs = @()
  if ($env:GITHUB_ACTIONS -eq 'true') {
    # Hosted runners have no output endpoint. This hardware integration test is
    # still exercised by the complete local qualification suite on a workstation.
    Write-Host 'Headless runner: excluding the physical default-output-device integration test.'
    $hardwareTestArgs = @('--','--skip','audio::playback_monitor::tests::test_get_output_device')
  }
  cargo test --locked --release -p meetily --lib --target $target --no-default-features --features $features @hardwareTestArgs
  if ($LASTEXITCODE -ne 0) { throw 'Native regression tests failed' }
  python frontend/scripts/verify-ultra-release.py windows $target $variant
  if ($LASTEXITCODE -ne 0) { throw 'Installer verification failed' }
} finally { Pop-Location }
