# webroot.yaml

A platform-neutral deployment configuration standard for static and JAMstack sites. One file replaces the platform-specific configs you'd otherwise maintain separately for each host. [Learn more](https://claude.ai/share/2742f285-550e-44ce-bec2-d5f1c7bac38a)

| Platform | Files replaced |
|---|---|
| Netlify | `netlify.toml`, `_redirects`, `_headers` |
| Vercel | `vercel.json` + `next.config.js` (hosting layer) |
| Firebase | `firebase.json` (hosting section) |
| Cloudflare | `_headers`, `_redirects`, `wrangler.toml` (routing) |

---

## Fallback chain

At build time, a webroot-aware tool resolves config by merging in priority order:

```
{webroot}/webroot.yaml         ← site-specific overrides (highest priority)
{webroot}/docker/webroot.yaml  ← shared org-wide defaults
```

Site-specific repos only need their own `webroot.yaml` when they override defaults. Secrets always live in `.env` — never in `webroot.yaml`.

---

## Emitter CLI

A `webroot` CLI tool reads `webroot.yaml` and emits the correct platform-specific file:

```bash
npx webroot emit --target netlify     # writes netlify.toml
npx webroot emit --target vercel      # writes vercel.json
npx webroot emit --target firebase    # writes firebase.json (hosting section)
npx webroot emit --target cloudflare  # writes _headers and _redirects
```

Options:

| Flag | Description |
|---|---|
| `--target` | Platform to emit for (required) |
| `--config` | Path to `webroot.yaml` (default: auto-resolved via fallback chain) |
| `--out` | Output directory (default: repo root) |
| `--dry-run` | Print output without writing files |

---

## Field reference

### `site`

Top-level site identity. Override in each repo's `webroot.yaml`.

| Field | Type | Description |
|---|---|---|
| `title` | string | Site display name |
| `description` | string | Short site description |
| `base_url` | string | Canonical full URL including protocol |
| `platform_id` | string | Platform-specific site ID (Firebase site name, Netlify site name, Vercel project name) |

---

### `cms`

Runtime config for Sveltia CMS / Decap CMS. Values are injected into `config.yaml` at deploy time, making `webroot.yaml` the single source of truth for both hosting and CMS behavior.

| Field | Type | Description |
|---|---|---|
| `app_title` | string | Editor UI title |
| `inline_editor` | bool | Show editor inline instead of full-page takeover |
| `logo.show_in_header` | bool | Show logo in CMS header |
| `logo.show_in_intro` | bool | Show logo on CMS intro screen |
| `extra_css` | list | Additional CSS files loaded by the CMS |
| `extra_js` | list | Additional JS files loaded by the CMS |
| `config_cache_ttl` | int | Cache-Control `max-age` in seconds for `/config.yaml` |

Per-page inline override at runtime:
```js
launchCMS({ inline: true, target: '#editPageBtn' })
```

---

### `build`

| Field | Type | Description |
|---|---|---|
| `command` | string | Build command. Empty = no build step (serve static files directly) |
| `publish` | string | Output directory to deploy. Use `"."` for static repos with no build step |
| `base` | string | Monorepo subdirectory. Empty = repo root |
| `node_version` | string | Node.js version for the build environment |
| `ignore` | list | Glob patterns for files excluded from deployment |
| `contexts` | map | Per-context build overrides (`production`, `preview`, `branch`) |

Context keys mirror Netlify's deploy contexts and Vercel's environment targets. A `command` set under `contexts.production` overrides the top-level `command` for production deploys only.

---

### `hosting`

| Field | Type | Description |
|---|---|---|
| `clean_urls` | bool | Serve `/about` instead of `/about.html` |
| `trailing_slash` | bool | Whether to append trailing slashes to URLs |
| `spa_fallback` | bool | Serve `spa_fallback_file` for all unmatched routes |
| `spa_fallback_file` | string | File to serve for unmatched routes (default: `/index.html`) |

---

### `redirects`

A list of redirect rules processed in order. Redirects take precedence over rewrites.

| Field | Type | Description |
|---|---|---|
| `from` | string | Source path. Supports `:param`, `:splat`, and `*` wildcards |
| `to` | string | Destination path or full URL |
| `status` | int | HTTP status code: `301` (permanent), `302` (temporary), `200` (rewrite/proxy) |
| `force` | bool | Redirect even when a file exists at the source path |
| `conditions` | map | Optional match conditions: `branch`, `cookie`, `country` |

Status `200` in a redirect entry is treated as a proxy rewrite (URL unchanged in browser). Use the `rewrites` section for clarity — both are equivalent.

---

### `rewrites`

Proxy rules. The browser URL does not change. Listed after redirects; redirects take precedence.

| Field | Type | Description |
|---|---|---|
| `from` | string | Source path pattern |
| `to` | string | Destination path, URL, or `function:name` for a serverless function |
| `status` | int | Should be `200` for rewrites |
| `spa_fallback` | bool | Hint to emitters: this rule is the SPA catch-all fallback |

The SPA fallback rule (`from: "/*"`) must always be last in the list.

---

### `headers`

A list of header rules applied in order. More specific path patterns should appear before broader ones.

| Field | Type | Description |
|---|---|---|
| `for` | string | Path pattern. Supports `**` glob wildcards |
| `values` | map | Header key → value pairs |

Common patterns:

| Path | Purpose |
|---|---|
| `/**` | Global security headers |
| `/static/**` | Long-cache immutable assets |
| `/api/**` | CORS + no-cache for API routes |
| `/config.yaml` | Short TTL for CMS config |
| `/**/*.{json,csv,yaml,yml}` | Open CORS for data files |

---

### `functions`

| Field | Type | Description |
|---|---|---|
| `directory` | string | Source directory for serverless functions |
| `runtime` | string | Default runtime (e.g. `nodejs20`) |
| `routes` | list | Per-function overrides (match pattern, name, memory, max_duration) |

Equivalent to `[functions]` in `netlify.toml` and `"functions"` in `vercel.json`. Functions referenced in `rewrites` via `function:name` must have a matching entry here.

---

### `environment`

Non-secret environment variables, safe to commit. Organized by deploy context.

```yaml
environment:
  production:
    NODE_ENV: "production"
  preview:
    NODE_ENV: "development"
  development:
    NODE_ENV: "development"
```

Secrets (API keys, tokens, passwords) belong in `.env` and are never placed here. See `docker/.env.example` for the full secrets reference.

---

### `dev`

Local development server configuration.

| Field | Type | Description |
|---|---|---|
| `port` | int | Port the webroot dev server listens on |
| `target_port` | int | Port your framework dev server runs on (proxied) |
| `command` | string | Command to start your dev server. Empty = static file server |

Equivalent to `[dev]` in `netlify.toml` and `devCommand` in `vercel.json`.

---

### `i18n`

| Field | Type | Description |
|---|---|---|
| `enabled` | bool | Enable internationalization rewrites |
| `default_locale` | string | Default locale code |
| `locales` | list | All supported locale codes |
| `root` | string | Root path for the default locale |

---

### `plugins`

A list of build plugin packages with optional inputs. Equivalent to `[[plugins]]` in `netlify.toml`.

```yaml
plugins:
  - package: "@org/webroot-plugin-sitemap"
    inputs:
      base_url: "https://example.com"
```

---

## Design notes

**Why YAML and not TOML?** The existing CMS ecosystem (`config.yaml`, GitHub Actions, Docker Compose, Kubernetes) is already YAML. Consistency reduces cognitive overhead. TOML's hierarchy via dot-notation becomes harder to read at scale, and tooling for scripting TOML changes (`yq` equivalent) is less mature. The main YAML gotcha — implicit boolean typing of values like `NO` or `yes` — does not affect the key names used in this spec. Always use quoted strings for values where ambiguity could arise.

**Why not JSON?** No comment support. Comments are load-bearing in a config standard meant to be read and edited by humans.

**Emitter, not runtime.** `webroot.yaml` is a build-time source of truth, not a runtime config format. Platform-specific files are generated from it and committed or written during CI. This means existing platform tooling (Netlify CLI, Vercel CLI, Firebase CLI) continues to work unchanged.

**Relationship to `.env`.** `webroot.yaml` is the public half of site configuration. `.env` is the private half. Neither replaces the other.
