# FrankenPHP Buildpack for Scalingo

A custom buildpack for deploying [FrankenPHP](https://frankenphp.dev) applications on [Scalingo](https://scalingo.com) PaaS.

## Overview

This buildpack provides a complete, self-contained FrankenPHP deployment solution on Scalingo. It handles:
- Downloading and installing the FrankenPHP binary
- Installing Composer
- Running `composer install` to manage PHP dependencies
- Setting up application directories
- Configuring the start command

## Installation

### 1. Create `.buildpacks` file in your app:

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

1. **`bin/detect`** — Detects FrankenPHP projects (checks for `Caddyfile` + `composer.json`)
2. **`bin/compile`** — 
   - Detects system architecture and libc type
   - Downloads FrankenPHP binary from GitHub releases
   - Downloads and installs Composer
   - Runs `composer install --no-dev --optimize-autoloader`
   - Creates application directories (storage, bootstrap/cache for Laravel)
3. **`bin/release`** — Specifies the default process: `frankenphp run --config /app/Caddyfile`

## Build Process

When you deploy with this buildpack:

```
git push scalingo main
  ↓
Scalingo detects Caddyfile + composer.json
  ↓
FrankenPHP buildpack runs
  ↓
1. Download FrankenPHP binary (latest release)
2. Download Composer
3. Run: composer install --no-dev --optimize-autoloader
4. Setup app directories
  ↓
Application starts with: frankenphp run --config /app/Caddyfile
```

## Typical Project Structure

Your FrankenPHP app needs:

```
your-app/
├── .buildpacks         # Points to this buildpack (required)
├── Caddyfile           # Caddy web server config (required)
├── composer.json       # PHP dependencies (required)
├── composer.lock       # Locked versions
├── public/             # Web root (index.php, assets, etc.)
├── app/                # Your PHP code
├── config/             # Application config
└── storage/            # Writable directory (created by buildpack)
```

## Customization

### Custom FrankenPHP Arguments

To use custom FrankenPHP arguments, create a `Procfile` in your app:

```
web: frankenphp run --config /app/Caddyfile --adapter cgi
```

The Procfile takes precedence over the buildpack's default command.

### Custom PHP Configuration

Place a `php.ini` file in your app root. FrankenPHP will use it if found.

## Troubleshooting

### Build fails: "FrankenPHP binary not found"

The binary download failed. Check:
1. Internet connectivity during build
2. GitHub releases accessible: https://github.com/dunglas/frankenphp/releases
3. Build logs: `scalingo logs --follow`

### Build fails: "Composer install failed"

PHP dependency installation failed. Check:
1. `composer.json` is valid
2. All dependencies are available
3. Disk space available during build

### App starts but crashes

Check:
1. Caddyfile is valid
2. `public/` directory exists
3. File permissions (buildpack creates writable directories)
4. Application logs: `scalingo logs --follow`

## License

MIT

## Resources

- [FrankenPHP Documentation](https://frankenphp.dev)
- [Scalingo Buildpacks](https://doc.scalingo.com/platform/deployment/buildpacks)
- [Buildpack API](https://doc.scalingo.com/platform/deployment/buildpacks/buildpack-api)
