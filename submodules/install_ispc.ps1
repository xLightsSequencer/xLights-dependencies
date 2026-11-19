# install_ispc.ps1 - Windows ispc, the analog of install_ispc.sh.
#
# Downloaded, not built, exactly as on macOS. ISPC_VERSION at the repo root is
# the single pin both scripts read; the Windows asset is checked against its
# sha256 so a re-uploaded release cannot slip in unnoticed.
#
# Only ispc.exe is installed. The release's bin/ also carries ispc.dll (the
# library form of the compiler, ~300 MB) and the ispcrt runtime DLLs; ispc.exe
# does not load any of them, and xLights copies every bin\*.dll from this bundle
# next to its executable, so shipping them would put them in the installer.

. "$PSScriptRoot\..\env.ps1"

$pin = Read-IspcPin
$asset = "ispc-$($pin.version)-windows.zip"
$url = "https://github.com/ispc/ispc/releases/download/$($pin.version)/$asset"

$work = Join-Path $PSScriptRoot 'ispc-win'
Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $work | Out-Null

Write-Host "==> ispc $($pin.version) -> $url" -ForegroundColor Cyan
$zip = Join-Path $work $asset
$ProgressPreference = 'SilentlyContinue'
try {
    Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
} catch {
    throw "install_ispc: download failed for $url : $($_.Exception.Message)"
}
$actual = (Get-FileHash -Algorithm SHA256 $zip).Hash.ToLowerInvariant()
if ($actual -ne $pin.sha256.ToLowerInvariant()) {
    throw "install_ispc: sha256 mismatch for ${asset}: got $actual, ISPC_VERSION pins $($pin.sha256)"
}

# bsdtar, not Expand-Archive: it can pull the one member out of a ~600 MB
# archive without unpacking the rest.
$member = "ispc-$($pin.version)-windows/bin/ispc.exe"
Invoke-Checked tar -x -f $zip -C $work $member
Install-Artifact -Path (Join-Path $work $member) -Destination $XL_BIN_DIR

Remove-Item -Recurse -Force $work
Write-Host "==> ispc done" -ForegroundColor Green
