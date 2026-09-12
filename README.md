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

### 1. Create `Aptfile` in your app root

Copy and customize [example.Aptfile](example.Aptfile) to install PHP, Caddy, and dependencies:

```bash
cp example.Aptfile Aptfile
# Edit Aptfile to adjust PHP version and extensions as needed
```

### 2. Create `.buildpacks` file in your app:

```
https://github.com/scalingo/buildpack-apt
https://github.com/YOUR_USERNAME/frankenphp-buildpack
```

**Important:** Order matters! apt buildpack must come **before** FrankenPHP buildpack.

### 3. Commit and deploy:

```bash
git add .buildpacks Aptfile
git commit -m "Use APT + FrankenPHP buildpacks"
git push scalingo main
```

## How It Works

### Multi-Buildpack Approach

1. **APT Buildpack** (runs first)
   - Installs system packages from `Aptfile` (PHP, Caddy, Composer, etc.)

2. **FrankenPHP Buildpack** (runs second)
   - Detects FrankenPHP project (has `Caddyfile`)
   - Installs PHP dependencies via Composer
   - Prepares the application

### FrankenPHP Buildpack Scripts

- **`bin/detect`** — Returns 0 if `Caddyfile` exists
- **`bin/compile`** — Installs composer dependencies, prepares app directories
- **`bin/release`** — Specifies the default web process: `frankenphp run --config /app/Caddyfile`

## Typical Project Structure

Your FrankenPHP app should have:

```
your-app/
├── Caddyfile           # Caddy configuration (required)
├── public/             # Web root
├── app/                # Your PHP code
├── composer.json       # PHP dependencies (required)
├── composer.lock       # Lock file
├── .buildpacks         # Points to APT + FrankenPHP buildpacks
└── Aptfile             # System packages to install
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
