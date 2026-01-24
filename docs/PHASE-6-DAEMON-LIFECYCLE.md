# Phase 6: Daemon Lifecycle & Polish

*Depends on: Phase 5*

## Overview

This phase completes the daemon implementation with proper lifecycle management, signal handling, graceful shutdown, and end-to-end integration testing.

## Tasks

### 1. Daemon Struct & Constructor

- [ ] **Write tests first:** `internal/daemon/daemon_test.go`
  - [ ] Test NewDaemon initializes all components
  - [ ] Test NewDaemon fails gracefully on config errors
  - [ ] Test daemon components are wired correctly
- [ ] Create `internal/daemon/daemon.go`:
  - [ ] Define `Daemon` struct:
    ```go
    type Daemon struct {
        config    *config.Config
        db        *storage.DB
        server    *grpc.Server
        manager   *queue.Manager
        pool      *queue.Pool
        scheduler *scheduler.Scheduler
        logger    logging.Logger
        startTime time.Time
        ctx       context.Context
        cancel    context.CancelFunc
    }
    ```
  - [ ] Implement `NewDaemon(configPath string) (*Daemon, error)`:
    - [ ] Load configuration
    - [ ] Initialize logger
    - [ ] Create context with cancel
    - [ ] Return daemon instance (components initialized in Start)

### 2. Daemon Startup Sequence

- [ ] **Write tests first:**
  - [ ] Test Start initializes database
  - [ ] Test Start runs migrations
  - [ ] Test Start recovers pending jobs
  - [ ] Test Start loads schedules
  - [ ] Test Start starts worker pool
  - [ ] Test Start starts gRPC server
  - [ ] Test Start writes PID file
  - [ ] Test Start fails if socket already in use
- [ ] Implement `Start() error`:
  ```go
  func (d *Daemon) Start() error {
      d.startTime = time.Now()

      // 1. Initialize database
      db, err := storage.Open(d.config.Storage.DatabasePath)
      if err != nil {
          return fmt.Errorf("open database: %w", err)
      }
      d.db = db

      // 2. Run migrations
      if err := storage.Migrate(d.db); err != nil {
          return fmt.Errorf("run migrations: %w", err)
      }

      // 3. Initialize components
      executor := honeydew.NewExecutor(d.db)
      d.manager = queue.NewManager(d.db, executor, d.logger)

      // 4. Recover pending jobs
      if err := queue.RecoverJobs(d.db, d.manager); err != nil {
          d.logger.Warn("job recovery failed", "error", err)
      }

      // 5. Start scheduler
      d.scheduler = scheduler.NewScheduler(d.db, d.manager, d.logger)
      d.scheduler.LoadSchedules()
      d.scheduler.Start()

      // 6. Start worker pool
      d.pool = queue.NewPool(d.config.Queue.Workers, d.manager, executor)
      d.pool.Start(d.ctx)

      // 7. Start gRPC server
      d.server = grpc.NewServer(d.config, d.db, d.manager, d.scheduler, d.logger)
      if err := d.server.Start(); err != nil {
          return fmt.Errorf("start grpc server: %w", err)
      }

      // 8. Write PID file
      if err := d.writePIDFile(); err != nil {
          d.logger.Warn("write pid file failed", "error", err)
      }

      d.logger.Info("daemon started", "socket", d.config.Daemon.SocketPath)
      return nil
  }
  ```

### 3. Signal Handling

- [ ] **Write tests first:**
  - [ ] Test SIGTERM triggers graceful shutdown
  - [ ] Test SIGINT triggers graceful shutdown
  - [ ] Test multiple signals don't cause panic
- [ ] Create `internal/daemon/signals.go`:
  - [ ] Implement `SetupSignalHandler(d *Daemon)`:
    ```go
    func SetupSignalHandler(d *Daemon) {
        sigChan := make(chan os.Signal, 1)
        signal.Notify(sigChan, syscall.SIGTERM, syscall.SIGINT)

        go func() {
            sig := <-sigChan
            d.logger.Info("received signal", "signal", sig)
            d.Shutdown(context.Background())
        }()
    }
    ```
- [ ] Call `SetupSignalHandler()` in `main.go` after `Start()`

### 4. Graceful Shutdown

- [ ] **Write tests first:**
  - [ ] Test shutdown stops accepting new connections
  - [ ] Test shutdown waits for in-progress jobs
  - [ ] Test shutdown respects timeout
  - [ ] Test shutdown persists queue state
  - [ ] Test shutdown removes socket file
  - [ ] Test shutdown removes PID file
- [ ] Implement `Shutdown(ctx context.Context) error`:
  ```go
  func (d *Daemon) Shutdown(ctx context.Context) error {
      d.logger.Info("initiating shutdown")

      // 1. Cancel daemon context (signals all components)
      d.cancel()

      // 2. Stop accepting new gRPC requests
      d.server.GracefulStop()

      // 3. Stop scheduler (no new jobs from schedules)
      d.scheduler.Stop()

      // 4. Stop worker pool (wait for in-progress jobs)
      shutdownCtx, cancel := context.WithTimeout(ctx, 30*time.Second)
      defer cancel()
      if err := d.pool.Stop(shutdownCtx); err != nil {
          d.logger.Warn("worker pool shutdown timeout", "error", err)
      }

      // 5. Close database connection
      if err := d.db.Close(); err != nil {
          d.logger.Warn("database close error", "error", err)
      }

      // 6. Cleanup files
      d.removePIDFile()
      d.removeSocketFile()

      d.logger.Info("daemon shutdown complete")
      return nil
  }
  ```

### 5. PID File Management

- [ ] **Write tests first:** `internal/daemon/pidfile_test.go`
  - [ ] Test writePIDFile creates file with correct PID
  - [ ] Test writePIDFile creates parent directory
  - [ ] Test removePIDFile deletes file
  - [ ] Test checkPIDFile detects running daemon
  - [ ] Test checkPIDFile returns false for stale PID
- [ ] Create `internal/daemon/pidfile.go`:
  - [ ] Implement `writePIDFile() error`:
    - [ ] Create parent directory if needed
    - [ ] Write current PID to file
    - [ ] Set file permissions (0644)
  - [ ] Implement `removePIDFile()`:
    - [ ] Remove PID file, ignore errors
  - [ ] Implement `checkPIDFile() (bool, int)`:
    - [ ] Read PID from file
    - [ ] Check if process is running (`os.FindProcess` + signal 0)
    - [ ] Return true if running, false if stale/missing
  - [ ] Check for existing daemon in `Start()`:
    ```go
    if running, pid := d.checkPIDFile(); running {
        return fmt.Errorf("daemon already running with PID %d", pid)
    }
    ```

### 6. Main Entry Point

- [ ] Create `cmd/daemon/main.go`:
  ```go
  func main() {
      // Parse flags
      configPath := flag.String("config", "", "config file path")
      flag.Parse()

      // Create daemon
      d, err := daemon.NewDaemon(*configPath)
      if err != nil {
          log.Fatalf("failed to create daemon: %v", err)
      }

      // Setup signal handler
      daemon.SetupSignalHandler(d)

      // Start daemon
      if err := d.Start(); err != nil {
          log.Fatalf("failed to start daemon: %v", err)
      }

      // Wait for shutdown signal
      d.Wait()
  }
  ```
- [ ] Implement `Wait()` - blocks until shutdown complete:
  ```go
  func (d *Daemon) Wait() {
      <-d.ctx.Done()
  }
  ```

### 7. End-to-End Integration Tests

- [ ] Create `tests/integration/` directory
- [ ] **Write integration tests:** `tests/integration/daemon_test.go`
  - [ ] Test full daemon startup and shutdown
  - [ ] Test Ping RPC returns success
  - [ ] Test environment management flow:
    - [ ] Add environment
    - [ ] List environments
    - [ ] Set active environment
  - [ ] Test job submission flow:
    - [ ] Submit job
    - [ ] Poll for status
    - [ ] Verify completion
  - [ ] Test scheduler flow:
    - [ ] Create schedule
    - [ ] Wait for trigger
    - [ ] Verify job created
  - [ ] Test graceful shutdown preserves state:
    - [ ] Submit jobs
    - [ ] Shutdown daemon
    - [ ] Restart daemon
    - [ ] Verify jobs recovered

### 8. CLI Simulation Scripts

- [ ] Create `scripts/common.sh` with shared utilities:
  ```bash
  SOCKET="${HONEYDEW_SOCKET:-$HOME/.honeydew/daemon.sock}"

  grpc_call() {
      grpcurl -plaintext -unix "$SOCKET" "$@"
  }
  ```

- [ ] Create individual scripts:
  - [ ] `scripts/ping.sh`:
    ```bash
    #!/bin/bash
    source "$(dirname "$0")/common.sh"
    grpc_call honeydew.Daemon/Ping
    ```
  - [ ] `scripts/status.sh`:
    ```bash
    #!/bin/bash
    source "$(dirname "$0")/common.sh"
    grpc_call honeydew.Daemon/GetStatus
    ```
  - [ ] `scripts/submit-job.sh`:
    ```bash
    #!/bin/bash
    source "$(dirname "$0")/common.sh"
    COMMAND="$1"
    PAYLOAD="$2"
    grpc_call -d "{\"command\": \"$COMMAND\", \"payload\": \"$PAYLOAD\"}" honeydew.Daemon/SubmitJob
    ```
  - [ ] `scripts/get-job.sh`:
    ```bash
    #!/bin/bash
    source "$(dirname "$0")/common.sh"
    JOB_ID="$1"
    grpc_call -d "{\"job_id\": \"$JOB_ID\"}" honeydew.Daemon/GetJobStatus
    ```
  - [ ] `scripts/list-jobs.sh`
  - [ ] `scripts/cancel-job.sh`
  - [ ] `scripts/schedule-job.sh`
  - [ ] `scripts/list-schedules.sh`
  - [ ] `scripts/unschedule-job.sh`
  - [ ] `scripts/shutdown.sh`:
    ```bash
    #!/bin/bash
    source "$(dirname "$0")/common.sh"
    grpc_call honeydew.Daemon/Shutdown
    ```
  - [ ] `scripts/env-add.sh`
  - [ ] `scripts/env-list.sh`
  - [ ] `scripts/env-use.sh`
  - [ ] `scripts/login.sh`
  - [ ] `scripts/auth-status.sh`

- [ ] Make all scripts executable: `chmod +x scripts/*.sh`
- [ ] Test each script manually against running daemon

### 9. Documentation & Final Polish

- [ ] Update README.md with:
  - [ ] Installation instructions
  - [ ] Quick start guide
  - [ ] Configuration reference
  - [ ] CLI script usage examples
- [ ] Add inline code documentation for public APIs
- [ ] Run `go vet ./...` and fix any issues
- [ ] Run `golangci-lint run` (if configured) and fix issues
- [ ] Verify `make test` passes with >80% coverage on business logic
- [ ] Verify `make build` produces working binary
- [ ] Test full workflow manually:
  - [ ] Start daemon
  - [ ] Add environment
  - [ ] Login
  - [ ] Submit API job
  - [ ] Poll for result
  - [ ] Create schedule
  - [ ] Verify scheduled job runs
  - [ ] Shutdown daemon gracefully

## Deliverable

Production-ready daemon with full lifecycle management

## Details

### Daemon Lifecycle

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

### File Locations

- **Unix socket:** `~/.honeydew/daemon.sock`
- **PID file:** `~/.honeydew/daemon.pid`
- **Database:** `~/.honeydew/daemon.db`
- **Config:** `~/.honeydew/config.yaml`
- **Log file:** `~/.honeydew/daemon.log`

### CLI Simulation Scripts

Shell scripts in `scripts/` simulate CLI interactions with the daemon for manual testing and development.

**Location:** `scripts/`

| Script | Purpose |
|--------|---------|
| `scripts/ping.sh` | Check if daemon is running |
| `scripts/status.sh` | Get daemon status |
| `scripts/submit-job.sh` | Submit a job to the queue |
| `scripts/get-job.sh` | Get status of a specific job |
| `scripts/list-jobs.sh` | List all jobs and their status |
| `scripts/cancel-job.sh` | Cancel a pending/running job |
| `scripts/schedule-job.sh` | Create a scheduled job |
| `scripts/list-schedules.sh` | List all scheduled jobs |
| `scripts/unschedule-job.sh` | Remove a scheduled job |
| `scripts/shutdown.sh` | Gracefully shutdown daemon |

**Usage:**

```bash
# Start daemon in background
go run ./cmd/daemon &

# Test daemon is running
./scripts/ping.sh

# Submit a test job
./scripts/submit-job.sh "test-command" '{"key": "value"}'

# List all jobs
./scripts/list-jobs.sh

# Check daemon status
./scripts/status.sh

# Shutdown daemon
./scripts/shutdown.sh
```

**Script requirements:**
- Scripts use `grpcurl` for gRPC calls over Unix socket
- Install: `brew install grpcurl` (macOS) or `go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest`
- Scripts read socket path from `HONEYDEW_SOCKET` env var or default to `~/.honeydew/daemon.sock`

**Example script template (`scripts/ping.sh`):**

```bash
#!/bin/bash
set -e

SOCKET="${HONEYDEW_SOCKET:-$HOME/.honeydew/daemon.sock}"

grpcurl -plaintext -unix "$SOCKET" honeydew.Daemon/Ping
```

### Build & Run

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

### Makefile Targets

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
