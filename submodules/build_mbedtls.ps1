# build_mbedtls.ps1 - Windows-only; there is no build_mbedtls.sh.
#
# macOS and iOS do their TLS through Network.framework and Linux takes Mbed TLS
# from the distro package, so only the Windows leg builds it. Built static,
# both configurations, with the stock mbedtls_config.h (TLS 1.2/1.3, PSK,
# AES-GCM, PBKDF2, CTR-DRBG and the platform entropy source are all on there).
#
# Consumers must also link bcrypt.lib (the entropy source calls
# BCryptGenRandom) and ws2_32.lib if they use mbedtls/net_sockets.h.
. "$PSScriptRoot\..\env.ps1"

$src = Join-Path $PSScriptRoot 'mbedtls'

# The 3.6 line keeps part of its CMake tree in a nested 'framework' submodule,
# and the top-level CMakeLists.txt refuses to configure without it - even for a
# library-only build. build_windows.ps1 inits submodules non-recursively, so
# fetch it here at the commit mbedtls records.
if (-not (Test-Path (Join-Path $src 'framework\CMakeLists.txt'))) {
    Push-Location $src
    try { Invoke-Checked git submodule update --init --depth 1 framework }
    finally { Pop-Location }
}

$wanted = @('mbedtls.lib', 'mbedx509.lib', 'mbedcrypto.lib')
foreach ($cfg in @('Release', 'Debug')) {
    $build = Join-Path $PSScriptRoot "mbedtls\build-win-$cfg"
    # No CRT option is passed: MSVC_STATIC_RUNTIME defaults OFF, so CMake's
    # default /MD (Release) and /MDd (Debug) apply - the same CRT as every
    # other library here and as xLights itself. FATAL_WARNINGS is off so a
    # new compiler warning does not fail the bundle; programs and tests are
    # not shipped.
    Build-CMakeProject -Source $src -BuildDir $build -Config $cfg -Options @(
        '-DUSE_STATIC_MBEDTLS_LIBRARY=ON', '-DUSE_SHARED_MBEDTLS_LIBRARY=OFF',
        '-DENABLE_PROGRAMS=OFF', '-DENABLE_TESTING=OFF',
        '-DMBEDTLS_FATAL_WARNINGS=OFF', '-DGEN_FILES=OFF',
        '-DDISABLE_PACKAGE_CONFIG_AND_INSTALL=ON')

    # The build also emits the 3rdparty helper libraries (everest, p256m),
    # which the default configuration does not use. Pick the three Mbed TLS
    # libraries by name, but check each exists exactly once rather than
    # assuming a path, so an upstream rename or a debug postfix fails here.
    $all = @(Get-ChildItem $build -Recurse -Filter '*.lib' -File)
    Write-Host ("    mbedtls produced: " + (($all | ForEach-Object { $_.Name }) -join ', ')) -ForegroundColor DarkGray
    $dest = if ($cfg -eq 'Release') { $XL_LIB_DIR } else { $XL_DBG_DIR }
    foreach ($name in $wanted) {
        $hits = @($all | Where-Object { $_.Name -ieq $name })
        if ($hits.Count -ne 1) {
            throw ("build_mbedtls: expected exactly one $name in $build, found $($hits.Count) " +
                   "(produced: " + (($all | ForEach-Object { $_.Name }) -join ', ') + ")")
        }
        Install-Artifact -Path $hits[0].FullName -Destination $dest
    }
}

# Headers: mbedtls/ and psa/ - the public mbedtls headers include psa/ ones.
foreach ($dir in @('mbedtls', 'psa')) {
    $from = Join-Path $src "include\$dir"
    if (-not (Test-Path (Join-Path $from '*.h'))) { throw "build_mbedtls: no headers in $from" }
    $to = Join-Path $XL_INC_DIR $dir
    # Replace rather than merge, so a header dropped upstream does not linger.
    Remove-Item -Recurse -Force $to -ErrorAction SilentlyContinue
    Copy-Item $from $to -Recurse -Force
}
Write-Host "==> mbedtls done" -ForegroundColor Green
