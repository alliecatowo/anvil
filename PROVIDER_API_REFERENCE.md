# PROVIDER_API_REFERENCE.md
# Real Provider API Reference for Anvil

Concrete endpoint URLs, request/response shapes, and auth patterns for each provider. Use this when implementing `AnvilInfrastructure` adapters.

---

## 1. Vercel

**Base URL:** `https://api.vercel.com`

**Auth:** HTTP Bearer token in every request header.
```
Authorization: Bearer <VERCEL_TOKEN>
```
Tokens are created at vercel.com/account/tokens. For team resources, append `?teamId=<TEAM_ID>` or `?slug=<TEAM_SLUG>` to every request.

**OpenAPI spec (machine-readable):** https://openapi.vercel.sh/

---

### 1.1 List Deployments

```
GET /v6/deployments
```

**Query parameters (all optional):**

| Parameter | Type | Description |
|---|---|---|
| `projectId` | string | Filter by project ID or name |
| `state` | string | `BUILDING`, `ERROR`, `INITIALIZING`, `QUEUED`, `READY`, `CANCELED` |
| `target` | string | `production` or `staging` |
| `limit` | number | Max results (default 20) |
| `since` | number | JS timestamp — deployments after this time |
| `until` | number | JS timestamp — deployments before this time |
| `branch` | string | Filter by git branch name |

**Example response (200):**
```json
{
  "deployments": [
    {
      "uid": "dpl_abc123",
      "name": "my-app",
      "projectId": "prj_xyz",
      "url": "my-app-abc123.vercel.app",
      "created": 1700000000000,
      "state": "READY",
      "readyState": "READY",
      "target": "production",
      "source": "git",
      "creator": {
        "uid": "user_123",
        "email": "user@example.com",
        "username": "username"
      },
      "meta": {
        "githubCommitSha": "abc123def456",
        "githubCommitMessage": "feat: add new feature",
        "githubCommitAuthorName": "Developer"
      },
      "inspectorUrl": "https://vercel.com/team/project/dpl_abc123",
      "isRollbackCandidate": true
    }
  ],
  "pagination": {
    "count": 20,
    "next": 1699000000000,
    "prev": null
  }
}
```

---

### 1.2 Get Deployment Build Logs (Events)

```
GET /v3/deployments/{idOrUrl}/events
```

**Path parameters:**
- `idOrUrl` (required) — Deployment UID (`dpl_abc123`) or hostname

**Query parameters:**

| Parameter | Type | Description |
|---|---|---|
| `follow` | `0` or `1` | When `1`, returns a live stream (`application/stream+json`) |
| `limit` | number | Max events. `-1` returns all |
| `direction` | `forward` or `backward` | Default: `forward` |
| `since` | number | Timestamp to start from |
| `until` | number | Timestamp to end at |

**Response (200, JSON array):**
```json
[
  {
    "type": "command",
    "created": 1700000001000,
    "payload": {
      "deploymentId": "dpl_abc123",
      "id": "log_001",
      "date": 1700000001000,
      "serial": "0000000001",
      "text": "Running build command: npm run build",
      "info": {
        "type": "build",
        "name": "build",
        "step": "build"
      }
    }
  },
  {
    "type": "stdout",
    "created": 1700000002000,
    "payload": {
      "deploymentId": "dpl_abc123",
      "id": "log_002",
      "date": 1700000002000,
      "serial": "0000000002",
      "text": "> next build"
    }
  },
  {
    "type": "exit",
    "created": 1700000060000,
    "payload": {
      "deploymentId": "dpl_abc123",
      "id": "log_999",
      "date": 1700000060000,
      "serial": "0000000999",
      "statusCode": 0
    }
  }
]
```

Log event `type` values: `delimiter`, `command`, `stdout`, `stderr`, `exit`, `deployment-state`, `fatal`

For streaming: set `follow=1` and read `application/stream+json` — each line is a JSON object.

---

### 1.3 List Environment Variables

```
GET /v10/projects/{idOrName}/env
```

**Path parameters:**
- `idOrName` (required) — Project ID (e.g. `prj_xyz`) or project name

**Query parameters:**

| Parameter | Type | Description |
|---|---|---|
| `decrypt` | `true` or `false` | Return decrypted values |
| `gitBranch` | string | Filter preview vars for a specific branch |

**Response (200):**
```json
{
  "envs": [
    {
      "id": "env_abc123",
      "key": "DATABASE_URL",
      "value": "postgresql://...",
      "type": "encrypted",
      "target": ["production", "preview"],
      "createdAt": 1700000000000,
      "updatedAt": 1700000000000
    },
    {
      "id": "env_def456",
      "key": "NEXT_PUBLIC_API_URL",
      "value": "https://api.example.com",
      "type": "plain",
      "target": ["production", "preview", "development"]
    }
  ],
  "pagination": {
    "count": 2,
    "next": null,
    "prev": null
  }
}
```

Env var `type` values: `plain`, `encrypted`, `sensitive`, `secret`, `system`

---

### 1.4 Create Environment Variable

```
POST /v10/projects/{idOrName}/env
```

**Query parameters:**
- `upsert=true` — Update existing var instead of failing if key already exists

**Request body:**
```json
{
  "key": "MY_SECRET",
  "value": "supersecret",
  "type": "encrypted",
  "target": ["production", "preview"]
}
```

Or create multiple at once by passing an array:
```json
[
  { "key": "VAR_ONE", "value": "val1", "type": "plain", "target": ["development"] },
  { "key": "VAR_TWO", "value": "val2", "type": "encrypted", "target": ["production"] }
]
```

**Response (201):**
```json
{
  "created": {
    "id": "env_newid",
    "key": "MY_SECRET",
    "value": "supersecret",
    "type": "encrypted",
    "target": ["production", "preview"],
    "createdAt": 1700000000000
  },
  "failed": []
}
```

---

### 1.5 Delete Environment Variable

```
DELETE /v10/projects/{idOrName}/env/{id}
```

Returns `200` with the deleted env var object, or `404` if not found.

---

### 1.6 Trigger a Redeploy

There is no "redeploy" endpoint directly. The pattern is to create a new deployment pointing at the same git commit. Use the Vercel SDK or the Vercel dashboard for redeployment. Rollback to a prior deployment uses:

```
PATCH /v12/deployments/{id}/rollback
```

---

## 2. Sentry

**Base URL:** `https://sentry.io`

**Auth:** Bearer token with appropriate scope.
```
Authorization: Bearer <SENTRY_AUTH_TOKEN>
```
Tokens are created at sentry.io/settings/account/api/auth-tokens/. Select the minimal required scopes (see each endpoint below).

**Pagination:** Sentry uses `Link` response headers for cursor-based pagination:
```
Link: <https://sentry.io/api/0/.../issues/?cursor=0:25:0>; rel="next"
```

---

### 2.1 List Organization Projects

```
GET /api/0/organizations/{org_slug}/projects/
```

**Required scope:** `org:read`

**Query parameters:**
- `cursor` — Pagination cursor from previous response `Link` header

**Example response (200):**
```json
[
  {
    "id": "3",
    "slug": "my-backend",
    "name": "My Backend",
    "platform": "python-django",
    "dateCreated": "2023-01-15T10:00:00Z",
    "firstEvent": "2023-01-16T08:30:00Z",
    "hasAccess": true,
    "isMember": true,
    "isBookmarked": false,
    "team": {
      "id": "2",
      "name": "Backend Team",
      "slug": "backend-team"
    },
    "environments": ["production", "staging"],
    "features": ["releases", "alert-filters"],
    "hasSessions": true,
    "hasReplays": true
  }
]
```

---

### 2.2 List Project Issues

```
GET /api/0/projects/{org_slug}/{project_slug}/issues/
```

**Required scope:** `event:read`

**Query parameters:**

| Parameter | Type | Description |
|---|---|---|
| `query` | string | Sentry structured search, e.g. `is:unresolved` (default) |
| `statsPeriod` | string | `24h`, `14d`, or empty to disable |
| `cursor` | string | Pagination cursor |
| `limit` | number | Max results per page |

**Note:** This endpoint is deprecated in favor of the Organization Issues endpoint:
```
GET /api/0/organizations/{org_slug}/issues/
```
Use the organization endpoint for new implementations.

**Example response (200):**
```json
[
  {
    "id": "123456",
    "shortId": "MY-BACKEND-1A2B",
    "title": "ZeroDivisionError: division by zero",
    "culprit": "app.views.calculate in divide",
    "level": "error",
    "status": "unresolved",
    "count": "47",
    "userCount": 12,
    "firstSeen": "2024-01-10T08:00:00Z",
    "lastSeen": "2024-01-15T14:30:00Z",
    "isBookmarked": false,
    "isSubscribed": true,
    "hasSeen": false,
    "annotations": [],
    "assignedTo": null,
    "project": {
      "id": "3",
      "name": "My Backend",
      "slug": "my-backend"
    },
    "metadata": {
      "type": "ZeroDivisionError",
      "value": "division by zero",
      "filename": "app/views.py"
    },
    "permalink": "https://sentry.io/organizations/my-org/issues/123456/"
  }
]
```

---

### 2.3 Retrieve an Issue (with detail)

```
GET /api/0/organizations/{org_slug}/issues/{issue_id}/
```

**Required scope:** `event:read`

**Example response (200):**
```json
{
  "id": "123456",
  "shortId": "MY-BACKEND-1A2B",
  "title": "ZeroDivisionError: division by zero",
  "culprit": "app.views.calculate in divide",
  "level": "error",
  "status": "unresolved",
  "count": "47",
  "userCount": 12,
  "firstSeen": "2024-01-10T08:00:00Z",
  "lastSeen": "2024-01-15T14:30:00Z",
  "project": {
    "id": "3",
    "name": "My Backend",
    "slug": "my-backend"
  },
  "activity": [
    {
      "id": "0",
      "type": "first_seen",
      "dateCreated": "2024-01-10T08:00:00Z",
      "user": null,
      "data": {}
    }
  ]
}
```

---

### 2.4 List Issue Events (with stack traces)

```
GET /api/0/organizations/{org_slug}/issues/{issue_id}/events/
```

**Required scope:** `event:read`

**Query parameters:**
- `full=true` — Include full event body with stack traces (critical: omit this and you only get a summary)

**Example response (200) with `full=true`:**
```json
[
  {
    "id": "event_abc123",
    "eventID": "abc123def456abc123def456abc123de",
    "groupID": "123456",
    "timestamp": "2024-01-15T14:30:00Z",
    "message": "ZeroDivisionError: division by zero",
    "level": "error",
    "platform": "python",
    "tags": [
      {"key": "environment", "value": "production"},
      {"key": "release", "value": "1.2.3"}
    ],
    "exception": {
      "values": [
        {
          "type": "ZeroDivisionError",
          "value": "division by zero",
          "stacktrace": {
            "frames": [
              {
                "filename": "app/views.py",
                "absPath": "/app/app/views.py",
                "module": "app.views",
                "function": "calculate",
                "lineNo": 42,
                "colNo": 12,
                "contextLine": "    return numerator / denominator",
                "preContext": [
                  "def calculate(numerator, denominator):",
                  "    # Perform division"
                ],
                "postContext": [
                  "",
                  "def another_func():"
                ],
                "inApp": true
              }
            ]
          }
        }
      ]
    },
    "user": {
      "id": "user_789",
      "email": "user@example.com",
      "ipAddress": "1.2.3.4"
    },
    "request": {
      "url": "https://app.example.com/api/calculate",
      "method": "POST",
      "data": {"numerator": 10, "denominator": 0}
    }
  }
]
```

---

### 2.5 Update Issue Status

```
PUT /api/0/organizations/{org_slug}/issues/{issue_id}/
```

**Required scope:** `event:write`

**Request body:**
```json
{ "status": "resolved" }
```

Valid status values: `resolved`, `resolvedInNextRelease`, `unresolved`, `ignored`

---

## 3. Slack

**Base URL:** `https://slack.com/api`

**Auth:** OAuth 2.0 Bearer token (bot token `xoxb-...` or user token `xoxp-...`).
```
Authorization: Bearer xoxb-your-bot-token
```

All methods accept `Content-Type: application/json` for POST requests. GET methods accept query parameters. The token can also be passed as a query parameter `?token=xoxb-...` but header auth is preferred.

**All responses include an `ok` boolean.** On failure, `ok` is `false` and an `error` string is present:
```json
{ "ok": false, "error": "not_in_channel" }
```

**Rate limits:** Most read methods are Tier 3 (50+ calls/minute). `chat.postMessage` is limited to 1 per second per channel.

---

### 3.1 List Channels

```
GET https://slack.com/api/conversations.list
```

**Required scopes:** `channels:read` (public), `groups:read` (private), `im:read` (DMs), `mpim:read` (group DMs)

**Query parameters:**

| Parameter | Type | Description |
|---|---|---|
| `types` | string | Comma-separated: `public_channel`, `private_channel`, `im`, `mpim`. Default: `public_channel` |
| `limit` | number | Max results per page (default 100, max 1000) |
| `cursor` | string | Pagination cursor from `response_metadata.next_cursor` |
| `exclude_archived` | boolean | Exclude archived channels |

**Example response (200):**
```json
{
  "ok": true,
  "channels": [
    {
      "id": "C012AB3CD",
      "name": "general",
      "is_channel": true,
      "is_private": false,
      "is_archived": false,
      "is_general": true,
      "is_member": true,
      "created": 1449252889,
      "creator": "U012A3CDE",
      "num_members": 42,
      "topic": {
        "value": "Company-wide announcements",
        "creator": "U012A3CDE",
        "last_set": 1449452889
      },
      "purpose": {
        "value": "This channel is for team-wide communication",
        "creator": "",
        "last_set": 0
      }
    }
  ],
  "response_metadata": {
    "next_cursor": "dGVhbTpDMDYxRkE1UEI="
  }
}
```

To paginate: repeat the call with `cursor=<next_cursor value>` until `next_cursor` is empty.

---

### 3.2 Post a Message

```
POST https://slack.com/api/chat.postMessage
Content-Type: application/json
Authorization: Bearer xoxb-your-bot-token
```

**Required scope:** `chat:write`

**Request body:**
```json
{
  "channel": "C012AB3CD",
  "text": "Hello from Anvil!",
  "blocks": [
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "*Deployment complete* :rocket:\n>Branch: `main`\n>Status: READY"
      }
    }
  ]
}
```

The `text` field is required as a fallback for notifications. `blocks` is used for rich formatting.

**Example response (200):**
```json
{
  "ok": true,
  "channel": "C012AB3CD",
  "ts": "1503435956.000247",
  "message": {
    "type": "message",
    "text": "Hello from Anvil!",
    "bot_id": "B123ABC456",
    "ts": "1503435956.000247"
  }
}
```

The returned `ts` (timestamp) is the message ID — store it if you need to update or delete the message later.

---

### 3.3 Fetch Channel History

```
GET https://slack.com/api/conversations.history
```

**Required scopes:** `channels:history` (public), `groups:history` (private), `im:history` (DMs)

**Query parameters:**

| Parameter | Type | Description |
|---|---|---|
| `channel` | string | **Required.** Channel ID (e.g. `C012AB3CD`) |
| `limit` | number | Max messages (default 100, max 999) |
| `oldest` | string | Unix timestamp — messages after this time |
| `latest` | string | Unix timestamp — messages before this time |
| `cursor` | string | Pagination cursor |
| `include_all_metadata` | boolean | Include message metadata |

**Example response (200):**
```json
{
  "ok": true,
  "messages": [
    {
      "type": "message",
      "user": "U012A3CDE",
      "text": "Has anyone seen the deployment logs?",
      "ts": "1512085950.000216"
    },
    {
      "type": "message",
      "bot_id": "B123ABC456",
      "text": "Deployment complete",
      "ts": "1512085900.000100",
      "blocks": [...]
    }
  ],
  "has_more": true,
  "pin_count": 0,
  "response_metadata": {
    "next_cursor": "bmV4dF90czoxNTEyMDg1ODYxMDAwNTQz"
  }
}
```

**Note:** Message `ts` values are Unix timestamps as strings with microsecond precision. They serve as unique message IDs and are used for threading (`thread_ts`).

---

### 3.4 Post Threaded Reply

To reply in a thread, include `thread_ts` pointing to the parent message's `ts`:

```json
{
  "channel": "C012AB3CD",
  "thread_ts": "1503435956.000247",
  "text": "This is a reply in the thread"
}
```

---

## 4. Docker Engine API

**Base URL (Unix socket):** Connect via Unix domain socket at `/var/run/docker.sock`

The Docker daemon listens on a Unix socket by default. HTTP requests go to `http://localhost/vX.XX/...` routed through the socket. The current stable API version is **v1.47** (Docker 27+). v1.45 is supported for backward compatibility.

**No authentication by default** on the Unix socket — access is controlled by filesystem permissions on the socket file (`root:docker` group). For remote TCP, TLS mutual auth is used, but for local Mac implementations, Unix socket is standard.

**Swift implementation note:** Use `URLSession` with a custom `URLProtocol` or `URLSessionConfiguration` that targets the Unix socket. Alternatively, shell out to `curl --unix-socket /var/run/docker.sock http://localhost/v1.47/...` for a simpler implementation.

```bash
# Test the socket is accessible:
curl -s --unix-socket /var/run/docker.sock http://localhost/v1.47/version
```

---

### 4.1 List Containers

```
GET /v1.47/containers/json
```

**Query parameters:**

| Parameter | Type | Description |
|---|---|---|
| `all` | boolean | Include stopped containers. Default `false` (running only) |
| `limit` | number | Max containers to return |
| `filters` | JSON string | Filter by status, name, label, etc. |
| `size` | boolean | Include container sizes |

**Example curl:**
```bash
curl -s --unix-socket /var/run/docker.sock \
  "http://localhost/v1.47/containers/json?all=true"
```

**Example response (200):**
```json
[
  {
    "Id": "8dfafdbc3a40",
    "Names": ["/webapp"],
    "Image": "nginx:latest",
    "ImageID": "sha256:abc123...",
    "Command": "nginx -g 'daemon off;'",
    "Created": 1367854155,
    "Status": "Up 2 hours",
    "State": "running",
    "Ports": [
      {"IP": "0.0.0.0", "PrivatePort": 80, "PublicPort": 8080, "Type": "tcp"}
    ],
    "Labels": {
      "com.example.project": "myproject"
    },
    "Mounts": [
      {
        "Type": "bind",
        "Source": "/host/path",
        "Destination": "/container/path",
        "Mode": "rw",
        "RW": true
      }
    ],
    "NetworkSettings": {
      "Networks": {
        "bridge": {
          "IPAddress": "172.17.0.2",
          "Gateway": "172.17.0.1"
        }
      }
    }
  }
]
```

Container `State` values: `created`, `restarting`, `running`, `paused`, `exited`, `dead`

---

### 4.2 Get Container Logs

```
GET /v1.47/containers/{id}/logs
```

**Path parameters:**
- `id` — Container ID or name

**Query parameters:**

| Parameter | Type | Description |
|---|---|---|
| `stdout` | boolean | Include stdout. Default `false` |
| `stderr` | boolean | Include stderr. Default `false` |
| `follow` | boolean | Stream logs. Default `false` |
| `timestamps` | boolean | Prepend timestamps. Default `false` |
| `tail` | string | Number of lines from end: `"100"` or `"all"` |
| `since` | integer | Unix timestamp — show logs since this time |
| `until` | integer | Unix timestamp — show logs until this time |

**Example curl (last 100 lines with timestamps):**
```bash
curl -s --unix-socket /var/run/docker.sock \
  "http://localhost/v1.47/containers/webapp/logs?stdout=true&stderr=true&tail=100&timestamps=true"
```

**Example curl (streaming, follow mode):**
```bash
curl -s --unix-socket /var/run/docker.sock \
  "http://localhost/v1.47/containers/webapp/logs?stdout=true&stderr=true&follow=true"
```

**Response format:** The response is a binary multiplexed stream, not plain text. Each "frame" has an 8-byte header:
- Byte 0: Stream type (`0` = stdin, `1` = stdout, `2` = stderr)
- Bytes 1-3: Unused (zeros)
- Bytes 4-7: Frame size (big-endian uint32)
- Remaining: The log line bytes

In practice, for terminal display you can strip the 8-byte header prefix from each line. If using the TTY attach mode (`/containers/{id}/attach`), the stream is raw with no framing.

---

### 4.3 Start a Container

```
POST /v1.47/containers/{id}/start
```

**Path parameters:**
- `id` — Container ID or name

**Request body:** Empty or omit.

**Responses:**
- `204` — Container started successfully
- `304` — Container was already running
- `404` — Container not found
- `500` — Server error

**Example curl:**
```bash
curl -s -X POST --unix-socket /var/run/docker.sock \
  "http://localhost/v1.47/containers/webapp/start"
```

---

### 4.4 Stop a Container

```
POST /v1.47/containers/{id}/stop
```

**Query parameters:**
- `t` (integer) — Seconds to wait before killing. Default is the container's `StopTimeout` setting (10s).
- `signal` (string) — Signal to send. Default `SIGTERM`.

**Responses:**
- `204` — Container stopped successfully
- `304` — Container was already stopped
- `404` — Container not found

**Example curl:**
```bash
curl -s -X POST --unix-socket /var/run/docker.sock \
  "http://localhost/v1.47/containers/webapp/stop?t=10"
```

---

### 4.5 Inspect a Container (full metadata)

```
GET /v1.47/containers/{id}/json
```

Returns comprehensive container info including config, state, network, mounts, environment variables. Useful for displaying container details in a dashboard.

**Key response fields:**
```json
{
  "Id": "8dfafdbc3a40...",
  "Name": "/webapp",
  "Created": "2024-01-15T10:30:00Z",
  "State": {
    "Status": "running",
    "Running": true,
    "Pid": 12345,
    "StartedAt": "2024-01-15T10:30:01Z",
    "FinishedAt": "0001-01-01T00:00:00Z"
  },
  "Config": {
    "Image": "nginx:latest",
    "Env": ["PATH=/usr/local/sbin:/usr/local/bin", "NGINX_VERSION=1.25.0"],
    "Cmd": ["nginx", "-g", "daemon off;"],
    "ExposedPorts": {"80/tcp": {}}
  },
  "HostConfig": {
    "PortBindings": {
      "80/tcp": [{"HostIp": "0.0.0.0", "HostPort": "8080"}]
    },
    "RestartPolicy": {"Name": "unless-stopped"}
  },
  "NetworkSettings": {
    "Ports": {
      "80/tcp": [{"HostIp": "0.0.0.0", "HostPort": "8080"}]
    },
    "IPAddress": "172.17.0.2"
  }
}
```

---

### 4.6 Swift URLSession + Unix Socket

The Docker socket is not directly supported by `URLSession`. The implementation options in Swift are:

**Option A — Shell out to curl (simplest):**
```swift
// In DockerProvider:
func runDockerAPIRequest(path: String) async throws -> Data {
    let result = try await Process.run(
        "/usr/bin/curl",
        arguments: ["-s", "--unix-socket", "/var/run/docker.sock",
                    "http://localhost\(path)"]
    )
    return result.stdout
}
```

**Option B — Use a Swift Docker client library** (e.g. `SwiftDockerClient` on GitHub, wraps the socket with `Network.framework`).

**Option C — Network.framework `NWConnection` with Unix socket:**
```swift
// Connect to a Unix domain socket:
let endpoint = NWEndpoint.unix(path: "/var/run/docker.sock")
let connection = NWConnection(to: endpoint, using: .tcp)
```

For macOS 15+ in a sandboxed app, you need the `com.apple.security.network.client` entitlement and the socket file must be within a permitted path. Docker Desktop on Mac exposes the socket at `/var/run/docker.sock` (symlink to `~/.docker/run/docker.sock`).

---

## Summary: Auth Token Storage

For the Anvil keychain adapter, store tokens with these service identifiers:

| Provider | Keychain Service Key | Token Format |
|---|---|---|
| Vercel | `anvil.vercel.token` | Plain bearer token string |
| Sentry | `anvil.sentry.token` | Plain bearer token string |
| Sentry | `anvil.sentry.org` | Organization slug string |
| Slack | `anvil.slack.token` | `xoxb-...` bot token |
| Docker | N/A | No token — socket permissions only |

All tokens should be stored with `kSecAttrAccessibleWhenUnlocked` and retrieved via `SecItemCopyMatching`.
