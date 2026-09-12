# Custom Docker Buildpack

This directory contains a minimal buildpack that forces Scalingo to use the Dockerfile instead of auto-detecting the PHP buildpack.

## How It Works

1. **`bin/detect`** - Checks if `Dockerfile` exists. If yes, claims this buildpack (prevents PHP auto-detection)
2. **`bin/compile`** - No-op script (Scalingo's Docker builder handles the build)
3. **`bin/release`** - Specifies the Procfile command to run

## Why This Is Needed

Scalingo auto-detects buildpacks based on file contents:
- `composer.json` → PHP buildpack
- `package.json` → Node buildpack
- etc.

Since our project has `composer.json`, Scalingo's PHP buildpack was claiming the app instead of using our Dockerfile. This custom buildpack has higher priority and prevents that.

## Buildpack Detection Order

When `.buildpacks` file exists, Scalingo runs each buildpack's `bin/detect` script in order:
1. If `detect` returns exit code 0 → buildpack is used
2. If `detect` returns non-zero → next buildpack is tried

Our buildpack returns 0 if `Dockerfile` exists, preventing PHP buildpack from running.
