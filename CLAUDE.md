# CLAUDE.md

This file provides context for Claude Code when working on this project.

## Project Overview

Honeydew Go Daemon - A Go-based daemon that provides command queuing and scheduling. It communicates with a CLI application via Unix sockets using gRPC/protobuf and interfaces with the Honeydew API via GraphQL over HTTPS.

## Tech Stack

- **Language:** Go 1.21+
- **IPC:** gRPC over Unix sockets
- **Serialization:** Protocol Buffers
- **Database:** SQLite (pure Go driver, no CGO)
- **Scheduling:** Cron expressions
- **External API:** Honeydew GraphQL (genqlient)
- **Encryption:** AES-256-GCM, Argon2id KDF

## Key Dependencies

```
google.golang.org/grpc          # gRPC framework
google.golang.org/protobuf      # Protobuf runtime
modernc.org/sqlite              # Pure Go SQLite
github.com/robfig/cron/v3       # Cron scheduler
golang.org/x/oauth2             # OAuth 2.0 client
golang.org/x/crypto             # Argon2, AES-GCM
github.com/Khan/genqlient       # GraphQL client generator
```

## Honeydew API

The daemon's only external API is the Honeydew API (GraphQL).

**Schema:** `graphql/schema.graphql`
**Source:** https://github.com/khalideidoo/honeydew-api

### Authentication

- Login via `login(username, password)` mutation returns `AuthPayload` with access/refresh tokens
- Use `refreshToken(refreshToken)` mutation to refresh expired tokens
- Tokens must be stored encrypted (AES-GCM) in local database

### Key Operations

| Category | Queries | Mutations |
|----------|---------|-----------|
| **User** | `me`, `listUsers`, `getUser` | `login`, `refreshToken`, `createUser`, `updateUser` |
| **GitHub** | `githubRepositories`, `githubCommits`, `githubPullRequests` | `githubCloneRepository` |
| **GitLab** | `gitlabProjects`, `gitlabCommits`, `gitlabMergeRequests` | `gitlabCloneRepository` |
| **Jira** | `jiraProjects`, `jiraIssues` | - |
| **Linear** | `linearTeams`, `linearProjects`, `linearIssues` | - |
| **Azure DevOps** | `azureDevOpsProjects`, `azureDevOpsWorkItems`, `azureDevOpsPullRequests` | - |
| **Asana** | `asanaWorkspaces`, `asanaProjects`, `asanaTasks` | - |
| **Monday** | `mondayWorkspaces`, `mondayBoards`, `mondayItems` | - |
| **Bitbucket** | `bitbucketRepositories`, `bitbucketCommits`, `bitbucketPullRequests` | `bitbucketCloneRepository` |

### Common Query Patterns

Most queries accept:
- `organization: String!` - Organization identifier
- `startDate: String` / `endDate: String` - Date range filtering
- `format: ExportFormat` - Output format (JSON)

### genqlient Setup

Queries are defined in `graphql/queries.graphql` and generated with:

```bash
make graphql  # runs: go run github.com/Khan/genqlient
```

Generated code goes to `internal/api/honeydew/generated/`.

## Project Structure

```
cmd/daemon/          # Daemon entry point
internal/
  daemon/            # Daemon lifecycle
  grpc/              # gRPC server and handlers
  queue/             # Command queue and workers
  scheduler/         # Cron scheduler wrapper
  storage/           # SQLite persistence
  api/honeydew/      # Honeydew GraphQL client (genqlient)
  auth/              # OAuth 2.0 handling
  crypto/            # Encryption utilities
api/proto/           # Protobuf definitions
graphql/             # GraphQL schema and genqlient config
migrations/          # SQLite migrations
scripts/             # Shell scripts for CLI simulation and testing
  daemon/            # Daemon control (ping, status, shutdown)
  jobs/              # Job management (submit, get, list, cancel)
  schedules/         # Scheduling (create, list, delete)
docs/                # Architecture and design documentation
  PLAN.md            # Detailed architecture plan
```

## Build Commands

```bash
# Run tests (do this frequently during TDD)
make test
go test ./... -v

# Run tests with coverage
go test ./... -coverprofile=coverage.out && go tool cover -html=coverage.out

# Generate protobuf code
make proto

# Generate GraphQL client
make graphql

# Build daemon binary
make build

# Run daemon
go run ./cmd/daemon

# Run CLI simulation scripts (requires grpcurl)
./scripts/daemon/ping.sh
./scripts/jobs/submit.sh "command" '{"payload": "data"}'
```

## Development Approach: TDD

This project follows Test-Driven Development. Always write tests first.

### TDD Cycle (Red-Green-Refactor)

1. **Red:** Write a failing test that defines the expected behavior
2. **Green:** Write the minimum code to make the test pass
3. **Refactor:** Clean up the code while keeping tests green

### TDD Commands

```bash
# Run tests continuously during development
go test ./... -v

# Run tests for a specific package
go test ./internal/queue/... -v

# Run a specific test
go test ./internal/queue/... -run TestQueue_Enqueue -v

# Run tests with coverage
go test ./... -coverprofile=coverage.out
go tool cover -html=coverage.out
```

### TDD Guidelines

- **Write the test first** - Never write implementation code without a failing test
- **One assertion per test** - Keep tests focused and readable
- **Test behavior, not implementation** - Tests should survive refactoring
- **Use descriptive test names** - `TestQueue_Enqueue_WithPriority_ReturnsHighestFirst`
- **Keep tests fast** - Mock external dependencies, use in-memory SQLite for unit tests
- **Aim for high coverage** - Target 80%+ coverage on business logic

## Code Conventions

- Use `internal/` for all non-exported packages
- Errors should wrap with context: `fmt.Errorf("operation failed: %w", err)`
- Use structured logging
- Context should be first parameter in functions that need cancellation
- Database operations should use transactions where appropriate
- All tokens/secrets must be encrypted at rest using AES-GCM
- **Write tests before implementation code**

## File Locations

- **Unix socket:** `~/.honeydew/daemon.sock`
- **PID file:** `~/.honeydew/daemon.pid`
- **Database:** `~/.honeydew/daemon.db`
- **Config:** `~/.honeydew/config.yaml`
- **Log file:** `~/.honeydew/daemon.log`
- **Output dir:** `~/.honeydew/output` (default)

## Testing

### Test Structure

- Unit tests alongside source files (`*_test.go`)
- Integration tests in `internal/*/integration_test.go`
- Test fixtures in `testdata/` directories

### Test Patterns

```go
// Table-driven tests
func TestQueue_Enqueue(t *testing.T) {
    tests := []struct {
        name     string
        input    Job
        wantErr  bool
    }{
        {"valid job", Job{ID: "1", Command: "test"}, false},
        {"empty command", Job{ID: "2", Command: ""}, true},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            q := NewQueue()
            err := q.Enqueue(tt.input)
            if (err != nil) != tt.wantErr {
                t.Errorf("Enqueue() error = %v, wantErr %v", err, tt.wantErr)
            }
        })
    }
}
```

### Mocking

- Define interfaces for external dependencies
- Use in-memory SQLite (`:memory:`) for database tests
- Create mock implementations for API clients
- Use `t.TempDir()` for file-based tests

### CLI Simulation Scripts

Shell scripts in `scripts/` simulate CLI interactions with the daemon for manual testing and development.

**Location:** `scripts/`

#### Daemon Control (`scripts/daemon/`)

| Script | Purpose |
|--------|---------|
| `ping.sh` | Check if daemon is running |
| `status.sh` | Get daemon status |
| `shutdown.sh` | Gracefully shutdown daemon |

#### Job Management (`scripts/jobs/`)

| Script | Purpose |
|--------|---------|
| `submit.sh` | Submit a job to the queue |
| `get.sh` | Get status of a specific job |
| `list.sh` | List all jobs and their status |
| `cancel.sh` | Cancel a pending/running job |

#### Scheduling (`scripts/schedules/`)

| Script | Purpose |
|--------|---------|
| `create.sh` | Create a scheduled job |
| `list.sh` | List all scheduled jobs |
| `delete.sh` | Remove a scheduled job |

**Usage:**

```bash
# Start daemon in background
go run ./cmd/daemon &

# Test daemon is running
./scripts/daemon/ping.sh

# Submit a test job
./scripts/jobs/submit.sh "test-command" '{"key": "value"}'

# List all jobs
./scripts/jobs/list.sh

# Check daemon status
./scripts/daemon/status.sh

# Shutdown daemon
./scripts/daemon/shutdown.sh
```

**Script requirements:**
- Scripts use `grpcurl` for gRPC calls over Unix socket
- Install: `brew install grpcurl` (macOS) or `go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest`
- Scripts read socket path from `HONEYDEW_SOCKET` env var or default to `~/.honeydew/daemon.sock`

**Example script template (`scripts/daemon/ping.sh`):**

```bash
#!/bin/bash
set -e

SOCKET="${HONEYDEW_SOCKET:-$HOME/.honeydew/daemon.sock}"

grpcurl -plaintext -unix "$SOCKET" honeydew.Daemon/Ping
```

## Common Tasks

### Adding a new gRPC method
1. Define in `api/proto/daemon.proto`
2. Run `make proto`
3. **Write tests first** in `internal/grpc/handlers_test.go`
4. Run tests - verify they fail (Red)
5. Implement handler in `internal/grpc/handlers.go`
6. Run tests - verify they pass (Green)
7. Refactor if needed, keeping tests green

### Adding a new queue feature
1. **Write tests first** in `internal/queue/queue_test.go`
2. Run tests - verify they fail (Red)
3. Implement the feature
4. Run tests - verify they pass (Green)
5. Refactor if needed

### Adding a new GraphQL query
1. Add query to `graphql/queries.graphql`
2. Run `make graphql`
3. **Write tests first** for the code using the generated client
4. Implement the feature
5. Verify tests pass

### Adding a database migration
1. Create new file in `migrations/` with incrementing prefix
2. **Write tests first** for the new schema/queries
3. Update migration logic in `internal/storage/sqlite.go`
4. Verify tests pass

### Adding any new feature
1. **Write a failing test** that describes the expected behavior
2. **Run the test** - confirm it fails for the right reason
3. **Write minimal code** to make the test pass
4. **Run the test** - confirm it passes
5. **Refactor** - improve code quality while keeping tests green
6. **Repeat** for the next piece of functionality
