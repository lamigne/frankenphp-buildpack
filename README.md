# FrankenPHP buildpack for Scalingo (FrankenPHP + Mercure + Ember)

A [Scalingo](https://scalingo.com) buildpack that installs the [FrankenPHP](https://frankenphp.dev) application server and the complementary [Ember](https://github.com/alexandre-daubois/ember) monitoring TUI on top of Scalingo's official PHP buildpack.

It is a thin layer: **PHP, Composer and your dependencies come from the PHP
buildpack**; this buildpack only adds the binaries that run and monitor the
app.

If you think this buildpack could be useful to others, feel free to ⭐️ the repository or contribute.

## What gets installed

| Binary                | Source                                                                                                                                                 | Notes                                                                                                      |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------- |
| `/app/bin/frankenphp` | latest [FrankenPHP release](https://github.com/dunglas/frankenphp/releases) (static build matching the host arch/libc, `linux-x86_64-gnu` on Scalingo) | Caddy + PHP in one process. Ships the [Mercure](https://mercure.rocks) hub and the `hash-password` command |
| `/app/bin/ember`      | latest [Ember release](https://github.com/alexandre-daubois/ember/releases), SHA-256 verified                                                          | Real-time TUI / Prometheus exporter for Caddy & FrankenPHP. Optional, see [Ember](#monitoring-with-ember)  |

Both are added to `PATH` at container boot by `/app/.profile.d/frankenphp.sh`,
so `frankenphp` and `ember` are available in `scalingo run` one-off containers
too.

## Installation

Create a `.buildpacks` file at the root of your app (see
[`example.buildpacks`](example.buildpacks)):

```
https://github.com/Scalingo/php-buildpack
https://github.com/lamigne/frankenphp-buildpack
```

Then commit and deploy:

```bash
git add .buildpacks
git commit -m "Use PHP and FrankenPHP buildpacks"
git push scalingo main
```

**The order matters:**

1. **PHP buildpack** runs first: installs the PHP CLI matching `composer.json`,
   installs Composer and runs `composer install`.
2. **FrankenPHP buildpack** runs second: installs the FrankenPHP and Ember
   binaries, checks that `vendor/` exists and registers the start commands.

> Scalingo fetches the buildpack from the `main` branch of this repository at
> **build time**. If you fork it, point `.buildpacks` at your fork; changes to
> the buildpack only take effect on the next app rebuild.

## How it works

### `bin/detect`

The buildpack applies when the app root contains both a `Caddyfile` and a
`composer.json`.

### `bin/compile`

1. Reads the PHP requirement from `composer.json` (informational, the PHP
   buildpack is the one installing PHP).
2. Detects the architecture and libc, downloads the latest FrankenPHP binary
   to `/app/bin/frankenphp`.
3. Installs Ember to `/app/bin/ember` (unless `EMBER_INSTALL=false`), verifying
   the archive against the release's `checksums.txt`.
4. Warns if `vendor/autoload.php` is missing (the PHP buildpack did not run or
   `composer install` failed).
5. Creates `storage/` and `bootstrap/cache/` (Laravel) if absent.
6. Writes `/app/.profile.d/frankenphp.sh`, sourced at every container boot,
   which extends `PATH` and sizes the
   [PHP thread pool](#php-thread-pool-sizing).

### `bin/release`

Declares the default process type:

```yaml
web: /app/bin/frankenphp run --config /app/Caddyfile
```

A `Procfile` in your app overrides it, and is where you add other process
types, e.g. the `tcp` process of the
[multi-container Ember setup](#option-3-several-web-containers-ember-daemon-in-a-tcp-process):

```
web: /app/bin/frankenphp run --config /app/Caddyfile
tcp: /app/bin/ember-daemon
```

## Project structure

```
your-app/
├── .buildpacks         # PHP buildpack + this buildpack (required)
├── Caddyfile           # FrankenPHP / Caddy config (required, see example.Caddyfile)
├── composer.json       # PHP dependencies (required)
├── composer.lock
├── Procfile            # optional, overrides/extends the default web process
├── bin/ember-daemon    # optional, tcp process of the Ember daemon setup
├── public/             # web root (index.php, assets)
└── src/ or app/        # your code
```

## Caddyfile

Start from [`example.Caddyfile`](example.Caddyfile) and save it as `Caddyfile`
at the root of your app. The parts that matter on Scalingo:

- **Listen on `$PORT`**: Scalingo assigns the public port through the `PORT`
  environment variable and kills the container if nothing binds to it within
  60 seconds. Use `:{$PORT:8080}` as the site address (the `8080` fallback is
  for local runs) and `bind 0.0.0.0`.
- **`auto_https off`**: TLS is terminated by Scalingo's router; the container
  only speaks HTTP.
- **`admin localhost:2019`**: keep Caddy's admin API on loopback. Ember reads
  everything through this API; see [Ember](#monitoring-with-ember) for how to
  reach it.
- **`log { output stdout }`**: Scalingo collects stdout, so `scalingo logs`
  shows Caddy's and FrankenPHP's logs.

Validate it locally before pushing:

```bash
frankenphp validate --config Caddyfile
```

FrankenPHP on Scalingo is always the latest release, which may be newer than
your local install: directives deprecated remotely can still validate locally.

### Custom PHP configuration

Place a `php.ini` in your app root; FrankenPHP picks it up.

## PHP thread pool sizing

FrankenPHP defaults to `2 x CPUs` PHP threads. On Scalingo, containers see every
core of the host and have no CPU quota (only a CPU _priority_ per size), so an
S container on an 8-core host would start 16 threads while having 256 MB of RAM
for all of them. Memory, not CPU, is the real limit.

At every container boot, `/app/.profile.d/frankenphp.sh` derives a thread pool
from `CONTAINER_MEMORY` (injected by Scalingo) and exports:

| Env var                     | Rule                                                                                               |
| --------------------------- | -------------------------------------------------------------------------------------------------- |
| `FRANKENPHP_NUM_THREADS`    | always-on threads: `RAM / 64 MB`, min 2, max `2 x CPUs`                                            |
| `FRANKENPHP_MAX_THREADS`    | burst ceiling: `RAM / 32 MB`, max `4 x CPUs`, never below `num_threads`                            |
| `FRANKENPHP_WORKER_THREADS` | `num_threads - 1` (FrankenPHP requires `num_threads` to be strictly greater than the worker count) |

Which gives, on an 8-core host:

| Container size | RAM    | `num_threads` | `max_threads` | `worker` threads |
| -------------- | ------ | ------------- | ------------- | ---------------- |
| S              | 256 MB | 4             | 8             | 3                |
| M              | 512 MB | 8             | 16            | 7                |
| L              | 1 GB   | 16            | 32            | 15               |
| XL and above   | 2 GB+  | 16 (CPU cap)  | 32 (CPU cap)  | 15               |

Reference the values in your Caddyfile; the fallbacks only apply outside
Scalingo, where `CONTAINER_MEMORY` is not set:

```
{
	frankenphp {
		num_threads {$FRANKENPHP_NUM_THREADS:4}
		max_threads {$FRANKENPHP_MAX_THREADS:8}
		# optional: recycle threads after N requests
		max_requests {$FRANKENPHP_MAX_REQUESTS:500}
	}
}

:{$PORT:8080} {
	root * /app/public
	php_server {
		# optional worker mode (Symfony >= 8.1 supports it out of the box via
		# symfony/runtime; Laravel needs Octane)
		worker {
			file /app/public/index.php
			num {$FRANKENPHP_WORKER_THREADS:3}
		}
	}
}
```

To override, set any of `FRANKENPHP_NUM_THREADS`, `FRANKENPHP_MAX_THREADS` or
`FRANKENPHP_WORKER_THREADS` on the app (`scalingo env-set`). Values you set are
kept as-is; the script only fills in the missing ones and raises `max_threads`
to `num_threads` if needed. The 64 MB budget per thread is conservative for a
typical Symfony/Laravel request (20-40 MB); lower it in the script if your app
is lighter.

## Mercure

The FrankenPHP binary embeds the [Mercure](https://mercure.rocks) hub, so
server-sent events need no extra process. Enable it inside the site block:

```
mercure {
	publisher_jwt {$MERCURE_JWT_SECRET:!ChangeThisMercureHubJWTSecretKey!}
	subscriber_jwt {$MERCURE_JWT_SECRET:!ChangeThisMercureHubJWTSecretKey!}
	anonymous
	# Scalingo's router closes idle connections after 59s
	heartbeat 30s
	# in-memory transport: fine for a single web container
	transport local
}
```

The hub answers at `/.well-known/mercure`. Set `MERCURE_JWT_SECRET` on the app
(`scalingo env-set MERCURE_JWT_SECRET=...`) and use the same value in your
framework's Mercure configuration. With several web containers, `transport
local` means each node only knows its own subscribers; switch to a shared
transport (e.g. Redis) if updates must reach every subscriber.

## Monitoring with Ember

[Ember](https://github.com/alexandre-daubois/ember) is a terminal UI for Caddy
and FrankenPHP: per-host traffic, latency percentiles, status codes, and, when
FrankenPHP is detected, per-thread introspection, worker restarts and memory
tracking. It can also run headless as a Prometheus exporter.

The buildpack installs it as `/app/bin/ember`:

| Env var         | Default        | Purpose                            |
| --------------- | -------------- | ---------------------------------- |
| `EMBER_INSTALL` | `true`         | Set to `false` to skip the install |
| `EMBER_VERSION` | latest release | Pin a version, e.g. `1.6.1`        |

### Prerequisites in the Caddyfile

Ember only needs Caddy's **admin API** (`localhost:2019`). Two additions make
it useful on Scalingo:

1. Turn on HTTP metrics (opt-in since Caddy 2.8), otherwise Ember has nothing
   to show:

   ```
   {
   	admin localhost:2019
   	metrics {
   		per_host
   	}
   }
   ```

2. Expose the admin API to Ember. Scalingo only routes `$PORT` to the internet
   and the admin API listens on loopback, so it has to be proxied. The admin
   API can reconfigure the whole server: **always** put basic auth in front of
   it when it is reachable from the public URL.

   ```
   :{$PORT:8080} {
   	# ...
   	handle_path /ember-admin/* {
   		route {
   			basic_auth {
   				{$EMBER_USER:ember} {$EMBER_PASSWORD_HASH:$2a$14$2OBVCEzzn90dtayNjVF7HeOfrslQblvl.yME7.DhHPQ/HRTmCrlKG}
   			}
   			# don't log Ember's polling (several requests per second)
   			log_skip
   			reverse_proxy localhost:2019 {
   				# the admin API only accepts requests whose Host matches its listen address
   				header_up Host {upstream_hostport}
   			}
   		}
   	}
   	php_server
   }
   ```

   The default hash belongs to a random, discarded password, so the endpoint
   stays locked until you configure it:

   ```bash
   frankenphp hash-password --plaintext 'a-strong-password'
   scalingo env-set EMBER_PASSWORD_HASH='$2a$14$...'
   ```

   Ember polls the admin API several times per second; exclude `admin.api`
   from the default logger (see [`example.Caddyfile`](example.Caddyfile)) to
   keep `scalingo logs` readable.

### Accessing the Ember TUI

Pick the option that matches how many web containers you run.

#### Option 1: from your machine, through the public URL

Works with **one web container**. Ember accepts credentials in the URL:

```bash
ember --addr https://ember:a-strong-password@your-app.osc-fr1.scalingo.io/ember-admin
```

Install Ember locally with `brew install alexandre-daubois/tap/ember` or from
the [releases page](https://github.com/alexandre-daubois/ember/releases).

With several web containers this still connects, but Scalingo's router
load-balances every poll to a random node, so the numbers jump between
containers. Use option 2 or 3 instead.

#### Option 2: from a one-off container, over the Private Network

Works with **any number of web containers**, no public exposure needed.
Requirements: the app has a
[Private Network](https://doc.scalingo.com/platform/networking/private/overview)
enabled, and the Caddyfile serves the admin proxy on a second, private port
(nothing else listens there and it is only reachable from the Private
Network, hence no basic auth):

```
# Private-network listener for Ember. Scalingo only routes $PORT publicly.
:{$EMBER_PRIVATE_PORT:9000} {
	bind 0.0.0.0
	handle_path /ember-admin/* {
		reverse_proxy localhost:2019 {
			header_up Host {upstream_hostport}
		}
	}
	respond 404
}
```

One-off containers join the Private Network and get the same environment as
the app, and `ember` is on their `PATH`, so:

```bash
scalingo --app your-app run bash

# inside the container: pick a node (1, 2, ... = web-1, web-2, ...)
ember --addr http://1.web.$SCALINGO_APPLICATION_ID.$SCALINGO_PRIVATE_NETWORK_ID.private-network.internal:9000/ember-admin
```

Press `Tab` or `1-9` to switch tabs, `r` to restart the FrankenPHP workers of
that node, `?` for the full key list, `q` to quit. Repeat with `2.web...` for
the next container. `web.<domain>` (no number) resolves to one A record per
web container, which is how you can count them.

#### Option 3: several web containers, Ember daemon in a `tcp` process

For a permanent view of all nodes at once, run Ember headless in a `tcp`
process type declared in your `Procfile`. It polls every web container over the
Private Network and serves one aggregated Prometheus `/metrics` endpoint
(labelled `ember_instance="web_1"`, `web_2`, ...) that the
[TCP Gateway](https://doc.scalingo.com/addons/tcp-gateway) addon
publishes at `$TCP_URL`. Point Prometheus/Grafana at it; there is no TUI in
this mode (use option 2 for that).

Requirements:

- Private Network + TCP Gateway addon on the app
- the private listener from option 2 in the Caddyfile
- `EMBER_METRICS_PASSWORD` set on the app (basic auth for `/metrics`)
- a `bin/ember-daemon` script in your app (below) and a `Procfile` declaring
  `tcp: /app/bin/ember-daemon` next to the `web` line, then
  `scalingo scale tcp:1` (new process types start at 0 containers)

Ember cannot change its target list at runtime, so the script re-resolves the
number of web containers every 30 s and restarts Ember when it changes:

<details>
<summary><code>bin/ember-daemon</code></summary>

```bash
#!/usr/bin/env bash
#
# Starts Ember in daemon mode for the `tcp` process type.
#
# Polls the Caddy admin API of every web container over the Scalingo Private
# Network (each node exposes it on EMBER_PRIVATE_PORT, see Caddyfile) and
# serves an aggregated Prometheus endpoint on $PORT, published by the TCP
# Gateway addon at $TCP_URL:
#
#   curl -u ember:$EMBER_METRICS_PASSWORD http://<host:port from TCP_URL>/metrics
#
# Environment:
#   EMBER_METRICS_PASSWORD  required, basic auth password for /metrics
#   EMBER_METRICS_USER      basic auth user (default: ember)
#   EMBER_WEB_NODES         fixed number of web containers to poll; disables
#                           auto-detection when set
#   EMBER_RESCAN_INTERVAL   seconds between node re-detections (default: 30)
#   EMBER_PRIVATE_PORT      port of the per-node admin proxy (default: 9000)
#   EMBER_INTERVAL          polling interval per node (default: 5s)
set -euo pipefail

: "${PORT:?PORT is not set (this script is meant to run as the tcp process on Scalingo)}"
: "${EMBER_METRICS_PASSWORD:?EMBER_METRICS_PASSWORD is not set; /metrics would be public through the TCP Gateway}"
: "${SCALINGO_APPLICATION_ID:?SCALINGO_APPLICATION_ID is not set}"
: "${SCALINGO_PRIVATE_NETWORK_ID:?SCALINGO_PRIVATE_NETWORK_ID is not set; enable a Private Network on the project}"

domain="${SCALINGO_APPLICATION_ID}.${SCALINGO_PRIVATE_NETWORK_ID}.private-network.internal"
private_port="${EMBER_PRIVATE_PORT:-9000}"
rescan="${EMBER_RESCAN_INTERVAL:-30}"

log() { echo "ember-daemon: $*"; }

# Number of web containers: EMBER_WEB_NODES if set, else one A record per
# container behind the unnumbered private name.
resolve_nodes() {
    if [ -n "${EMBER_WEB_NODES:-}" ]; then
        echo "$EMBER_WEB_NODES"
        return
    fi
    local n
    n=$(getent ahosts "web.${domain}" 2>/dev/null | awk '{print $1}' | sort -u | wc -l | tr -d ' ')
    if [ "${n:-0}" -lt 1 ]; then
        log "could not resolve web.${domain}, assuming 1 web node (set EMBER_WEB_NODES to override)" >&2
        n=1
    fi
    echo "$n"
}

ember_pid=""

start_ember() {
    local count=$1 addrs=() i
    for i in $(seq 1 "$count"); do
        # Alias becomes a Prometheus label value: letters, digits and underscores only
        addrs+=(--addr "web_${i}=http://${i}.web.${domain}:${private_port}/ember-admin")
    done
    log "polling ${count} web node(s) on port ${private_port}, exposing /metrics on :${PORT}"
    /app/bin/ember --daemon \
        --expose ":${PORT}" \
        --metrics-auth "${EMBER_METRICS_USER:-ember}:${EMBER_METRICS_PASSWORD}" \
        --interval "${EMBER_INTERVAL:-5s}" \
        "${addrs[@]}" &
    ember_pid=$!
}

stop_ember() {
    if [ -n "$ember_pid" ] && kill -0 "$ember_pid" 2>/dev/null; then
        kill "$ember_pid" 2>/dev/null || true
        wait "$ember_pid" 2>/dev/null || true
    fi
    ember_pid=""
}

# Scalingo stops the container with SIGTERM: pass it on and exit cleanly
trap 'log "stopping"; stop_ember; exit 0' TERM INT

nodes=$(resolve_nodes)
start_ember "$nodes"

# With a fixed node count there is nothing to rescan: just follow Ember
if [ -n "${EMBER_WEB_NODES:-}" ]; then
    wait "$ember_pid"
    exit $?
fi

while true; do
    # `sleep` in the background so the TERM trap fires immediately
    sleep "$rescan" & wait $! || true

    # Ember died on its own: exit non-zero so Scalingo restarts the container
    if ! kill -0 "$ember_pid" 2>/dev/null; then
        wait "$ember_pid" && status=0 || status=$?
        log "ember exited with status ${status}"
        exit "$status"
    fi

    current=$(resolve_nodes)
    if [ "$current" != "$nodes" ]; then
        log "web nodes changed: ${nodes} -> ${current}, restarting ember"
        stop_ember
        nodes=$current
        start_ember "$nodes"
    fi
done
```

</details>

Make it executable (`chmod +x bin/ember-daemon`), add the `tcp` line to your
`Procfile`, commit, then:

```bash
scalingo --app your-app env-set EMBER_METRICS_PASSWORD="$(openssl rand -hex 16)"
scalingo --app your-app scale tcp:1
scalingo --app your-app env | grep TCP_URL     # e.g. tcp://tcp-1.osc-fr1.scalingo.com:22074
curl -u ember:$EMBER_METRICS_PASSWORD http://tcp-1.osc-fr1.scalingo.com:22074/metrics
```

Prometheus scrape config:

```yaml
scrape_configs:
  - job_name: frankenphp
    basic_auth:
      username: ember
      password: <EMBER_METRICS_PASSWORD>
    static_configs:
      - targets: ["tcp-1.osc-fr1.scalingo.com:<SCALINGO_TCP_PORT>"]
```

## Troubleshooting

### Build fails: "Failed to download FrankenPHP"

The binary download from GitHub releases failed. Check the build logs
(`scalingo deployment-logs`) and that
https://github.com/dunglas/frankenphp/releases is reachable, then retry the
deployment.

### Build warns: "vendor/ not found"

The PHP buildpack did not run before this one, or `composer install` failed.
Check the order in `.buildpacks` and the PHP buildpack's output above the
warning.

### Build warns: "Ember checksum mismatch" / "Failed to download Ember"

Ember is optional, so the build continues without `/app/bin/ember`. Pin a
known-good release with `EMBER_VERSION`, or set `EMBER_INSTALL=false` to
silence the warning.

### Deploy fails: "took more than 60 seconds to boot"

Nothing bound to `$PORT`. Your Caddyfile probably hardcodes a port: use
`:{$PORT:8080}` as the site address (see [Caddyfile](#caddyfile)). The same
applies to the `tcp` process: `bin/ember-daemon` passes `--expose :$PORT` for
that reason.

### Ember shows no traffic

Add `metrics { per_host }` to the global options of the Caddyfile; HTTP
metrics are opt-in in Caddy.

### Ember: 401 / "unauthorized" through the public URL

`EMBER_PASSWORD_HASH` is not set (the default hash matches no password) or the
password in `--addr` does not match it. Regenerate with `frankenphp
hash-password` and `scalingo env-set` the result; the app restarts with the new
value.

### App starts but crashes

Run `frankenphp validate --config Caddyfile` locally, check that `public/`
exists and read `scalingo logs --follow`.

## License

MIT

## Resources

- [FrankenPHP documentation](https://frankenphp.dev)
- [Ember](https://github.com/alexandre-daubois/ember)
- [Mercure](https://mercure.rocks/docs)
- [Scalingo buildpacks](https://doc.scalingo.com/platform/deployment/buildpacks)
- [Scalingo Private Network](https://doc.scalingo.com/platform/networking/private/overview)
- [Scalingo TCP Gateway](https://doc.scalingo.com/addons/tcp-gateway)
