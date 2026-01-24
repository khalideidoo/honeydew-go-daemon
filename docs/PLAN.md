# Honeydew Go Daemon - Architecture Plan

## Overview

A Go-based daemon application that provides command queuing and scheduling capabilities. It communicates with a CLI application via Unix sockets using gRPC/protobuf and calls the Honeydew API (GraphQL over HTTPS).

## Architecture

```
┌─────────────┐     Unix Socket      ┌─────────────────────────────────────┐
│   CLI App   │◄───────────────────► │           Daemon                    │
└─────────────┘       gRPC           │                                     │
                                     │  ┌─────────────────────────────┐    │
                                     │  │      gRPC Server            │    │
                                     │  │   (Unix Socket Listener)    │    │
                                     │  └─────────────┬───────────────┘    │
                                     │                │                    │
                                     │  ┌─────────────▼───────────────┐    │
                                     │  │      Command Queue          │    │
                                     │  │      & Scheduler            │    │
                                     │  └─────────────┬───────────────┘    │
                                     │                │                    │
                                     │  ┌─────────────▼───────────────┐    │
                                     │  │    Honeydew API Client      │    │
                                     │  │        (GraphQL)            │    │
                                     │  └─────────────┬───────────────┘    │
                                     │                │                    │
                                     │  ┌─────────────▼───────────────┐    │
                                     │  │      SQLite Storage         │    │
                                     │  │   (Jobs, State, Config)     │    │
                                     │  └─────────────────────────────┘    │
                                     └────────────────┼────────────────────┘
                                                      │
                                         HTTPS        │
                                     ┌────────────────▼────────────────┐
                                     │        Honeydew API             │
                                     │          (GraphQL)              │
                                     └─────────────────────────────────┘
```

## Dependencies

| Package | Purpose |
|---------|---------|
| `google.golang.org/grpc` | gRPC framework for CLI-daemon communication |
| `google.golang.org/protobuf` | Protocol buffers runtime |
| `modernc.org/sqlite` | Pure Go SQLite driver for persistent storage |
| `github.com/robfig/cron/v3` | Cron-based job scheduling |
| `golang.org/x/oauth2` | OAuth 2.0 client for API authentication |
| `golang.org/x/crypto` | Argon2 key derivation, AES-GCM token encryption |
| `github.com/Khan/genqlient` | Type-safe GraphQL client generation |

## Project Structure

```
honeydew-go-daemon/
├── cmd/
│   └── daemon/
│       └── main.go              # Daemon entry point
├── internal/
│   ├── daemon/
│   │   └── daemon.go            # Daemon lifecycle management
│   ├── grpc/
│   │   ├── server.go            # gRPC server setup (Unix socket)
│   │   └── handlers.go          # RPC method implementations
│   ├── queue/
│   │   ├── queue.go             # Command queue implementation
│   │   └── worker.go            # Queue worker/executor
│   ├── scheduler/
│   │   └── scheduler.go         # Cron-based scheduler wrapper
│   ├── storage/
│   │   ├── sqlite.go            # SQLite connection and migrations
│   │   ├── jobs.go              # Job persistence
│   │   └── config.go            # Configuration storage
│   ├── api/
│   │   └── honeydew/
│   │       ├── client.go        # Honeydew GraphQL client setup
│   │       └── generated/       # genqlient generated code
│   ├── auth/
│   │   ├── oauth.go             # OAuth 2.0 flow handling
│   │   └── tokens.go            # Token encryption/storage
│   └── crypto/
│       └── encryption.go        # AES-GCM encryption, Argon2 KDF
├── api/
│   └── proto/
│       └── daemon.proto         # gRPC service definitions
├── graphql/
│   ├── schema.graphql           # GraphQL schema (for genqlient)
│   └── genqlient.yaml           # genqlient configuration
├── migrations/
│   └── 001_initial.sql          # SQLite schema migrations
├── go.mod
├── go.sum
└── Makefile
```

## Core Components

### 1. gRPC Server (Unix Socket)

**Location:** `internal/grpc/`

The gRPC server listens on a Unix socket for CLI commands.

**Socket path:** `~/.honeydew/daemon.sock` (or configurable)

**Service definition (`api/proto/daemon.proto`):**
```protobuf
syntax = "proto3";
package honeydew;

service Daemon {
  // ─────────────────────────────────────────────────────────────
  // Job Management (async execution)
  // ─────────────────────────────────────────────────────────────
  rpc SubmitJob(SubmitJobRequest) returns (SubmitJobResponse);
  rpc CancelJob(CancelJobRequest) returns (CancelJobResponse);
  rpc GetJobStatus(GetJobStatusRequest) returns (JobStatus);
  rpc ListJobs(ListJobsRequest) returns (ListJobsResponse);

  // ─────────────────────────────────────────────────────────────
  // Scheduling (cron-based)
  // ─────────────────────────────────────────────────────────────
  rpc ScheduleJob(ScheduleJobRequest) returns (ScheduleJobResponse);
  rpc UnscheduleJob(UnscheduleJobRequest) returns (UnscheduleJobResponse);
  rpc ListSchedules(ListSchedulesRequest) returns (ListSchedulesResponse);

  // ─────────────────────────────────────────────────────────────
  // Authentication (Honeydew API)
  // ─────────────────────────────────────────────────────────────
  rpc Login(LoginRequest) returns (LoginResponse);
  rpc Logout(LogoutRequest) returns (LogoutResponse);
  rpc GetAuthStatus(GetAuthStatusRequest) returns (AuthStatus);

  // ─────────────────────────────────────────────────────────────
  // Environment Management
  // ─────────────────────────────────────────────────────────────
  rpc AddEnvironment(AddEnvironmentRequest) returns (AddEnvironmentResponse);
  rpc RemoveEnvironment(RemoveEnvironmentRequest) returns (RemoveEnvironmentResponse);
  rpc ListEnvironments(ListEnvironmentsRequest) returns (ListEnvironmentsResponse);
  rpc SetActiveEnvironment(SetActiveEnvironmentRequest) returns (SetActiveEnvironmentResponse);
  rpc GetActiveEnvironment(GetActiveEnvironmentRequest) returns (GetActiveEnvironmentResponse);

  // ─────────────────────────────────────────────────────────────
  // Honeydew API - Organizations
  // ─────────────────────────────────────────────────────────────
  rpc ListOrganizations(ListOrganizationsRequest) returns (ListOrganizationsResponse);

  // ─────────────────────────────────────────────────────────────
  // Honeydew API - GitHub
  // ─────────────────────────────────────────────────────────────
  rpc GitHubListRepositories(GitHubListRepositoriesRequest) returns (GitHubListRepositoriesResponse);
  rpc GitHubGetCommits(GitHubGetCommitsRequest) returns (GitHubGetCommitsResponse);
  rpc GitHubGetPullRequests(GitHubGetPullRequestsRequest) returns (GitHubGetPullRequestsResponse);
  rpc GitHubCloneRepository(GitHubCloneRepositoryRequest) returns (GitHubCloneRepositoryResponse);

  // ─────────────────────────────────────────────────────────────
  // Honeydew API - GitLab
  // ─────────────────────────────────────────────────────────────
  rpc GitLabListProjects(GitLabListProjectsRequest) returns (GitLabListProjectsResponse);
  rpc GitLabGetCommits(GitLabGetCommitsRequest) returns (GitLabGetCommitsResponse);
  rpc GitLabGetMergeRequests(GitLabGetMergeRequestsRequest) returns (GitLabGetMergeRequestsResponse);
  rpc GitLabCloneRepository(GitLabCloneRepositoryRequest) returns (GitLabCloneRepositoryResponse);

  // ─────────────────────────────────────────────────────────────
  // Honeydew API - Jira
  // ─────────────────────────────────────────────────────────────
  rpc JiraListProjects(JiraListProjectsRequest) returns (JiraListProjectsResponse);
  rpc JiraGetIssues(JiraGetIssuesRequest) returns (JiraGetIssuesResponse);

  // ─────────────────────────────────────────────────────────────
  // Honeydew API - Linear
  // ─────────────────────────────────────────────────────────────
  rpc LinearListTeams(LinearListTeamsRequest) returns (LinearListTeamsResponse);
  rpc LinearListProjects(LinearListProjectsRequest) returns (LinearListProjectsResponse);
  rpc LinearGetIssues(LinearGetIssuesRequest) returns (LinearGetIssuesResponse);

  // ─────────────────────────────────────────────────────────────
  // Honeydew API - Bitbucket
  // ─────────────────────────────────────────────────────────────
  rpc BitbucketListWorkspaces(BitbucketListWorkspacesRequest) returns (BitbucketListWorkspacesResponse);
  rpc BitbucketListRepositories(BitbucketListRepositoriesRequest) returns (BitbucketListRepositoriesResponse);
  rpc BitbucketGetCommits(BitbucketGetCommitsRequest) returns (BitbucketGetCommitsResponse);
  rpc BitbucketCloneRepository(BitbucketCloneRepositoryRequest) returns (BitbucketCloneRepositoryResponse);

  // ─────────────────────────────────────────────────────────────
  // Daemon Control
  // ─────────────────────────────────────────────────────────────
  rpc Ping(PingRequest) returns (PingResponse);
  rpc Shutdown(ShutdownRequest) returns (ShutdownResponse);
  rpc GetStatus(GetStatusRequest) returns (DaemonStatus);
}
```

### API Method Behavior

All Honeydew API methods (GitHub*, GitLab*, Jira*, etc.) follow the async execution model:

1. **CLI calls method** (e.g., `GitHubGetCommits`)
2. **Daemon creates a job** internally with command type and parameters
3. **Response returns job_id** immediately
4. **Worker executes** the corresponding GraphQL query against Honeydew API
5. **CLI polls `GetJobStatus`** to retrieve results

Example flow for `GitHubGetCommits`:
```
CLI                              Daemon                           Honeydew API
 │                                  │                                  │
 │  GitHubGetCommits(org, repo)     │                                  │
 │─────────────────────────────────►│                                  │
 │                                  │  queue job: github.commits       │
 │  Response(job_id)                │                                  │
 │◄─────────────────────────────────│                                  │
 │                                  │                                  │
 │                                  │  worker: githubCommits(...)      │
 │                                  │─────────────────────────────────►│
 │                                  │                                  │
 │                                  │  GraphQL response                │
 │                                  │◄─────────────────────────────────│
 │                                  │                                  │
 │  GetJobStatus(job_id)            │  store result                    │
 │─────────────────────────────────►│                                  │
 │                                  │                                  │
 │  JobStatus(completed, commits)   │                                  │
 │◄─────────────────────────────────│                                  │
```

### Command Type Mapping

Each gRPC method maps to an internal command type:

**Remote API Commands:**

| gRPC Method | Command Type | Execution Target |
|-------------|--------------|------------------|
| `Login` | `auth.login` | Honeydew GraphQL `login` mutation |
| `GitHubListRepositories` | `github.repositories` | Honeydew GraphQL `githubRepositories` query |
| `GitHubGetCommits` | `github.commits` | Honeydew GraphQL `githubCommits` query |
| `GitHubGetPullRequests` | `github.pullRequests` | Honeydew GraphQL `githubPullRequests` query |
| `GitHubCloneRepository` | `github.clone` | Honeydew GraphQL `githubCloneRepository` mutation |
| `GitLabListProjects` | `gitlab.projects` | Honeydew GraphQL `gitlabProjects` query |
| `GitLabGetCommits` | `gitlab.commits` | Honeydew GraphQL `gitlabCommits` query |
| `GitLabGetMergeRequests` | `gitlab.mergeRequests` | Honeydew GraphQL `gitlabMergeRequests` query |
| `JiraListProjects` | `jira.projects` | Honeydew GraphQL `jiraProjects` query |
| `JiraGetIssues` | `jira.issues` | Honeydew GraphQL `jiraIssues` query |
| `LinearListTeams` | `linear.teams` | Honeydew GraphQL `linearTeams` query |
| `LinearGetIssues` | `linear.issues` | Honeydew GraphQL `linearIssues` query |
| `BitbucketListRepositories` | `bitbucket.repositories` | Honeydew GraphQL `bitbucketRepositories` query |
| `BitbucketGetCommits` | `bitbucket.commits` | Honeydew GraphQL `bitbucketCommits` query |

### 2. Command Queue

**Location:** `internal/queue/`

In-memory queue with SQLite persistence for durability.

**Features:**
- Priority-based ordering
- Concurrent worker pool
- Retry with exponential backoff
- Job state persistence (survives daemon restart)

**Job states:** `pending` → `running` → `completed` | `failed` | `cancelled`

## Command Execution Model

All command execution is **asynchronous**. The daemon never blocks on command execution - instead, jobs are queued and processed by a worker pool.

### Immediate Command Flow

```
┌─────────┐                         ┌────────────────┐                         ┌────────────┐
│   CLI   │                         │     Daemon     │                         │  External  │
│         │                         │                │                         │    API     │
└────┬────┘                         └───────┬────────┘                         └─────┬──────┘
     │                                      │                                        │
     │  1. SubmitJob(command, payload)      │                                        │
     │─────────────────────────────────────►│                                        │
     │                                      │                                        │
     │                                      │  Create job (status: pending)          │
     │                                      │  Persist to SQLite                     │
     │                                      │  Add to in-memory queue                │
     │                                      │                                        │
     │  2. SubmitJobResponse(job_id)        │                                        │
     │◄─────────────────────────────────────│                                        │
     │                                      │                                        │
     │                                      │  3. Worker picks up job                │
     │                                      │     Update status: running             │
     │                                      │                                        │
     │                                      │  4. Execute command                    │
     │                                      │─────────────────────────────────────►  │
     │                                      │                                        │
     │                                      │  5. API response                       │
     │                                      │◄─────────────────────────────────────  │
     │                                      │                                        │
     │                                      │  6. Update status: completed           │
     │                                      │     Store result in SQLite             │
     │                                      │                                        │
     │  7. GetJobStatus(job_id)             │                                        │
     │─────────────────────────────────────►│                                        │
     │                                      │                                        │
     │  8. JobStatus(completed, result)     │                                        │
     │◄─────────────────────────────────────│                                        │
     │                                      │                                        │
```

### CLI Polling Pattern

The CLI can poll for job completion using `GetJobStatus`:

```go
// CLI pseudo-code for waiting on job completion
func waitForJob(client DaemonClient, jobID string) (*Result, error) {
    for {
        status, err := client.GetJobStatus(ctx, &GetJobStatusRequest{JobId: jobID})
        if err != nil {
            return nil, err
        }

        switch status.Status {
        case "completed":
            return status.Result, nil
        case "failed":
            return nil, errors.New(status.Error)
        case "cancelled":
            return nil, errors.New("job was cancelled")
        case "pending", "running":
            time.Sleep(pollInterval)
            continue
        }
    }
}
```

### Priority-Based Execution

Jobs are executed in priority order (higher priority first). When submitting a job:

| Priority | Use Case |
|----------|----------|
| 0 (default) | Normal background tasks |
| 1-10 | Elevated priority for user-initiated actions |
| 100+ | Urgent tasks that should execute immediately |

Workers always pick the highest-priority pending job from the queue.

### 3. Scheduler

**Location:** `internal/scheduler/`

Wraps `robfig/cron/v3` for cron-based job scheduling.

**Features:**
- Standard cron expression support
- Named schedules for easy management
- Persistence of schedule definitions
- Automatic job submission on trigger

### 4. Storage Layer

**Location:** `internal/storage/`

SQLite database using `modernc.org/sqlite` (pure Go, no CGO).

**Database path:** `~/.honeydew/daemon.db`

**Schema:**
```sql
-- Jobs table
CREATE TABLE jobs (
    id TEXT PRIMARY KEY,
    command TEXT NOT NULL,
    payload BLOB,
    priority INTEGER DEFAULT 0,
    status TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    started_at DATETIME,
    completed_at DATETIME,
    result BLOB,
    error TEXT,
    retry_count INTEGER DEFAULT 0,
    max_retries INTEGER DEFAULT 3
);

-- Schedules table
CREATE TABLE schedules (
    id TEXT PRIMARY KEY,
    name TEXT UNIQUE NOT NULL,
    cron_expr TEXT NOT NULL,
    command TEXT NOT NULL,
    payload BLOB,
    enabled INTEGER DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_run_at DATETIME,
    next_run_at DATETIME
);

-- Configuration table
CREATE TABLE config (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

-- API environments table
-- Stores Honeydew API URLs for different environments (production, development, etc.)
CREATE TABLE api_environments (
    id TEXT PRIMARY KEY,
    name TEXT UNIQUE NOT NULL,         -- e.g., 'production', 'development', 'staging'
    base_url TEXT NOT NULL,            -- e.g., 'https://api.honeydew.mobilecapital.net/graphql'
    is_active INTEGER DEFAULT 0,       -- 1 if this is the currently active environment
    description TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Active environment tracking (only one active at a time)
CREATE INDEX idx_api_environments_active ON api_environments(is_active);

-- Auth tokens table (encrypted)
-- Stores Honeydew access and refresh tokens per environment
CREATE TABLE auth_tokens (
    id TEXT PRIMARY KEY,
    environment_id TEXT NOT NULL,      -- FK to api_environments.id
    username TEXT,

    -- Access token (encrypted with AES-GCM)
    encrypted_access_token BLOB NOT NULL,
    access_token_expires_at DATETIME,

    -- Refresh token (encrypted with AES-GCM)
    encrypted_refresh_token BLOB,
    refresh_token_expires_at DATETIME,

    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(environment_id, username),
    FOREIGN KEY (environment_id) REFERENCES api_environments(id)
);
```

### 5. Honeydew API Client

**Location:** `internal/api/honeydew/`

- Uses `genqlient` for type-safe GraphQL queries/mutations
- Schema-first approach with generated Go code
- Automatic authentication header injection
- Token refresh handling

#### Environment Management

The Honeydew API supports multiple environments (production, development) with different base URLs.

**Environments:**
```
├── production  (active) → https://api.honeydew.mobilecapital.net/graphql
└── development          → https://honeydew-api-test-560149296060.us-east1.run.app/graphql
```

**Concepts:**
- Only one environment is **active** at a time
- Auth tokens are **scoped to an environment** (different credentials per environment)
- Switching environments requires re-authentication if no stored tokens exist

**gRPC Methods:**

| Method | Description |
|--------|-------------|
| `AddEnvironment` | Register a new environment URL |
| `RemoveEnvironment` | Remove an environment (fails if active) |
| `ListEnvironments` | List all environments |
| `SetActiveEnvironment` | Switch to a different environment |
| `GetActiveEnvironment` | Get the currently active environment |

**AddEnvironment request:**
```protobuf
message AddEnvironmentRequest {
  string name = 1;          // e.g., "development"
  string base_url = 2;      // e.g., "https://honeydew-api-test-560149296060.us-east1.run.app/graphql"
  string description = 3;   // optional description
  bool set_active = 4;      // immediately set as active environment
}
```

**SetActiveEnvironment behavior:**
1. Looks up environment by name
2. Marks it as active (deactivates previous)
3. Checks for existing auth tokens for this environment
4. Returns `needs_auth: true` if no valid tokens exist

**CLI workflow:**
```bash
# Add development environment
honeydew env add development https://honeydew-api-test-560149296060.us-east1.run.app/graphql

# List environments
honeydew env list
# Output:
#   production (active) - https://api.honeydew.mobilecapital.net/graphql
#   development         - https://honeydew-api-test-560149296060.us-east1.run.app/graphql

# Switch to development
honeydew env use development
# Output: Switched to development. Please login: honeydew login

# Login to development environment
honeydew login
```

### 6. Authentication & Security

**Location:** `internal/auth/` and `internal/crypto/`

**Honeydew Authentication:**
- Username/password login via GraphQL `login` mutation
- Token refresh via `refreshToken` mutation
- Secure token storage per environment

**Encryption:**
- AES-256-GCM for token encryption at rest
- Argon2id for key derivation from user password/system key
- Tokens never stored in plaintext

#### Authentication for Scheduled Jobs

Scheduled jobs run without user interaction and need automatic token management:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Scheduled Job Authentication Flow                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  1. Scheduler triggers job                                              │
│           │                                                             │
│           ▼                                                             │
│  2. Worker retrieves auth tokens from SQLite                            │
│           │                                                             │
│           ▼                                                             │
│  3. Check: Is access_token expired or expiring within 5 min?            │
│           │                                                             │
│     ┌─────┴─────┐                                                       │
│    No          Yes                                                      │
│     │           │                                                       │
│     │           ▼                                                       │
│     │   4. Use refresh_token to call refreshToken mutation              │
│     │           │                                                       │
│     │           ▼                                                       │
│     │   5. Store new tokens (encrypted) in SQLite                       │
│     │           │                                                       │
│     └─────┬─────┘                                                       │
│           │                                                             │
│           ▼                                                             │
│  6. Execute API call with valid access_token                            │
│           │                                                             │
│           ▼                                                             │
│  7. Store result, update job status                                     │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

**Token refresh strategy:**

| Mechanism | Description |
|-----------|-------------|
| **Proactive refresh** | Refresh if access token expires within 5 minutes |
| **Automatic retry** | If API returns 401, refresh token and retry once |
| **Refresh token expiry** | If refresh token expired, job fails with `AUTH_EXPIRED` |
| **Background refresh** | Daemon can periodically check and refresh tokens |

**Failure scenarios:**

| Scenario | Behavior | Job Error Code |
|----------|----------|----------------|
| Access token expired, refresh token valid | Auto-refresh, continue | (none) |
| Access token expired, refresh token expired | Job fails | `AUTH_EXPIRED` |
| API returns 401 after successful refresh | Job fails | `AUTH_INVALID` |
| Network error during token refresh | Retry with backoff, then fail | `AUTH_NETWORK_ERROR` |

**CLI notification:**

When authentication fails for scheduled jobs:
1. Job is marked as failed with auth error code
2. `GetAuthStatus` RPC returns `needs_reauth: true`
3. CLI can prompt user to re-login when they next interact

**GetAuthStatus response:**
```protobuf
message AuthStatus {
  bool authenticated = 1;
  string username = 2;
  bool needs_reauth = 3;           // true if refresh token expired
  string access_token_expires = 4;  // ISO8601 timestamp
  string refresh_token_expires = 5; // ISO8601 timestamp
  int32 failed_auth_jobs = 6;       // count of jobs failed due to auth
}
```

## Daemon Lifecycle

```
┌─────────────────────────────────────────────────────────┐
│                     Startup                             │
├─────────────────────────────────────────────────────────┤
│ 1. Load configuration                                   │
│ 2. Initialize SQLite database                           │
│ 3. Recover pending jobs from storage                    │
│ 4. Start scheduler (load saved schedules)               │
│ 5. Start worker pool                                    │
│ 6. Create Unix socket                                   │
│ 7. Start gRPC server                                    │
│ 8. Write PID file                                       │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│                     Running                             │
├─────────────────────────────────────────────────────────┤
│ - Accept gRPC requests from CLI                         │
│ - Process queued jobs                                   │
│ - Execute scheduled jobs                                │
│ - Communicate with Honeydew API                         │
│ - Persist state changes                                 │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│                     Shutdown                            │
├─────────────────────────────────────────────────────────┤
│ 1. Stop accepting new requests                          │
│ 2. Signal workers to stop                               │
│ 3. Wait for in-progress jobs (with timeout)             │
│ 4. Persist queue state                                  │
│ 5. Stop scheduler                                       │
│ 6. Close database connection                            │
│ 7. Remove Unix socket                                   │
│ 8. Remove PID file                                      │
└─────────────────────────────────────────────────────────┘
```

## Logging

**Location:** `internal/logging/`

**Log file:** `~/.honeydew/daemon.log`

The daemon uses structured JSON logging with automatic rotation.

### Log Format

```json
{
  "timestamp": "2024-01-15T10:30:45.123Z",
  "level": "error",
  "message": "job execution failed",
  "job_id": "abc123",
  "command": "github.commits",
  "error": "AUTH_EXPIRED: refresh token expired",
  "duration_ms": 1234,
  "retry_count": 2
}
```

### Log Levels

| Level | Description |
|-------|-------------|
| `debug` | Detailed execution info (disabled in production) |
| `info` | Normal operations (job started, completed, scheduled) |
| `warn` | Recoverable issues (retry triggered, token refreshed) |
| `error` | Failed operations (job failed, auth error, API error) |

### What Gets Logged

| Event | Level | Fields |
|-------|-------|--------|
| Job submitted | `info` | job_id, command, priority |
| Job started | `info` | job_id, command, worker_id |
| Job completed | `info` | job_id, command, duration_ms |
| Job failed | `error` | job_id, command, error, retry_count |
| Job retrying | `warn` | job_id, command, error, retry_count, next_retry |
| Auth token refreshed | `info` | environment, username |
| Auth token expired | `error` | environment, username, failed_jobs_count |
| Schedule triggered | `info` | schedule_id, schedule_name, job_id |

### Log Rotation

- **Max file size:** 10 MB (configurable)
- **Max backups:** 5 files (configurable)
- **Max age:** 30 days (configurable)
- **Compression:** gzip for rotated files

### Querying Failed Jobs

**Via SQLite:**
```sql
SELECT id, command, error, created_at, completed_at
FROM jobs
WHERE status = 'failed'
ORDER BY completed_at DESC
LIMIT 20;
```

**Via gRPC:**
```
ListJobs(status: "failed", limit: 20)
```

**Via log file:**
```bash
jq 'select(.level == "error")' ~/.honeydew/daemon.log
```

## Configuration

**Config file:** `~/.honeydew/config.yaml` (optional)

```yaml
daemon:
  socket_path: ~/.honeydew/daemon.sock
  pid_file: ~/.honeydew/daemon.pid

storage:
  database_path: ~/.honeydew/daemon.db

logging:
  level: info                          # debug, info, warn, error
  file: ~/.honeydew/daemon.log
  max_size_mb: 10                      # max size before rotation
  max_backups: 5                       # number of rotated files to keep
  max_age_days: 30                     # days to retain old logs
  compress: true                       # gzip rotated files

queue:
  workers: 4
  max_retries: 3
  retry_backoff: exponential

api:
  timeout: 30s
  graphql_endpoint: https://api.example.com/graphql
```

## Implementation Phases

### Phase 1: Foundation
- [ ] Project setup with `go.mod`
- [ ] Daemon lifecycle (start/stop/signal handling)
- [ ] SQLite storage layer with migrations
- [ ] Basic gRPC server on Unix socket
- [ ] Protobuf definitions and code generation

### Phase 2: Queue & Scheduler
- [ ] Command queue implementation
- [ ] Worker pool for job execution
- [ ] Cron scheduler integration
- [ ] Job persistence and recovery

### Phase 3: Honeydew API Integration
- [ ] GraphQL client setup with genqlient
- [ ] Honeydew authentication flow
- [ ] Token encryption and secure storage
- [ ] Environment management (prod/dev)

### Phase 4: Polish
- [ ] Configuration file support
- [ ] Logging and observability
- [ ] Error handling and retry logic
- [ ] Graceful shutdown improvements

## Build & Run

```bash
# Generate protobuf code
make proto

# Generate GraphQL client
make graphql

# Build daemon
make build

# Run daemon
./bin/daemon

# Or with go run
go run ./cmd/daemon
```

## Makefile Targets

```makefile
.PHONY: proto graphql build test clean

proto:
	protoc --go_out=. --go-grpc_out=. api/proto/*.proto

graphql:
	go run github.com/Khan/genqlient

build:
	go build -o bin/daemon ./cmd/daemon

test:
	go test ./...

clean:
	rm -rf bin/
```
