# ConjunApp App (Residentes)

Aplicación Flutter para residentes de conjuntos residenciales.

## Stack

- Flutter / Dart (`>=3.6.0 <4.0.0`)
- Provider
- http + flutter_secure_storage

## Instalación

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:8000/api/v1
```

### Emulador Android (API en Docker/host)

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

## Variables

No hay `.env` cargado en runtime. Usa `--dart-define=API_BASE_URL=...`.
Plantilla documentada en `.env.example`.

## Docker

El flujo diario de la app es con el SDK Flutter en el host. El monorepo levanta API + admin con Compose.

Build web opcional:

```bash
docker build -f Dockerfile.web -t conjunapp-app-web \
  --build-arg API_BASE_URL=http://localhost:8000/api/v1 .
```

## Credenciales demo

`ana@example.com` / `residente123`

## Documentación

[../docs/App.md](../docs/App.md)
