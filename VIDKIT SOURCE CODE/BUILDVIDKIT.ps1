<#
.SYNOPSIS
  Builds VIDKIT-A000.BIN.  Same steps as BUILDVIDKIT.BAS and the Makefile.

.EXAMPLE
  .\BUILDVIDKIT.ps1                      build everything
  .\BUILDVIDKIT.ps1 -Clean               remove generated files
  .\BUILDVIDKIT.ps1 -Jar C:\p8\prog8c-12.3.5-all.jar   use (and remember in P8JARPATH) this jar

  If scripts are blocked:  powershell -ExecutionPolicy Bypass -File .\BUILDVIDKIT.ps1

  Needs java, 64tass, lzsa and make + cc65 (cl65) on the PATH.

  After the build: VIDKIT.Z = lzsa -r -f2 VIDKIT-A000.BIN VIDKIT.Z, then VIDKIT-A000.BIN and
  VIDKIT.Z are copied into the example folders.

  Layout of VIDKIT-A000.BIN (each part zero padded to its slot):
    VIDKIT-B1.bin 8192 | VIDKIT.ENGINE 2560 | VIDKIT-B2.bin 5632 | SPIVID.ENGINE 5120 | VIDKIT-B3.bin (not padded)
#>
param(
    [switch]$Clean,
    [string]$Jar
)

$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot

function Fail([string]$msg) {
    Write-Host ""
    Write-Host $msg
    Write-Host ""
    exit 1
}

function Remove-Noisy([string]$file) {
    if (Test-Path -LiteralPath $file -PathType Leaf) {
        Write-Host "Removing -->  $file"
        Remove-Item -LiteralPath $file -Force
    }
}

# run an external program, stop the build if it fails
function Invoke-Tool([string]$exe, [string[]]$arguments) {
    Write-Host ("$exe " + ($arguments -join ' '))
    & $exe @arguments
    if ($LASTEXITCODE -ne 0) { Fail "$exe failed (exit code $LASTEXITCODE)" }
    Write-Host ""
}

function Invoke-Make([string]$dir, [string]$outFile) {
    Push-Location -LiteralPath $dir
    try { Invoke-Tool 'make' @() } finally { Pop-Location }
    Write-Host "copy $dir\$outFile ."
    Copy-Item -LiteralPath (Join-Path $dir $outFile) -Destination . -Force
    Write-Host ""
}

# ---------------------------------------------------------------- clean
if ($Clean) {
    foreach ($d in 'SPIVID-ENGINE', 'VIDKIT-ENGINE') {
        $eng = if ($d -eq 'SPIVID-ENGINE') { 'SPIVID.ENGINE' } else { 'VIDKIT.ENGINE' }
        Remove-Noisy (Join-Path $d $eng)
        Remove-Noisy (Join-Path $d 'src\main.o')
    }
    foreach ($f in 'a.out', 'tramp.o', 'VIDKIT-B1.bin', 'VIDKIT-B2.bin', 'VIDKIT-B3.bin',
                   'VIDKIT.ENGINE', 'SPIVID.ENGINE', 'BUILDVIDKIT.license.txt', 'VIDKIT-A000.tmp') {
        Remove-Noisy $f
    }
    Get-ChildItem -File -Path '*.asm', '*.vice-mon-list' -ErrorAction SilentlyContinue |
        ForEach-Object { Remove-Noisy $_.Name }
    exit 0
}

# ---------------------------------------------------------------- prog8 jar
function Test-Jar([string]$p) {
    return ($p -and $p.ToLower().EndsWith('.jar') -and (Test-Path -LiteralPath $p -PathType Leaf))
}

$jarFile = $null
if ($Jar) {
    $jarFile = $Jar
} elseif (Test-Path -LiteralPath 'P8JARPATH') {
    $jarFile = (Get-Content -LiteralPath 'P8JARPATH' -TotalCount 1)
    if ($jarFile) { $jarFile = $jarFile.Trim() }
}
if (-not (Test-Jar $jarFile)) {
    Fail ("prog8 JAR not found !`nCan't continue !`nUse:  .\BUILDVIDKIT.ps1 -Jar C:\path\to\prog8c-x.y.z-all.jar   (remembered in P8JARPATH)")
}
if ($Jar) { Set-Content -LiteralPath 'P8JARPATH' -Value $jarFile -Encoding ASCII }

# ---------------------------------------------------------------- trampoline
Remove-Noisy 'a.out'
Write-Host "Assembling trampoline.s"
Invoke-Tool '64tass' @('tramp.s', '-o', 'a.out')
if (-not (Test-Path -LiteralPath 'a.out')) { Fail "Error assembling Trampoline object !" }
$obj = [System.IO.File]::ReadAllBytes((Join-Path $PWD 'a.out'))
# drop the 2 byte load address
[System.IO.File]::WriteAllBytes((Join-Path $PWD 'tramp.o'), $obj[2..($obj.Length - 1)])

# ---------------------------------------------------------------- prog8 banks
foreach ($b in 'VIDKIT-B1', 'VIDKIT-B2', 'VIDKIT-B3') {
    Remove-Item -LiteralPath "$b.bin" -Force -ErrorAction SilentlyContinue   # no stale .bin may pass
    Invoke-Tool 'java' @('-jar', $jarFile, '-target', 'cx16', "$b.p8")
    if (-not (Test-Path -LiteralPath "$b.bin")) { Fail "prog8 did not produce $b.bin" }
}

# ---------------------------------------------------------------- engines
Invoke-Make 'VIDKIT-ENGINE' 'VIDKIT.ENGINE'
Invoke-Make 'SPIVID-ENGINE' 'SPIVID.ENGINE'

# ---------------------------------------------------------------- VIDKIT-A000.BIN
$parts = @(
    @{ File = 'VIDKIT-B1.bin';  Slot = 8192 },
    @{ File = 'VIDKIT.ENGINE';  Slot = 2560 },
    @{ File = 'VIDKIT-B2.bin';  Slot = 5632 },
    @{ File = 'SPIVID.ENGINE';  Slot = 5120 },
    @{ File = 'VIDKIT-B3.bin';  Slot = 0 }       # last part is not padded
)
foreach ($p in $parts) {
    if (Test-Path -LiteralPath $p.File) { Write-Host "FOUND: $($p.File)" }
    else { Fail "MISSING: $($p.File)" }
}

Write-Host ""
Write-Host "CREATING:  VIDKIT-A000.BIN"
$tmp = Join-Path $PWD 'VIDKIT-A000.tmp'
$ms = New-Object System.IO.MemoryStream
$total = 0
foreach ($p in $parts) {
    $data = [System.IO.File]::ReadAllBytes((Join-Path $PWD $p.File))
    $sz = $data.Length
    $slot = if ($p.Slot -eq 0) { $sz } else { $p.Slot }
    if ($sz -gt $slot) {
        Fail "ERROR: $($p.File) is $sz bytes but its slot is $slot (over by $($sz - $slot))"
    }
    $pad = $slot - $sz
    $ms.Write($data, 0, $sz)
    if ($pad -gt 0) { $ms.Write((New-Object byte[] $pad), 0, $pad) }
    Write-Host "COPYING: $($p.File),  Size: $sz"
    if ($pad -gt 0) { Write-Host "PAD BYTES: $pad   TOTAL BYTES: $slot" }
    Write-Host ""
    $total += $slot
}
[System.IO.File]::WriteAllBytes($tmp, $ms.ToArray())
Move-Item -LiteralPath $tmp -Destination 'VIDKIT-A000.BIN' -Force
Write-Host " VIDKIT-A000.BIN  SIZE: $total"

# ---------------------------------------------------------------- VIDKIT.Z
Write-Host ""
Write-Host "COMPRESSING:  VIDKIT-A000.BIN -> VIDKIT.Z"
Remove-Item -LiteralPath 'VIDKIT.Z' -Force -ErrorAction SilentlyContinue
Invoke-Tool 'lzsa' @('-r', '-f2', 'VIDKIT-A000.BIN', 'VIDKIT.Z')
if (-not (Test-Path -LiteralPath 'VIDKIT.Z')) { Fail "lzsa did not produce VIDKIT.Z" }
Write-Host " VIDKIT.Z  SIZE: $((Get-Item -LiteralPath 'VIDKIT.Z').Length)"

# ---------------------------------------------------------------- copy into the example folders
Write-Host ""
Write-Host "COPYING to the example folders"
$ex     = 'EXAMPLE VIDKIT CODE'
$player = Join-Path $ex 'X16 MOVIE PLAYER ( prog8 )'
$maker  = Join-Path $ex 'MOVIE MAKER PLAYER TEMPLATES ( prog8 )'
$copies = @(
    @('VIDKIT-A000.BIN', (Join-Path $ex 'BASLOAD CODE')),
    @('VIDKIT-A000.BIN', $player),
    @('VIDKIT-A000.BIN', (Join-Path $player 'ASSETS')),
    @('VIDKIT-A000.BIN', (Join-Path $maker 'ASSETS')),
    @('VIDKIT.Z',        $maker)
)
foreach ($c in $copies) {
    Write-Host "copy $($c[0]) -> $($c[1])"
    Copy-Item -LiteralPath $c[0] -Destination $c[1] -Force
}
