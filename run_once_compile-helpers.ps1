# Compile helper executables that dotfiles depend on.
# run_once_ scripts execute once per machine (chezmoi tracks state).

$ErrorActionPreference = "Stop"

$ScriptsDir = Join-Path $env:USERPROFILE ".local\share\chezmoi\scripts"
$BinDir = Join-Path $env:USERPROFILE ".local\bin"
$Csc = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"

# Validate compiler exists
if (-not (Test-Path $Csc)) {
    Write-Warning "C# compiler not found at $Csc"
    Write-Warning "clip2png.exe will not be compiled - Ctrl+V will use normal paste"
    exit 0
}

# Ensure bin directory exists
New-Item -ItemType Directory -Path $BinDir -Force -ErrorAction SilentlyContinue | Out-Null

# clip2png: clipboard image to PNG (used by wezterm smart paste)
$ClipSource = Join-Path $ScriptsDir "clip2png.cs"
$ClipExe = Join-Path $BinDir "clip2png.exe"

if (-not (Test-Path $ClipSource)) {
    Write-Host "No helpers to compile (scripts/clip2png.cs not found)"
    exit 0
}

Write-Host "Compiling clip2png.exe..."
& $Csc -nologo -optimize "-target:exe" "-out:$ClipExe" $ClipSource

if ($LASTEXITCODE -ne 0) {
    Write-Error "Compilation failed"
    exit 1
}

Write-Host "  -> $ClipExe"
