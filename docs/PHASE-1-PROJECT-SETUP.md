# Phase 1: Project Setup

*No dependencies*

## Overview

This phase establishes the foundational project structure, including Go module initialization, directory layout, protobuf definitions, configuration loading, and structured logging.

## Tasks

### 1. Go Module & Dependencies

- [ ] Initialize Go module: `go mod init github.com/khalideidoo/honeydew-go-daemon`
- [ ] Add core dependencies to `go.mod`:
  - [ ] `google.golang.org/grpc` - gRPC framework
  - [ ] `google.golang.org/protobuf` - Protocol buffers runtime
  - [ ] `modernc.org/sqlite` - Pure Go SQLite driver
  - [ ] `github.com/robfig/cron/v3` - Cron scheduler
  - [ ] `golang.org/x/crypto` - Argon2, AES-GCM
  - [ ] `github.com/Khan/genqlient` - GraphQL client generator
  - [ ] `gopkg.in/natefinch/lumberjack.v2` - Log rotation
  - [ ] `gopkg.in/yaml.v3` - YAML config parsing
- [ ] Run `go mod tidy` to resolve dependencies

### 2. Directory Structure

- [ ] Create `cmd/daemon/` directory
- [ ] Create `cmd/daemon/main.go` with minimal entry point
- [ ] Create `internal/` package directories:
  - [ ] `internal/daemon/` - Daemon lifecycle
  - [ ] `internal/grpc/` - gRPC server and handlers
  - [ ] `internal/queue/` - Command queue and workers
  - [ ] `internal/scheduler/` - Cron scheduler wrapper
  - [ ] `internal/storage/` - SQLite persistence
  - [ ] `internal/api/honeydew/` - Honeydew GraphQL client
  - [ ] `internal/api/honeydew/generated/` - genqlient output
  - [ ] `internal/auth/` - OAuth handling
  - [ ] `internal/crypto/` - Encryption utilities
  - [ ] `internal/config/` - Configuration loading
  - [ ] `internal/logging/` - Structured logging
- [ ] Create `api/proto/` directory for protobuf definitions
- [ ] Create `graphql/` directory for GraphQL schema and genqlient config
- [ ] Create `migrations/` directory for SQLite migrations
- [ ] Create `scripts/` directory for CLI simulation scripts
  - [ ] `scripts/daemon/` - Daemon control (ping, status, shutdown)
  - [ ] `scripts/jobs/` - Job management (submit, get, list, cancel)
  - [ ] `scripts/schedules/` - Scheduling (create, list, delete)

### 3. Protobuf Definitions

- [ ] Create `api/proto/daemon.proto` with package declaration and Go options
- [ ] Define `Daemon` service with all RPC methods:
  - [ ] Job Management: `SubmitJob`, `CancelJob`, `GetJobStatus`, `ListJobs`
  - [ ] Scheduling: `ScheduleJob`, `UnscheduleJob`, `ListSchedules`
  - [ ] Authentication: `Login`, `Logout`, `GetAuthStatus`
  - [ ] Environment: `AddEnvironment`, `RemoveEnvironment`, `ListEnvironments`, `SetActiveEnvironment`, `GetActiveEnvironment`
  - [ ] Honeydew API proxies: GitHub, GitLab, Jira, Linear, Bitbucket methods
  - [ ] Daemon Control: `Ping`, `Shutdown`, `GetStatus`
- [ ] Define all request/response message types for each RPC
- [ ] Define shared message types: `Job`, `JobStatus`, `Schedule`, `Environment`, `AuthStatus`, `DaemonStatus`
- [ ] Define enums: `JobState` (pending, running, completed, failed, cancelled)

### 4. Protobuf Code Generation

- [ ] Install protoc compiler (if not present)
- [ ] Install Go protoc plugins: `protoc-gen-go`, `protoc-gen-go-grpc`
- [ ] Create `Makefile` with `proto` target
- [ ] Add buf.yaml or direct protoc command for code generation
- [ ] Generate Go code to `internal/grpc/proto/` or alongside proto files
- [ ] Verify generated `*_grpc.pb.go` and `*.pb.go` files compile

### 5. Configuration Loading

- [ ] **Write tests first:** `internal/config/config_test.go`
  - [ ] Test loading config from YAML file
  - [ ] Test default values when config file missing
  - [ ] Test environment variable overrides
  - [ ] Test path expansion (`~/.honeydew/` → absolute path)
  - [ ] Test invalid config returns error
- [ ] Create `internal/config/config.go`:
  - [ ] Define `Config` struct with nested structs (Daemon, Storage, Logging, Queue, API)
  - [ ] Implement `Load(path string) (*Config, error)`
  - [ ] Implement `LoadWithDefaults() *Config`
  - [ ] Implement path expansion for `~` home directory
  - [ ] Support environment variable overrides (`HONEYDEW_SOCKET_PATH`, etc.)
- [ ] Create default config template at `configs/config.example.yaml`

### 6. Structured Logging

- [ ] **Write tests first:** `internal/logging/logger_test.go`
  - [ ] Test JSON output format
  - [ ] Test log levels (debug, info, warn, error)
  - [ ] Test structured fields are included
  - [ ] Test log rotation triggers at size limit
- [ ] Create `internal/logging/logger.go`:
  - [ ] Define `Logger` interface with `Debug`, `Info`, `Warn`, `Error` methods
  - [ ] Implement JSON formatter with timestamp, level, message, fields
  - [ ] Integrate `lumberjack` for log rotation
  - [ ] Support configurable rotation settings (max size, max backups, max age, compress)
  - [ ] Implement `WithFields(fields map[string]interface{}) Logger` for contextual logging
- [ ] Create package-level logger instance with `Init(config LoggingConfig)` function
- [ ] Add helper functions: `logging.Info()`, `logging.Error()`, etc.

### 7. Makefile

- [ ] Create `Makefile` with targets:
  - [ ] `proto` - Generate protobuf code
  - [ ] `graphql` - Generate GraphQL client (placeholder for Phase 4)
  - [ ] `build` - Build daemon binary to `bin/daemon`
  - [ ] `test` - Run all tests with `-v`
  - [ ] `test-cover` - Run tests with coverage report
  - [ ] `clean` - Remove build artifacts
  - [ ] `lint` - Run golangci-lint (optional)
- [ ] Verify `make build` produces working binary
- [ ] Verify `make test` runs successfully (even with no tests yet)

## Deliverable

Buildable project skeleton with config and logging

## Details

### Directory Structure

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
├── scripts/
│   ├── daemon/                  # Daemon control scripts
│   │   ├── ping.sh
│   │   ├── status.sh
│   │   └── shutdown.sh
│   ├── jobs/                    # Job management scripts
│   │   ├── submit.sh
│   │   ├── get.sh
│   │   ├── list.sh
│   │   └── cancel.sh
│   └── schedules/               # Scheduling scripts
│       ├── create.sh
│       ├── list.sh
│       └── delete.sh
├── go.mod
├── go.sum
└── Makefile
```

### Configuration

**Config file:** `~/.honeydew/config.yaml` (optional)

```yaml
daemon:
  socket_path: ~/.honeydew/daemon.sock
  pid_file: ~/.honeydew/daemon.pid
  output_dir: ~/.honeydew/output        # default output directory for commands

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

### Logging

**Location:** `internal/logging/`

**Log file:** `~/.honeydew/daemon.log`

The daemon uses structured JSON logging with automatic rotation.

#### Log Format

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

#### Log Levels

| Level | Description |
|-------|-------------|
| `debug` | Detailed execution info (disabled in production) |
| `info` | Normal operations (job started, completed, scheduled) |
| `warn` | Recoverable issues (retry triggered, token refreshed) |
| `error` | Failed operations (job failed, auth error, API error) |

#### Log Rotation

- **Max file size:** 10 MB (configurable)
- **Max backups:** 5 files (configurable)
- **Max age:** 30 days (configurable)
- **Compression:** gzip for rotated files
