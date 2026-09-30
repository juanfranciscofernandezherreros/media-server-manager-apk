param(
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"

function Write-Step($message) {
    Write-Host ""
    Write-Host "==> $message" -ForegroundColor Cyan
}

function Require-Command($name, $help) {
    if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
        throw "No se encontro '$name'. $help"
    }
}

Write-Host "Media Server Manager APK - Android setup" -ForegroundColor Green
Write-Host "Este script configurara el entorno y preparara la APK." -ForegroundColor DarkGray

Write-Step "Comprobando Node.js y npm"
Require-Command "node" "Instala Node.js 20 o superior: winget install OpenJS.NodeJS.LTS"
Require-Command "npm" "npm debe instalarse junto con Node.js."
node --version
npm --version

Write-Step "Comprobando Java"
Require-Command "java" "Instala JDK 17 o superior: winget install EclipseAdoptium.Temurin.17.JDK"
java -version

Write-Step "Localizando Android SDK"
$sdkCandidates = @(
    $env:ANDROID_HOME,
    "$env:LOCALAPPDATA\Android\Sdk",
    "$env:USERPROFILE\AppData\Local\Android\Sdk"
) | Where-Object { $_ -and (Test-Path $_) }

if (-not $sdkCandidates -or $sdkCandidates.Count -eq 0) {
    Write-Host ""
    Write-Host "No se encontro Android SDK." -ForegroundColor Red
    Write-Host "Instala Android Studio y desde SDK Manager instala:" -ForegroundColor Yellow
    Write-Host "  - Android SDK Platform 35"
    Write-Host "  - Android SDK Build-Tools 35"
    Write-Host "  - Android SDK Platform-Tools"
    Write-Host "  - Android SDK Command-line Tools (latest)"
    Write-Host ""
    Write-Host "Android Studio: winget install Google.AndroidStudio"
    exit 1
}

$androidHome = $sdkCandidates[0]
$env:ANDROID_HOME = $androidHome
$env:ANDROID_SDK_ROOT = $androidHome

$platformTools = Join-Path $androidHome "platform-tools"
$cmdlineLatest = Join-Path $androidHome "cmdline-tools\latest\bin"
$cmdlineLegacy = Join-Path $androidHome "cmdline-tools\bin"

$pathsToAdd = @($platformTools)
if (Test-Path $cmdlineLatest) {
    $pathsToAdd += $cmdlineLatest
} elseif (Test-Path $cmdlineLegacy) {
    $pathsToAdd += $cmdlineLegacy
}

foreach ($path in $pathsToAdd) {
    if ($env:PATH -notlike "*$path*") {
        $env:PATH += ";$path"
    }
}

Write-Host "ANDROID_HOME=$env:ANDROID_HOME"

Write-Step "Guardando ANDROID_HOME para futuras terminales"
[Environment]::SetEnvironmentVariable("ANDROID_HOME", $androidHome, "User")
[Environment]::SetEnvironmentVariable("ANDROID_SDK_ROOT", $androidHome, "User")

$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
foreach ($path in $pathsToAdd) {
    if ($userPath -notlike "*$path*") {
        if ([string]::IsNullOrWhiteSpace($userPath)) {
            $userPath = $path
        } else {
            $userPath += ";$path"
        }
    }
}
[Environment]::SetEnvironmentVariable("Path", $userPath, "User")

Write-Step "Comprobando herramientas Android"
Require-Command "adb" "Instala Android SDK Platform-Tools desde Android Studio."

$sdkManager = Get-Command "sdkmanager" -ErrorAction SilentlyContinue
if ($sdkManager) {
    Write-Step "Instalando componentes Android necesarios"
    1..30 | ForEach-Object { "y" } | & sdkmanager --licenses | Out-Host
    & sdkmanager "platform-tools" "platforms;android-35" "build-tools;35.0.0"
} else {
    Write-Host "sdkmanager no esta disponible; se omite la instalacion automatica de componentes." -ForegroundColor Yellow
    Write-Host "Instala 'Android SDK Command-line Tools (latest)' desde Android Studio."
}

Write-Step "Instalando dependencias npm"
npm install

Write-Step "Eliminando plugin Cordova obsoleto si aun existe"
try { npx cordova plugin remove cordova-plugin-whitelist | Out-Host } catch {}
try { npm uninstall cordova-plugin-whitelist --no-save | Out-Host } catch {}

Write-Step "Recreando plataforma Android"
if (Test-Path "platforms\android") {
    npx cordova platform remove android
}
npx cordova platform add android@14.0.1

Write-Step "Comprobando requisitos Cordova"
npx cordova requirements android

if (-not $SkipBuild) {
    Write-Step "Compilando APK debug"
    npx cordova build android --debug

    $apk = Join-Path (Get-Location) "platforms\android\app\build\outputs\apk\debug\app-debug.apk"
    if (Test-Path $apk) {
        Write-Host ""
        Write-Host "APK generada correctamente:" -ForegroundColor Green
        Write-Host $apk -ForegroundColor White
    } else {
        throw "La compilacion termino pero no se encontro la APK esperada."
    }
} else {
    Write-Host ""
    Write-Host "Entorno preparado. Compila con:" -ForegroundColor Green
    Write-Host "  npx cordova build android --debug"
}
