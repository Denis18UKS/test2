param(
    [Parameter(Mandatory = $true)]
    [string]$InstallDir
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Write-Step([string]$Message) {
    Write-Host "[VK Dialog Exporter] $Message"
}

function Find-Python311 {
    try {
        $path = (& py -3.11 -c "import sys; print(sys.executable)" 2>$null | Select-Object -First 1)
        if ($LASTEXITCODE -eq 0 -and $path -and (Test-Path $path.Trim())) {
            return $path.Trim()
        }
    } catch {}

    $candidates = @(
        "$env:LOCALAPPDATA\Programs\Python\Python311\python.exe",
        "$env:ProgramFiles\Python311\python.exe",
        "${env:ProgramFiles(x86)}\Python311\python.exe"
    )
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path $candidate)) { return $candidate }
    }
    return $null
}

function Install-Python311 {
    Write-Step 'Python 3.11 not found. Installing it automatically...'
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget) {
        & winget install --id Python.Python.3.11 -e --scope user --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
        if ($LASTEXITCODE -eq 0) { return }
        Write-Warning "winget returned code $LASTEXITCODE. Falling back to the official Python installer."
    }

    $installer = Join-Path $env:TEMP 'python-3.11.9-amd64.exe'
    Invoke-WebRequest -UseBasicParsing -Uri 'https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe' -OutFile $installer
    $proc = Start-Process -FilePath $installer -ArgumentList '/quiet','InstallAllUsers=0','PrependPath=1','Include_launcher=1','Include_test=0' -Wait -PassThru
    if ($proc.ExitCode -ne 0) { throw "Python installer failed with exit code $($proc.ExitCode)." }
    Remove-Item $installer -Force -ErrorAction SilentlyContinue
}

Write-Step 'Preparing installation directory...'
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
$archive = Join-Path $InstallDir 'source.zip'
if (-not (Test-Path $archive)) { throw 'Bundled source.zip was not found.' }

Write-Step 'Extracting application files...'
Expand-Archive -Path $archive -DestinationPath $InstallDir -Force
$project = Join-Path $InstallDir 'vk-dialog-exporter'
if (-not (Test-Path (Join-Path $project 'requirements.txt'))) {
    throw 'Application archive is invalid: requirements.txt was not found.'
}

$python = Find-Python311
if (-not $python) {
    Install-Python311
    $python = Find-Python311
}
if (-not $python) { throw 'Python 3.11 installation completed, but python.exe could not be found.' }
Write-Step "Using Python: $python"

# CTranslate2/PySide6 depend on the Microsoft Visual C++ runtime on clean Windows installations.
Write-Step 'Ensuring Microsoft Visual C++ runtime is installed...'
try {
    $vcInstaller = Join-Path $env:TEMP 'vc_redist.x64.exe'
    Invoke-WebRequest -UseBasicParsing -Uri 'https://aka.ms/vs/17/release/vc_redist.x64.exe' -OutFile $vcInstaller
    $vcProc = Start-Process -FilePath $vcInstaller -ArgumentList '/install','/quiet','/norestart' -Wait -PassThru
    if ($vcProc.ExitCode -notin @(0, 1638, 3010)) {
        Write-Warning "VC++ runtime installer returned code $($vcProc.ExitCode)."
    }
    Remove-Item $vcInstaller -Force -ErrorAction SilentlyContinue
} catch {
    Write-Warning "Could not refresh VC++ runtime: $($_.Exception.Message)"
}

$venv = Join-Path $project '.venv'
$venvPython = Join-Path $venv 'Scripts\python.exe'
if (-not (Test-Path $venvPython)) {
    Write-Step 'Creating isolated Python environment...'
    & $python -m venv $venv
    if ($LASTEXITCODE -ne 0) { throw "venv creation failed with code $LASTEXITCODE." }
}

Write-Step 'Installing/updating required components...'
& $venvPython -m pip install --disable-pip-version-check --upgrade pip
if ($LASTEXITCODE -ne 0) { throw "pip upgrade failed with code $LASTEXITCODE." }
& $venvPython -m pip install --disable-pip-version-check -r (Join-Path $project 'requirements.txt')
if ($LASTEXITCODE -ne 0) { throw "Dependency installation failed with code $LASTEXITCODE." }

# The project intentionally uses a src/ layout. Add it to the venv import path so
# launcher.py works from Explorer/desktop shortcuts without relying on PYTHONPATH.
Write-Step 'Registering application package path...'
$sitePackages = (& $venvPython -c "import site; print(site.getsitepackages()[0])" | Select-Object -First 1).Trim()
if (-not $sitePackages -or -not (Test-Path $sitePackages)) { throw 'Could not resolve venv site-packages.' }
$srcPath = Join-Path $project 'src'
if (-not (Test-Path $srcPath)) { throw 'Application src directory was not found.' }
Set-Content -Path (Join-Path $sitePackages 'vk_dialog_exporter_src.pth') -Value $srcPath -Encoding ASCII

Write-Step 'Checking installed runtime...'
& $venvPython -c "import requests, webview, PySide6, faster_whisper, keyring, av, vk_dialog_exporter; print('Runtime OK')"
if ($LASTEXITCODE -ne 0) { throw 'Runtime self-check failed.' }

Remove-Item $archive -Force -ErrorAction SilentlyContinue
Write-Step 'Installation completed successfully.'
