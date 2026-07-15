# ConjunApp App (Residentes)

Aplicación Flutter para residentes de conjuntos residenciales.

## Stack

- Flutter / Dart (`>=3.6.0 <4.0.0`)
- Provider
- http + flutter_secure_storage

## Probar en el navegador (recomendado)

Con el monorepo en marcha:

```bash
# desde la raíz Conjuntos
docker compose up --build resident
```

Abre http://localhost:5174  
Login: `ana@example.com` / `residente123`

## Instalación nativa (móvil / desktop)

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:8000/api/v1
```

### Emulador Android (API en Docker/host)

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

### Chrome local (sin Docker de la app)

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000/api/v1
```

## Variables

No hay `.env` cargado en runtime. Usa `--dart-define=API_BASE_URL=...` o el build-arg `API_BASE_URL` / `RESIDENT_API_BASE_URL` en Compose.

## Docker

| Archivo | Uso |
|---------|-----|
| `Dockerfile.web` | Build release web → nginx |
| `nginx.conf` | SPA + `/health` |

## Credenciales demo

`ana@example.com` / `residente123`

## Documentación

[../docs/App.md](../docs/App.md)
