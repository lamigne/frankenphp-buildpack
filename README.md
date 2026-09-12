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

### 1. Create `Aptfile` in your app root

Copy [example.Aptfile](example.Aptfile) to install PHP CLI:

```bash
cp example.Aptfile Aptfile
```

The minimal Aptfile is:
```
php-cli
```

### 2. Create `.buildpacks` file in your app:

Copy [example.buildpacks](example.buildpacks):

```
https://github.com/Scalingo/apt-buildpack
https://github.com/YOUR_USERNAME/frankenphp-buildpack
```

**Important:** Order matters! apt buildpack must come **before** FrankenPHP buildpack.

### 3. Commit and deploy:

```bash
git add .buildpacks Aptfile
git commit -m "Use FrankenPHP buildpack with apt for PHP CLI"
git push scalingo main
```

## How It Works

The buildpack uses a **hybrid approach** with two buildpacks:

### 1. APT Buildpack (runs first)
- Reads `Aptfile` from your app
- Installs system packages (e.g., `php-cli`)

### 2. FrankenPHP Buildpack (runs second)
The buildpack consists of three scripts:

- **`bin/detect`** — Detects FrankenPHP projects (checks for `Caddyfile` + `composer.json`)
- **`bin/compile`** — 
  - Verifies PHP CLI is available (from apt buildpack)
  - Detects system architecture and libc type
  - Downloads FrankenPHP binary from GitHub releases
  - Downloads and installs Composer
  - Runs `composer install --no-dev --optimize-autoloader`
  - Creates application directories (storage, bootstrap/cache for Laravel)
- **`bin/release`** — Specifies the default process: `frankenphp run --config /app/Caddyfile`

## Build Process

When you deploy with both buildpacks:

```
git push scalingo main
  ↓
1. APT Buildpack: Install packages from Aptfile (php-cli, etc.)
  ↓
2. FrankenPHP Buildpack detects Caddyfile + composer.json
  ↓
3. Download FrankenPHP binary (latest release)
4. Download Composer
5. Run: php composer install --no-dev --optimize-autoloader
6. Setup app directories
  ↓
Application starts with: frankenphp run --config /app/Caddyfile
```

## Typical Project Structure

Your FrankenPHP app needs:

```
your-app/
├── .buildpacks         # Points to both buildpacks (required)
├── Aptfile             # APT packages (php-cli, etc.) (required)
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
