param(
    [switch]$SkipBuild,
    [switch]$NoPull
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
Write-Host "Este script actualiza main, prepara Android desde cero y genera la APK." -ForegroundColor DarkGray

Write-Step "Comprobando repositorio Git"
Require-Command "git" "Instala Git y asegurate de que esta disponible en PATH."

if (-not (Test-Path ".git")) {
    throw "Ejecuta este script desde la raiz de media-server-manager-apk."
}

if (-not $NoPull) {
    Write-Step "Actualizando rama main"

    git fetch origin
    if ($LASTEXITCODE -ne 0) {
        throw "git fetch ha fallado."
    }

    git checkout main
    if ($LASTEXITCODE -ne 0) {
        throw "No se pudo cambiar a la rama main. Revisa si tienes cambios locales sin guardar."
    }

    git pull --ff-only origin main
    if ($LASTEXITCODE -ne 0) {
        throw "git pull --ff-only ha fallado. Revisa si tu rama local diverge de origin/main."
    }

    Write-Host "Repositorio actualizado a origin/main." -ForegroundColor Green
} else {
    Write-Host "Actualizacion Git omitida por -NoPull." -ForegroundColor Yellow
}

Write-Step "Comprobando Node.js y npm"
Require-Command "node" "Instala Node.js 20 o superior: winget install OpenJS.NodeJS.LTS"
Require-Command "npm" "npm debe instalarse junto con Node.js."
node --version
npm --version

Write-Step "Comprobando Java 17"
Require-Command "java" "Instala JDK 17: winget install -e --id EclipseAdoptium.Temurin.17.JDK"

$javaVersionText = (& cmd /c "java -version 2>&1" | Out-String)
$javaMajor = $null
if ($javaVersionText -match 'version "(\d+)') {
    $javaMajor = [int]$Matches[1]
}

if ($javaMajor -ne 17) {
    Write-Host "Se detecto Java $javaMajor, pero cordova-android 14 requiere JDK 17." -ForegroundColor Yellow
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Step "Instalando Eclipse Temurin JDK 17"
        winget install -e --id EclipseAdoptium.Temurin.17.JDK --accept-package-agreements --accept-source-agreements
    } else {
        throw "Falta JDK 17 y winget no esta disponible. Instala Eclipse Temurin JDK 17."
    }
}

$jdk17Candidates = @(
    "C:\Program Files\Eclipse Adoptium\jdk-17*",
    "C:\Program Files\Java\jdk-17*"
)

$jdk17 = $null
foreach ($pattern in $jdk17Candidates) {
    $match = Get-ChildItem $pattern -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending |
        Select-Object -First 1
    if ($match) {
        $jdk17 = $match.FullName
        break
    }
}

if ($jdk17) {
    $env:CORDOVA_JAVA_HOME = $jdk17
    $env:JAVA_HOME = $jdk17
    $env:PATH = "$jdk17\bin;$env:PATH"
    [Environment]::SetEnvironmentVariable("CORDOVA_JAVA_HOME", $jdk17, "User")
    [Environment]::SetEnvironmentVariable("JAVA_HOME", $jdk17, "User")
    Write-Host "CORDOVA_JAVA_HOME=$jdk17"
    Write-Host "JAVA_HOME=$jdk17"
} else {
    throw "No se pudo localizar JDK 17 tras la instalacion."
}

& "$jdk17\bin\java.exe" -version

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
    Write-Host ""
    Write-Host "Falta Android SDK Command-line Tools (latest)." -ForegroundColor Red
    Write-Host "Abre Android Studio -> Settings -> Languages & Frameworks -> Android SDK -> SDK Tools." -ForegroundColor Yellow
    Write-Host "Marca 'Android SDK Command-line Tools (latest)' y pulsa Apply."
    Write-Host ""
    Write-Host "Despues vuelve a ejecutar este script."
    exit 1
}

Write-Step "Comprobando Gradle"
if (-not (Get-Command "gradle" -ErrorAction SilentlyContinue)) {
    Write-Step "Instalando Gradle 8.13"

    $gradleVersion = "8.13"
    $gradleBase = Join-Path $env:LOCALAPPDATA "Gradle"
    $gradleHome = Join-Path $gradleBase "gradle-$gradleVersion"
    $gradleZip = Join-Path $env:TEMP "gradle-$gradleVersion-bin.zip"

    if (-not (Test-Path $gradleHome)) {
        New-Item -ItemType Directory -Force -Path $gradleBase | Out-Null
        Invoke-WebRequest -Uri "https://services.gradle.org/distributions/gradle-$gradleVersion-bin.zip" -OutFile $gradleZip
        Expand-Archive -Path $gradleZip -DestinationPath $gradleBase -Force
        Remove-Item $gradleZip -Force -ErrorAction SilentlyContinue
    }

    $gradleBin = Join-Path $gradleHome "bin"
    if (-not (Test-Path (Join-Path $gradleBin "gradle.bat"))) {
        throw "No se encontro gradle.bat tras instalar Gradle $gradleVersion."
    }

    if ($env:PATH -notlike "*$gradleBin*") {
        $env:PATH = "$gradleBin;$env:PATH"
    }

    $gradleUserPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($gradleUserPath -notlike "*$gradleBin*") {
        if ([string]::IsNullOrWhiteSpace($gradleUserPath)) {
            $gradleUserPath = $gradleBin
        } else {
            $gradleUserPath += ";$gradleBin"
        }
        [Environment]::SetEnvironmentVariable("Path", $gradleUserPath, "User")
    }

    [Environment]::SetEnvironmentVariable("GRADLE_HOME", $gradleHome, "User")
    $env:GRADLE_HOME = $gradleHome
}

Require-Command "gradle" "No se pudo instalar Gradle automaticamente."
gradle --version

Write-Step "Instalando dependencias npm"
npm install

Write-Step "Eliminando plugin Cordova obsoleto si aun existe"
try { npx cordova plugin remove cordova-plugin-whitelist | Out-Host } catch {}
try { npm uninstall cordova-plugin-whitelist --no-save | Out-Host } catch {}

Write-Step "Limpiando plataforma Android generada"
if (Test-Path "platforms\android") {
    npx cordova platform remove android
    if ($LASTEXITCODE -ne 0) {
        throw "No se pudo eliminar la plataforma Android existente."
    }
}

Write-Step "Recreando Android 14.0.1 desde config.xml"
npx cordova platform add android@14.0.1
if ($LASTEXITCODE -ne 0) {
    throw "No se pudo agregar cordova-android 14.0.1."
}

Write-Step "Preparando proyecto Android"
npx cordova prepare android
if ($LASTEXITCODE -ne 0) {
    throw "cordova prepare android ha fallado."
}

Write-Step "Comprobando requisitos Cordova"
npx cordova requirements android
if ($LASTEXITCODE -ne 0) {
    throw "Los requisitos de Cordova Android no se cumplen."
}

if (-not $SkipBuild) {
    Write-Step "Compilando APK debug"
    npx cordova build android --debug
    if ($LASTEXITCODE -ne 0) {
        throw "La compilacion de la APK ha fallado."
    }

    $apk = Join-Path (Get-Location) "platforms\android\app\build\outputs\apk\debug\app-debug.apk"
    if (Test-Path $apk) {
        Write-Host ""
        Write-Host "APK generada correctamente:" -ForegroundColor Green
        Write-Host $apk -ForegroundColor White
        Write-Host ""
        Write-Host "Servidor por defecto:" -ForegroundColor Green
        Write-Host "  http://media-server-share:8090" -ForegroundColor White
        Write-Host ""
        Write-Host "Desinstala la APK anterior del movil antes de instalar esta si quieres limpiar completamente los datos antiguos." -ForegroundColor Yellow
    } else {
        throw "La compilacion termino pero no se encontro la APK esperada."
    }
} else {
    Write-Host ""
    Write-Host "Entorno preparado. Compila con:" -ForegroundColor Green
    Write-Host "  npx cordova build android --debug"
}
