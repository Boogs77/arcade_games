# build.ps1 - assembles the Arcade6502 games (games\*.asm) into bin\ with vasm6502_oldstyle
#
#   .\tools\build.ps1                    all the games
#   .\tools\build.ps1 space_invaders     only the games given (name or file)
#
# The path of vasm6502_oldstyle.exe is read from the VASM variable or from the first
# line of the file vasm.path in the repository root (not in git).
# The games include ..\lib\arcade.asm: vasm runs from the games folder.

param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Games)

$root = Split-Path $PSScriptRoot -Parent
$vasm = $env:VASM
$vp = Join-Path $root 'vasm.path'
if (-not $vasm -and (Test-Path $vp)) { $vasm = (Get-Content $vp -TotalCount 1).Trim() }
if (-not $vasm -or -not (Test-Path $vasm)) {
  Write-Host "vasm6502_oldstyle not found: write its path in the file vasm.path" -ForegroundColor Red
  exit 1
}

$gdir = Join-Path $root 'games'
$bin = Join-Path $root 'bin'
New-Item -ItemType Directory -Force $bin | Out-Null
if (-not $Games) { $Games = (Get-ChildItem (Join-Path $gdir '*.asm')).BaseName }

$failed = @()
Push-Location $gdir
try {
  foreach ($g in $Games) {
    $name = [IO.Path]::GetFileNameWithoutExtension($g)
    $out = Join-Path $bin "$name.bin"
    & $vasm -Fbin -dotdir -c02 -quiet -o $out "$name.asm"
    if ($LASTEXITCODE -ne 0) { $failed += $name; continue }
    Write-Host ("{0,-20} {1,6} bytes" -f $name, (Get-Item $out).Length)
  }
} finally { Pop-Location }

if ($failed) { Write-Host "FAILED: $($failed -join ', ')" -ForegroundColor Red; exit 1 }
