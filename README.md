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
http://media-server-share:8088
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
