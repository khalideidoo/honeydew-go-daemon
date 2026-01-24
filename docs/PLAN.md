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

## Implementation Phases

```
Phase 1 ──► Phase 2 ──► Phase 3 ──► Phase 4 ──► Phase 5 ──► Phase 6
Project     Storage     gRPC        Honeydew    Job Queue   Daemon
Setup       & Crypto    Server      API Client  & Workers   Lifecycle
```

| Phase | Document | Description |
|-------|----------|-------------|
| 1 | [Project Setup](PHASE-1-PROJECT-SETUP.md) | Go module initialization, directory structure, protobuf definitions, configuration loading, and structured logging setup |
| 2 | [Storage & Security](PHASE-2-STORAGE-SECURITY.md) | SQLite database layer with migrations, schema for jobs/schedules/environments/tokens, and AES-256-GCM encryption utilities |
| 3 | [gRPC Server](PHASE-3-GRPC-SERVER.md) | Unix socket listener, gRPC server initialization, daemon control handlers, environment management, and authentication handlers |
| 4 | [Honeydew API Client](PHASE-4-HONEYDEW-API-CLIENT.md) | genqlient GraphQL client setup, dynamic endpoint configuration, authentication header injection, and token refresh handling |
| 5 | [Job Queue & Execution](PHASE-5-JOB-QUEUE-EXECUTION.md) | Priority-based job queue, worker pool, async execution, retry logic with exponential backoff, and cron scheduler integration |
| 6 | [Daemon Lifecycle](PHASE-6-DAEMON-LIFECYCLE.md) | Startup sequence, signal handling, graceful shutdown, PID file management, and end-to-end integration testing |

## Quick Reference

### File Locations

| File | Path |
|------|------|
| Unix socket | `~/.honeydew/daemon.sock` |
| PID file | `~/.honeydew/daemon.pid` |
| Database | `~/.honeydew/daemon.db` |
| Config | `~/.honeydew/config.yaml` |
| Log file | `~/.honeydew/daemon.log` |

### Build Commands

```bash
make proto    # Generate protobuf code
make graphql  # Generate GraphQL client
make build    # Build daemon binary
make test     # Run tests
go run ./cmd/daemon  # Run daemon
```
