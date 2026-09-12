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

That's it! The buildpack automatically:
- Parses your `composer.json` for PHP version
- Downloads FrankenPHP binary
- Downloads PHP CLI from ondrej/php repository
- Installs Composer
- Runs `composer install`

## How It Works

### Completely Self-Contained

The buildpack handles everything without external dependencies:

1. **Detects FrankenPHP projects** (checks for `Caddyfile` + `composer.json`)
2. **Parses `composer.json`** for PHP version requirement (e.g., `"php": ">=8.4"`)
3. **Downloads FrankenPHP binary** from GitHub releases
4. **Downloads PHP CLI** from ondrej/php repository (matches your PHP version)
5. **Extracts PHP binary** from .deb package
6. **Downloads Composer**
7. **Runs `composer install`** with the PHP version your app needs
8. **Creates application directories** (storage, bootstrap/cache for Laravel)

### Build Process

```
git push scalingo main
  ↓
FrankenPHP Buildpack runs
  ↓
1. Parse composer.json → detect PHP 8.4 needed
2. Download FrankenPHP binary (latest)
3. Download PHP 8.4 from ondrej/php
4. Extract PHP CLI binary
5. Download Composer
6. Run: php composer install --no-dev --optimize-autoloader
7. Setup app directories
  ↓
Application starts with: frankenphp run --config /app/Caddyfile
```

## Typical Project Structure

Your FrankenPHP app needs:

```
your-app/
├── .buildpacks         # Points to FrankenPHP buildpack (required)
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
web: /app/bin/frankenphp run --config /app/Caddyfile --adapter cgi
```

Or copy the buildpack's Procfile:

```bash
cp node_modules/.bin/../../../Procfile .  # Adjust path to buildpack
# Then edit as needed
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
