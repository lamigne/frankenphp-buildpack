# FrankenPHP Buildpack for Scalingo

A custom buildpack for deploying [FrankenPHP](https://frankenphp.dev) applications on [Scalingo](https://scalingo.com) PaaS.

## Overview

This buildpack enables you to use FrankenPHP with Dockerfile-based deployments on Scalingo. It prevents the default PHP buildpack from interfering with your custom Docker configuration.

## Why This Buildpack?

Scalingo auto-detects buildpacks based on project files:
- `composer.json` → PHP buildpack
- `package.json` → Node buildpack
- `Dockerfile` → Docker builder

If your FrankenPHP app has `composer.json`, Scalingo's PHP buildpack claims the app before your Dockerfile is used. This custom buildpack takes precedence and ensures your Dockerfile is used instead.

## Installation

### 1. Create a `.buildpacks` file in your FrankenPHP app:

```
https://github.com/YOUR_USERNAME/frankenphp-buildpack
```

### 2. Commit and deploy:

```bash
git add .buildpacks
git commit -m "Use FrankenPHP buildpack"
git push scalingo main
```

## How It Works

The buildpack consists of three scripts:

- **`bin/detect`** — Returns 0 if `Dockerfile` exists, preventing PHP buildpack from running
- **`bin/compile`** — No-op script (Scalingo's Docker builder handles compilation)
- **`bin/release`** — Specifies the default web process: `frankenphp run --config /app/Caddyfile`

## Typical Project Structure

Your FrankenPHP app should have:

```
your-app/
├── Dockerfile           # Your FrankenPHP image
├── Caddyfile           # Caddy configuration
├── public/             # Web root
├── app/                # Your PHP code
├── .buildpacks         # Points to this buildpack
└── composer.json       # PHP dependencies
```

## Example Dockerfile

```dockerfile
FROM dunglas/frankenphp:latest

WORKDIR /app
COPY . /app

RUN composer install --no-dev

EXPOSE 8080
CMD ["frankenphp", "run", "--config", "/app/Caddyfile"]
```

## Configuration

### Using a Custom Procfile

If you need a different start command, create a `Procfile` in your app:

```
web: frankenphp run --config /app/Caddyfile --adapter cgi
```

The Procfile takes precedence over the buildpack's default process type.

## Troubleshooting

### Build failing with PHP buildpack error?

Ensure:
1. `.buildpacks` file exists in your app root
2. `Dockerfile` exists in your app root
3. Both files are committed to git

### Wrong process type running?

Check:
1. Your `Procfile` (if it exists)
2. The buildpack's `bin/release` script
3. Scalingo deployment logs: `scalingo logs --follow`

## License

MIT

## Resources

- [FrankenPHP Documentation](https://frankenphp.dev)
- [Scalingo Buildpacks](https://doc.scalingo.com/platform/deployment/buildpacks)
- [Buildpack API](https://doc.scalingo.com/platform/deployment/buildpacks/buildpack-api)
