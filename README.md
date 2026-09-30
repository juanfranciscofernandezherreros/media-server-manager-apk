# Media Server Manager APK

Aplicación Android para acceder de forma privada al panel **Media Server Manager** mediante Tailscale.

## Arquitectura

La APK es un cliente Cordova. El backend FastAPI y el acceso a Docker continúan ejecutándose en el servidor.

```
Android + Tailscale
        |
        v
Media Server Manager (FastAPI)
        |
        v
Docker / Jellyfin / Sonarr / Radarr / Deluge / Gluetun / ...
```

## URL inicial

La app propone por defecto:

```
http://media-server-share.taild3fa5b.ts.net:8090
```

La URL puede cambiarse desde la pantalla de conexión sin recompilar la APK.

## Requisitos de compilación

- Node.js 20+
- Java 17
- Android SDK
- Cordova CLI 12+

## Desarrollo

```bash
npm install
npx cordova platform add android
npx cordova build android
```

APK de debug:

```
platforms/android/app/build/outputs/apk/debug/app-debug.apk
```

## Seguridad

La app no contiene credenciales de NordVPN ni acceso directo a Docker. Solo se comunica con el API del Media Server Manager.

Para usarla remotamente, el dispositivo Android y el servidor deben estar conectados a la misma red Tailscale.


## Instalación automática en Windows

Desde PowerShell:

\`\`\`powershell
Set-ExecutionPolicy -Scope Process Bypass
.\setup-android.ps1
\`\`\`

El script actualiza la rama `main`, detecta y configura Android SDK, instala dependencias npm, elimina plugins Cordova obsoletos, elimina cualquier plataforma Android generada anteriormente, recrea Android 14.0.1 desde `config.xml`, ejecuta `cordova prepare` y genera la APK de debug.

Si solo quieres preparar el entorno sin compilar:

\`\`\`powershell
.\setup-android.ps1 -SkipBuild
\`\`\`


Si quieres ejecutar el proceso sin hacer `git pull`:

```powershell
.\setup-android.ps1 -NoPull
```

La APK generada queda en:

```text
platforms\android\app\build\outputs\apk\debug\app-debug.apk
```
