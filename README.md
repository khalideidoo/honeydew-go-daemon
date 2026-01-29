# Honeydew Go Daemon

A Go-based daemon that provides command queuing and scheduling capabilities. It communicates with a CLI application via Unix sockets using gRPC/protobuf and interfaces with the Honeydew API via GraphQL over HTTPS.

## Status

**Pre-implementation** - This project is currently in the specification and planning phase. The architecture and implementation plan have been defined, but no implementation code exists yet.

## Features (Planned)

- **Command Queue** - Priority-based job queue with async execution
- **Job Scheduling** - Cron-based scheduling for recurring jobs
- **gRPC API** - Unix socket communication for CLI integration
- **Honeydew API Integration** - GraphQL client for external API access
- **Secure Storage** - SQLite with AES-256-GCM encryption for sensitive data
- **Graceful Lifecycle** - Signal handling, PID management, and clean shutdown

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
                                                      │ HTTPS
                                     ┌────────────────▼────────────────┐
                                     │        Honeydew API             │
                                     │          (GraphQL)              │
                                     └─────────────────────────────────┘
```

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Language | Go 1.21+ |
| IPC | gRPC over Unix sockets |
| Serialization | Protocol Buffers |
| Database | SQLite (pure Go, no CGO) |
| Scheduling | Cron expressions |
| External API | Honeydew GraphQL |
| Encryption | AES-256-GCM, Argon2id KDF |

## Prerequisites

- Go 1.21 or later
- `protoc` (Protocol Buffers compiler)
- `grpcurl` (for CLI testing scripts)

```bash
# macOS
brew install protobuf grpcurl

# Or install grpcurl via Go
go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest
```

## Installation

```bash
# Clone the repository
git clone https://github.com/khalideidoo/honeydew-go-daemon.git
cd honeydew-go-daemon

# Install dependencies
go mod download

# Generate protobuf code
make proto

# Generate GraphQL client
make graphql

# Build the daemon
make build
```

## Usage

### Running the Daemon

```bash
# Run directly
go run ./cmd/daemon

# Or run the built binary
./bin/honeydew-daemon
```

### CLI Simulation Scripts

Shell scripts in `scripts/` provide CLI-like interaction with the daemon:

```bash
# Check if daemon is running
./scripts/ping.sh

# Submit a job
./scripts/submit-job.sh "command-name" '{"key": "value"}'

# List all jobs
./scripts/list-jobs.sh

# Get job status
./scripts/get-job.sh <job-id>

# Cancel a job
./scripts/cancel-job.sh <job-id>

# Schedule a recurring job
./scripts/schedule-job.sh "0 * * * *" "hourly-task" '{"data": "value"}'

# List scheduled jobs
./scripts/list-schedules.sh

# Remove a scheduled job
./scripts/unschedule-job.sh <schedule-id>

# Check daemon status
./scripts/status.sh

# Gracefully shutdown
./scripts/shutdown.sh
```

### File Locations

| Item | Path |
|------|------|
| Unix socket | `~/.honeydew/daemon.sock` |
| PID file | `~/.honeydew/daemon.pid` |
| Database | `~/.honeydew/daemon.db` |
| Config | `~/.honeydew/config.yaml` |

## Project Structure

```
honeydew-go-daemon/
├── cmd/
│   └── daemon/              # Daemon entry point
├── internal/
│   ├── daemon/              # Daemon lifecycle management
│   ├── grpc/                # gRPC server and handlers
│   ├── queue/               # Command queue and workers
│   ├── scheduler/           # Cron scheduler wrapper
│   ├── storage/             # SQLite persistence
│   ├── api/honeydew/        # Honeydew GraphQL client
│   ├── auth/                # OAuth 2.0 handling
│   └── crypto/              # Encryption utilities
├── api/proto/               # Protobuf definitions
├── graphql/                 # GraphQL schema and queries
├── migrations/              # SQLite migrations
├── scripts/                 # CLI testing scripts
└── docs/                    # Architecture documentation
```

## Development

This project follows **Test-Driven Development (TDD)**.

### TDD Cycle

1. **Red** - Write a failing test
2. **Green** - Write minimal code to pass
3. **Refactor** - Improve while keeping tests green

### Running Tests

```bash
# Run all tests
make test

# Run tests with verbose output
go test ./... -v

# Run tests for a specific package
go test ./internal/queue/... -v

# Run a specific test
go test ./internal/queue/... -run TestQueue_Enqueue -v

# Run tests with coverage
go test ./... -coverprofile=coverage.out
go tool cover -html=coverage.out
```

### Build Commands

```bash
make proto    # Generate protobuf code
make graphql  # Generate GraphQL client
make build    # Build daemon binary
make test     # Run tests
```

## Documentation

Detailed architecture and implementation plans are available in the `docs/` directory:

- [PLAN.md](docs/PLAN.md) - Architecture overview
- [Phase 1: Project Setup](docs/PHASE-1-PROJECT-SETUP.md)
- [Phase 2: Storage & Security](docs/PHASE-2-STORAGE-SECURITY.md)
- [Phase 3: gRPC Server](docs/PHASE-3-GRPC-SERVER.md)
- [Phase 4: Honeydew API Client](docs/PHASE-4-HONEYDEW-API-CLIENT.md)
- [Phase 5: Job Queue & Execution](docs/PHASE-5-JOB-QUEUE-EXECUTION.md)
- [Phase 6: Daemon Lifecycle](docs/PHASE-6-DAEMON-LIFECYCLE.md)

## Dependencies

```
google.golang.org/grpc          # gRPC framework
google.golang.org/protobuf      # Protobuf runtime
modernc.org/sqlite              # Pure Go SQLite
github.com/robfig/cron/v3       # Cron scheduler
golang.org/x/oauth2             # OAuth 2.0 client
golang.org/x/crypto             # Argon2, AES-GCM
github.com/Khan/genqlient       # GraphQL client generator
```

## License

[Add license information here]
