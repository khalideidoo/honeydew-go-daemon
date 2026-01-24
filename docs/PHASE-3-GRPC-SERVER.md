# Phase 3: gRPC Server

*Depends on: Phase 2*

## Overview

This phase implements the gRPC server that listens on a Unix socket for CLI commands. It includes daemon control endpoints, environment management, and authentication handlers.

## Tasks

### 1. Unix Socket Listener

- [ ] **Write tests first:** `internal/grpc/server_test.go`
  - [ ] Test server creates Unix socket file
  - [ ] Test server removes existing socket file on startup
  - [ ] Test server creates parent directory if missing
  - [ ] Test server fails gracefully if socket path is invalid
  - [ ] Test server accepts connections
  - [ ] Test server closes socket on shutdown
- [ ] Create `internal/grpc/server.go`:
  - [ ] Define `Server` struct with `*grpc.Server`, socket path, listener
  - [ ] Implement `NewServer(config ServerConfig) (*Server, error)`
  - [ ] Implement socket path directory creation
  - [ ] Implement stale socket file cleanup (remove if exists)
  - [ ] Create `net.Listen("unix", socketPath)` listener
  - [ ] Implement `Start() error` (non-blocking, starts goroutine)
  - [ ] Implement `Stop(ctx context.Context) error` (graceful shutdown)
  - [ ] Implement `GracefulStop()` with timeout

### 2. gRPC Server Initialization

- [ ] Create `internal/grpc/service.go`:
  - [ ] Define `DaemonService` struct implementing generated `DaemonServer` interface
  - [ ] Add dependencies: storage DB, queue, scheduler, API client, logger
  - [ ] Implement constructor: `NewDaemonService(deps Dependencies) *DaemonService`
- [ ] Register service with gRPC server:
  - [ ] In `NewServer()`: `pb.RegisterDaemonServer(grpcServer, service)`
- [ ] Add gRPC interceptors:
  - [ ] Logging interceptor: log all RPC calls with method, duration, error
  - [ ] Recovery interceptor: catch panics and return Internal error
  - [ ] Create `internal/grpc/interceptors.go` for interceptor implementations

### 3. Daemon Control Handlers

#### Ping
- [ ] **Write tests first:** `internal/grpc/handlers_test.go`
  - [ ] Test Ping returns success response
  - [ ] Test Ping includes daemon version
  - [ ] Test Ping includes uptime
- [ ] Implement `Ping(ctx, req) (*PingResponse, error)`:
  - [ ] Return daemon version string
  - [ ] Return uptime duration
  - [ ] Return timestamp

#### GetStatus
- [ ] **Write tests first:**
  - [ ] Test GetStatus returns daemon state
  - [ ] Test GetStatus includes job queue stats
  - [ ] Test GetStatus includes active environment info
- [ ] Implement `GetStatus(ctx, req) (*DaemonStatus, error)`:
  - [ ] Return daemon version, uptime, PID
  - [ ] Return queue stats: pending, running, completed, failed counts
  - [ ] Return worker pool status: active workers, idle workers
  - [ ] Return active environment name and URL
  - [ ] Return authentication status summary

#### Shutdown
- [ ] **Write tests first:**
  - [ ] Test Shutdown initiates graceful shutdown
  - [ ] Test Shutdown returns acknowledgment
- [ ] Implement `Shutdown(ctx, req) (*ShutdownResponse, error)`:
  - [ ] Signal daemon to begin shutdown sequence
  - [ ] Return acknowledgment with expected shutdown behavior
  - [ ] Use channel or context to signal main daemon goroutine

### 4. Environment Management Handlers

#### AddEnvironment
- [ ] **Write tests first:**
  - [ ] Test AddEnvironment creates new environment
  - [ ] Test AddEnvironment fails on duplicate name
  - [ ] Test AddEnvironment with set_active=true activates environment
  - [ ] Test AddEnvironment validates URL format
- [ ] Implement `AddEnvironment(ctx, req) (*AddEnvironmentResponse, error)`:
  - [ ] Validate name (non-empty, alphanumeric with hyphens)
  - [ ] Validate base_url (valid URL, HTTPS preferred)
  - [ ] Generate UUID for environment ID
  - [ ] Call `storage.CreateEnvironment()`
  - [ ] If `set_active`, call `storage.SetActiveEnvironment()`
  - [ ] Return created environment

#### RemoveEnvironment
- [ ] **Write tests first:**
  - [ ] Test RemoveEnvironment deletes environment
  - [ ] Test RemoveEnvironment fails if environment is active
  - [ ] Test RemoveEnvironment fails if environment not found
  - [ ] Test RemoveEnvironment cascades to delete tokens
- [ ] Implement `RemoveEnvironment(ctx, req) (*RemoveEnvironmentResponse, error)`:
  - [ ] Look up environment by name
  - [ ] Check if active, return error if so
  - [ ] Call `storage.DeleteEnvironment()`
  - [ ] Return success

#### ListEnvironments
- [ ] **Write tests first:**
  - [ ] Test ListEnvironments returns all environments
  - [ ] Test ListEnvironments includes active flag
  - [ ] Test ListEnvironments returns empty list when none exist
- [ ] Implement `ListEnvironments(ctx, req) (*ListEnvironmentsResponse, error)`:
  - [ ] Call `storage.ListEnvironments()`
  - [ ] Convert to protobuf messages
  - [ ] Return list

#### SetActiveEnvironment
- [ ] **Write tests first:**
  - [ ] Test SetActiveEnvironment switches active environment
  - [ ] Test SetActiveEnvironment fails if environment not found
  - [ ] Test SetActiveEnvironment returns needs_auth if no tokens
- [ ] Implement `SetActiveEnvironment(ctx, req) (*SetActiveEnvironmentResponse, error)`:
  - [ ] Look up environment by name
  - [ ] Call `storage.SetActiveEnvironment()`
  - [ ] Check for existing tokens for this environment
  - [ ] Return `needs_auth: true` if no valid tokens

#### GetActiveEnvironment
- [ ] **Write tests first:**
  - [ ] Test GetActiveEnvironment returns active environment
  - [ ] Test GetActiveEnvironment returns error if none active
- [ ] Implement `GetActiveEnvironment(ctx, req) (*GetActiveEnvironmentResponse, error)`:
  - [ ] Call `storage.GetActiveEnvironment()`
  - [ ] Return environment details or error

### 5. Authentication Handlers

#### Login
- [ ] **Write tests first:**
  - [ ] Test Login with valid credentials succeeds
  - [ ] Test Login stores encrypted tokens
  - [ ] Test Login fails with invalid credentials (mock API)
  - [ ] Test Login requires active environment
- [ ] Implement `Login(ctx, req) (*LoginResponse, error)`:
  - [ ] Get active environment
  - [ ] Call Honeydew API `login` mutation (via job or direct)
  - [ ] Encrypt tokens using `crypto.Encrypt()`
  - [ ] Store tokens via `storage.SaveTokens()`
  - [ ] Return success with username and token expiry times

#### Logout
- [ ] **Write tests first:**
  - [ ] Test Logout clears tokens for active environment
  - [ ] Test Logout succeeds even if not logged in
- [ ] Implement `Logout(ctx, req) (*LogoutResponse, error)`:
  - [ ] Get active environment
  - [ ] Delete tokens via `storage.DeleteTokens()`
  - [ ] Return success

#### GetAuthStatus
- [ ] **Write tests first:**
  - [ ] Test GetAuthStatus returns authenticated=true when tokens exist
  - [ ] Test GetAuthStatus returns authenticated=false when no tokens
  - [ ] Test GetAuthStatus returns needs_reauth when refresh token expired
  - [ ] Test GetAuthStatus returns token expiry times
  - [ ] Test GetAuthStatus returns failed auth job count
- [ ] Implement `GetAuthStatus(ctx, req) (*AuthStatus, error)`:
  - [ ] Get active environment
  - [ ] Retrieve tokens via `storage.GetTokens()`
  - [ ] Decrypt tokens to check expiry times
  - [ ] Check if refresh token is expired
  - [ ] Query failed jobs with auth errors
  - [ ] Return comprehensive auth status

### 6. Integration: Wire Up Server

- [ ] Create `internal/grpc/deps.go`:
  - [ ] Define `Dependencies` struct with all service dependencies
  - [ ] Implement `NewDependencies(config, db, ...) *Dependencies`
- [ ] Update `cmd/daemon/main.go`:
  - [ ] Initialize storage
  - [ ] Create dependencies
  - [ ] Create and start gRPC server
  - [ ] Handle shutdown signals
- [ ] **Write integration test:** `internal/grpc/integration_test.go`
  - [ ] Test full server startup and shutdown
  - [ ] Test Ping via gRPC client
  - [ ] Test environment CRUD operations
  - [ ] Test authentication flow (with mock Honeydew API)

## Deliverable

CLI can connect and manage environments/auth

## Details

### Unix Socket

**Socket path:** `~/.honeydew/daemon.sock` (or configurable)

### Service Definition

**File:** `api/proto/daemon.proto`

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

### Environment Management

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

### Authentication Status

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
