# Phase 5: Job Queue & Execution

*Depends on: Phase 4*

## Overview

This phase implements the job queue system with priority-based execution, worker pool, retry logic, and cron-based scheduling. Jobs are persisted to SQLite for durability and recovered on daemon restart.

## Tasks

### 1. Job Model & ID Generation

- [ ] **Write tests first:** `internal/queue/job_test.go`
  - [ ] Test NewJob generates unique ID
  - [ ] Test NewJob sets initial state to pending
  - [ ] Test NewJob sets created_at timestamp
  - [ ] Test Job state transitions are valid
- [ ] Create `internal/queue/job.go`:
  - [ ] Define `Job` struct (mirrors storage but with behavior):
    ```go
    type Job struct {
        ID          string
        Command     string
        Payload     []byte
        Priority    int
        Status      JobStatus
        CreatedAt   time.Time
        StartedAt   *time.Time
        CompletedAt *time.Time
        Result      []byte
        Error       string
        RetryCount  int
        MaxRetries  int
    }
    ```
  - [ ] Define `JobStatus` type with constants: `Pending`, `Running`, `Completed`, `Failed`, `Cancelled`
  - [ ] Implement `NewJob(command string, payload []byte, priority int) *Job`
  - [ ] Implement `CanRetry() bool`
  - [ ] Implement `MarkRunning()`, `MarkCompleted(result)`, `MarkFailed(error)`, `MarkCancelled()`

### 2. In-Memory Priority Queue

- [ ] **Write tests first:** `internal/queue/priority_queue_test.go`
  - [ ] Test Push adds job to queue
  - [ ] Test Pop returns highest priority job
  - [ ] Test Pop returns oldest job when priorities equal
  - [ ] Test Pop returns nil when queue empty
  - [ ] Test Len returns correct count
  - [ ] Test Remove removes specific job
  - [ ] Test queue is thread-safe (concurrent Push/Pop)
- [ ] Create `internal/queue/priority_queue.go`:
  - [ ] Implement using `container/heap`:
    ```go
    type PriorityQueue struct {
        mu    sync.Mutex
        items []*Job
    }
    ```
  - [ ] Implement `heap.Interface`: `Len()`, `Less()`, `Swap()`, `Push()`, `Pop()`
  - [ ] Sort by: priority DESC, then created_at ASC
  - [ ] Implement thread-safe wrappers: `Enqueue(*Job)`, `Dequeue() *Job`
  - [ ] Implement `Remove(jobID string) bool`
  - [ ] Implement `Peek() *Job` (view without removing)

### 3. Queue Manager

- [ ] **Write tests first:** `internal/queue/manager_test.go`
  - [ ] Test Submit adds job to queue and storage
  - [ ] Test Submit returns job ID immediately
  - [ ] Test GetJob retrieves job from storage
  - [ ] Test Cancel updates job status
  - [ ] Test Cancel fails for completed jobs
  - [ ] Test ListJobs filters by status
- [ ] Create `internal/queue/manager.go`:
  - [ ] Define `Manager` struct:
    ```go
    type Manager struct {
        queue    *PriorityQueue
        storage  *storage.DB
        executor Executor
        logger   logging.Logger
    }
    ```
  - [ ] Implement `NewManager(storage, executor, logger) *Manager`
  - [ ] Implement `Submit(command string, payload []byte, priority int) (string, error)`
  - [ ] Implement `Cancel(jobID string) error`
  - [ ] Implement `GetJob(jobID string) (*Job, error)`
  - [ ] Implement `ListJobs(filter JobFilter) ([]*Job, error)`
  - [ ] Implement `GetNextJob() *Job` (for workers)

### 4. Worker Pool

- [ ] **Write tests first:** `internal/queue/worker_test.go`
  - [ ] Test worker picks up jobs from queue
  - [ ] Test worker executes job command
  - [ ] Test worker updates job status on completion
  - [ ] Test worker handles execution errors
  - [ ] Test worker respects context cancellation
  - [ ] Test multiple workers process jobs concurrently
- [ ] Create `internal/queue/worker.go`:
  - [ ] Define `Worker` struct:
    ```go
    type Worker struct {
        id       int
        manager  *Manager
        executor Executor
        logger   logging.Logger
        done     chan struct{}
    }
    ```
  - [ ] Implement `NewWorker(id int, manager, executor, logger) *Worker`
  - [ ] Implement `Start(ctx context.Context)`:
    - [ ] Loop: get next job, execute, update status
    - [ ] Use select with ctx.Done() for cancellation
    - [ ] Sleep briefly when queue empty (avoid busy loop)
  - [ ] Implement `Stop()` - signals worker to stop
  - [ ] Log job start, completion, and errors with worker ID

### 5. Worker Pool Manager

- [ ] **Write tests first:** `internal/queue/pool_test.go`
  - [ ] Test pool starts configured number of workers
  - [ ] Test pool stops all workers on shutdown
  - [ ] Test pool waits for in-progress jobs on graceful shutdown
  - [ ] Test pool respects shutdown timeout
- [ ] Create `internal/queue/pool.go`:
  - [ ] Define `Pool` struct:
    ```go
    type Pool struct {
        workers []*Worker
        manager *Manager
        size    int
        wg      sync.WaitGroup
    }
    ```
  - [ ] Implement `NewPool(size int, manager *Manager, executor Executor) *Pool`
  - [ ] Implement `Start(ctx context.Context)`:
    - [ ] Create and start `size` workers
    - [ ] Track workers in WaitGroup
  - [ ] Implement `Stop(ctx context.Context) error`:
    - [ ] Signal all workers to stop
    - [ ] Wait for workers with timeout from context
    - [ ] Return error if timeout exceeded

### 6. Retry Logic with Exponential Backoff

- [ ] **Write tests first:** `internal/queue/retry_test.go`
  - [ ] Test retry is scheduled after failure
  - [ ] Test backoff increases exponentially
  - [ ] Test max retries is respected
  - [ ] Test job marked failed after max retries
  - [ ] Test retry backoff has jitter
- [ ] Create `internal/queue/retry.go`:
  - [ ] Define backoff parameters: base delay, max delay, multiplier
  - [ ] Implement `CalculateBackoff(retryCount int) time.Duration`:
    ```go
    delay := baseDelay * math.Pow(multiplier, float64(retryCount))
    delay = min(delay, maxDelay)
    jitter := rand.Float64() * 0.1 * delay  // 10% jitter
    return time.Duration(delay + jitter)
    ```
  - [ ] Implement `ShouldRetry(job *Job, err error) bool`:
    - [ ] Check retry count < max retries
    - [ ] Check error is retriable (not auth errors, validation errors)
  - [ ] Update worker to handle retries:
    - [ ] On failure, check `ShouldRetry()`
    - [ ] If yes, increment retry count, schedule retry
    - [ ] If no, mark job as failed

### 7. Job Recovery on Daemon Restart

- [ ] **Write tests first:** `internal/queue/recovery_test.go`
  - [ ] Test pending jobs are loaded into queue on startup
  - [ ] Test running jobs are reset to pending on startup
  - [ ] Test jobs are loaded in priority order
  - [ ] Test completed/failed jobs are not loaded
- [ ] Create `internal/queue/recovery.go`:
  - [ ] Implement `RecoverJobs(storage *storage.DB, queue *PriorityQueue) error`:
    - [ ] Query all pending jobs from storage
    - [ ] Query all running jobs (interrupted by crash)
    - [ ] Reset running jobs to pending
    - [ ] Add all to priority queue
    - [ ] Log number of recovered jobs
  - [ ] Call `RecoverJobs()` during daemon startup (before starting workers)

### 8. Cron Scheduler Integration

- [ ] **Write tests first:** `internal/scheduler/scheduler_test.go`
  - [ ] Test AddSchedule registers cron job
  - [ ] Test AddSchedule validates cron expression
  - [ ] Test schedule triggers job submission
  - [ ] Test RemoveSchedule stops scheduled job
  - [ ] Test ListSchedules returns all schedules
  - [ ] Test scheduler persists schedules to storage
- [ ] Create `internal/scheduler/scheduler.go`:
  - [ ] Define `Scheduler` struct:
    ```go
    type Scheduler struct {
        cron    *cron.Cron
        storage *storage.DB
        manager *queue.Manager
        entries map[string]cron.EntryID  // schedule ID -> cron entry
        mu      sync.RWMutex
        logger  logging.Logger
    }
    ```
  - [ ] Implement `NewScheduler(storage, manager, logger) *Scheduler`
  - [ ] Implement `Start()` - starts cron scheduler
  - [ ] Implement `Stop()` - stops cron scheduler
  - [ ] Implement `AddSchedule(schedule *Schedule) error`:
    - [ ] Validate cron expression
    - [ ] Save to storage
    - [ ] Register with cron library
    - [ ] Store entry ID mapping
  - [ ] Implement `RemoveSchedule(scheduleID string) error`
  - [ ] Implement `ListSchedules() ([]*Schedule, error)`
  - [ ] Implement `LoadSchedules() error` - load from storage on startup

### 9. Schedule Trigger Handler

- [ ] **Write tests first:**
  - [ ] Test trigger creates job with correct command and payload
  - [ ] Test trigger updates last_run_at timestamp
  - [ ] Test trigger calculates next_run_at
  - [ ] Test trigger logs execution
- [ ] Create schedule trigger function:
  - [ ] Implement `createTriggerFunc(schedule *Schedule) func()`:
    ```go
    return func() {
        job, err := manager.Submit(schedule.Command, schedule.Payload, 0)
        if err != nil {
            logger.Error("schedule trigger failed", ...)
            return
        }
        storage.UpdateLastRunAt(schedule.ID, time.Now())
        logger.Info("schedule triggered", "schedule", schedule.Name, "job", job.ID)
    }
    ```

### 10. gRPC Handlers for Queue & Scheduler

- [ ] **Write tests first:** `internal/grpc/queue_handlers_test.go`
  - [ ] Test SubmitJob creates job and returns ID
  - [ ] Test CancelJob cancels pending job
  - [ ] Test GetJobStatus returns current status
  - [ ] Test ListJobs returns filtered jobs
- [ ] Implement queue handlers in `internal/grpc/handlers.go`:
  - [ ] `SubmitJob(ctx, req) (*SubmitJobResponse, error)`
  - [ ] `CancelJob(ctx, req) (*CancelJobResponse, error)`
  - [ ] `GetJobStatus(ctx, req) (*JobStatus, error)`
  - [ ] `ListJobs(ctx, req) (*ListJobsResponse, error)`

- [ ] **Write tests first:** `internal/grpc/schedule_handlers_test.go`
  - [ ] Test ScheduleJob creates schedule
  - [ ] Test UnscheduleJob removes schedule
  - [ ] Test ListSchedules returns all schedules
- [ ] Implement scheduler handlers:
  - [ ] `ScheduleJob(ctx, req) (*ScheduleJobResponse, error)`
  - [ ] `UnscheduleJob(ctx, req) (*UnscheduleJobResponse, error)`
  - [ ] `ListSchedules(ctx, req) (*ListSchedulesResponse, error)`

### 11. Honeydew API Proxy Handlers

- [ ] Implement gRPC handlers that create jobs for Honeydew API calls:
  - [ ] `GitHubListRepositories` → creates job with command `github.repositories`
  - [ ] `GitHubGetCommits` → creates job with command `github.commits`
  - [ ] `GitHubGetPullRequests` → creates job with command `github.pullRequests`
  - [ ] `GitHubCloneRepository` → creates job with command `github.clone`
  - [ ] (Similar for GitLab, Jira, Linear, Bitbucket)
- [ ] Each handler:
  - [ ] Marshals request params to JSON payload
  - [ ] Calls `manager.Submit(commandType, payload, priority)`
  - [ ] Returns job ID to CLI for polling

## Deliverable

Full async job execution with scheduling

## Details

### Command Queue

**Location:** `internal/queue/`

In-memory queue with SQLite persistence for durability.

**Features:**
- Priority-based ordering
- Concurrent worker pool
- Retry with exponential backoff
- Job state persistence (survives daemon restart)

**Job states:** `pending` → `running` → `completed` | `failed` | `cancelled`

### Command Execution Model

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

### Scheduler

**Location:** `internal/scheduler/`

Wraps `robfig/cron/v3` for cron-based job scheduling.

**Features:**
- Standard cron expression support
- Named schedules for easy management
- Persistence of schedule definitions
- Automatic job submission on trigger

### Logging Events

| Event | Level | Fields |
|-------|-------|--------|
| Job submitted | `info` | job_id, command, priority |
| Job started | `info` | job_id, command, worker_id |
| Job completed | `info` | job_id, command, duration_ms |
| Job failed | `error` | job_id, command, error, retry_count |
| Job retrying | `warn` | job_id, command, error, retry_count, next_retry |
| Schedule triggered | `info` | schedule_id, schedule_name, job_id |

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
