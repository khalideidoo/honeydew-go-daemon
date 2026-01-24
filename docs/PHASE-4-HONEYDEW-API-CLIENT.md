# Phase 4: Honeydew API Client

*Depends on: Phase 3*

## Overview

This phase implements the Honeydew GraphQL API client using genqlient for type-safe queries. It includes dynamic endpoint configuration based on the active environment and automatic token refresh handling.

## Tasks

### 1. GraphQL Schema & genqlient Configuration

- [ ] Copy Honeydew GraphQL schema to `graphql/schema.graphql`
- [ ] Create `graphql/genqlient.yaml` configuration:
  ```yaml
  schema: schema.graphql
  operations:
    - queries.graphql
  generated: ../internal/api/honeydew/generated/generated.go
  package: generated
  bindings:
    DateTime:
      type: time.Time
  ```
- [ ] Create `graphql/queries.graphql` with all operations:
  - [ ] `mutation Login($username: String!, $password: String!)`
  - [ ] `mutation RefreshToken($refreshToken: String!)`
  - [ ] `query Me`
  - [ ] GitHub queries: `githubRepositories`, `githubCommits`, `githubPullRequests`
  - [ ] GitHub mutation: `githubCloneRepository`
  - [ ] GitLab queries: `gitlabProjects`, `gitlabCommits`, `gitlabMergeRequests`
  - [ ] GitLab mutation: `gitlabCloneRepository`
  - [ ] Jira queries: `jiraProjects`, `jiraIssues`
  - [ ] Linear queries: `linearTeams`, `linearProjects`, `linearIssues`
  - [ ] Bitbucket queries: `bitbucketRepositories`, `bitbucketCommits`, `bitbucketPullRequests`
  - [ ] Bitbucket mutation: `bitbucketCloneRepository`
- [ ] Add `graphql` target to Makefile: `go run github.com/Khan/genqlient`
- [ ] Run `make graphql` and verify generated code compiles

### 2. GraphQL Client Setup

- [ ] **Write tests first:** `internal/api/honeydew/client_test.go`
  - [ ] Test NewClient creates client with base URL
  - [ ] Test client makes request to correct endpoint
  - [ ] Test client includes Authorization header when token provided
  - [ ] Test client handles network errors gracefully
  - [ ] Test client handles GraphQL errors
- [ ] Create `internal/api/honeydew/client.go`:
  - [ ] Define `Client` struct with HTTP client, base URL, token provider
  - [ ] Implement `NewClient(baseURL string) *Client`
  - [ ] Implement `SetTokenProvider(provider TokenProvider)`
  - [ ] Define `TokenProvider` interface: `GetAccessToken() (string, error)`
  - [ ] Create custom `http.RoundTripper` for auth header injection
  - [ ] Implement `Do(ctx, op) (interface{}, error)` wrapper for genqlient

### 3. Dynamic Endpoint Configuration

- [ ] **Write tests first:**
  - [ ] Test client uses active environment URL
  - [ ] Test client updates URL when environment changes
  - [ ] Test client fails gracefully if no active environment
- [ ] Create `internal/api/honeydew/environment.go`:
  - [ ] Define `EnvironmentAwareClient` wrapping base `Client`
  - [ ] Implement `NewEnvironmentAwareClient(storage *storage.DB) *EnvironmentAwareClient`
  - [ ] Implement `GetClient() (*Client, error)` - creates client for active env
  - [ ] Cache client instance, invalidate on environment change
  - [ ] Listen for environment change events (or check on each request)

### 4. Authentication Header Injection

- [ ] **Write tests first:**
  - [ ] Test requests include Bearer token in Authorization header
  - [ ] Test requests without token don't include header
  - [ ] Test token is fetched fresh for each request (not stale)
- [ ] Create `internal/api/honeydew/auth_transport.go`:
  - [ ] Implement `AuthenticatedTransport` as `http.RoundTripper`
  - [ ] In `RoundTrip()`: get token from provider, add header, delegate
  - [ ] Handle missing token gracefully (for login/public endpoints)
- [ ] Create `internal/api/honeydew/token_provider.go`:
  - [ ] Implement `StorageTokenProvider` using storage.DB
  - [ ] Decrypt token on each `GetAccessToken()` call
  - [ ] Return error if no token available

### 5. Token Refresh Handling

#### Proactive Refresh
- [ ] **Write tests first:** `internal/api/honeydew/refresh_test.go`
  - [ ] Test proactive refresh when token expires within 5 minutes
  - [ ] Test no refresh when token has plenty of time
  - [ ] Test refresh updates stored tokens
  - [ ] Test refresh failure returns error
- [ ] Implement proactive refresh in `TokenProvider`:
  - [ ] Check token expiry before returning
  - [ ] If expiring within 5 minutes, trigger refresh
  - [ ] Call `refreshToken` mutation
  - [ ] Encrypt and store new tokens
  - [ ] Return new access token

#### Retry on 401
- [ ] **Write tests first:**
  - [ ] Test 401 response triggers token refresh
  - [ ] Test request is retried after successful refresh
  - [ ] Test no retry if refresh fails
  - [ ] Test no infinite retry loop (max 1 retry)
- [ ] Implement retry logic in `AuthenticatedTransport`:
  - [ ] Check response status code
  - [ ] If 401, attempt token refresh
  - [ ] If refresh succeeds, retry original request once
  - [ ] If refresh fails, return original 401 error

### 6. Honeydew API Method Implementations

#### Authentication Methods
- [ ] **Write tests first:** `internal/api/honeydew/auth_test.go`
  - [ ] Test Login returns tokens on success
  - [ ] Test Login returns error on invalid credentials
  - [ ] Test RefreshToken returns new tokens
- [ ] Create `internal/api/honeydew/auth.go`:
  - [ ] Implement `Login(ctx, username, password string) (*AuthPayload, error)`
  - [ ] Implement `RefreshToken(ctx, refreshToken string) (*AuthPayload, error)`
  - [ ] Implement `Me(ctx) (*User, error)`

#### GitHub Methods
- [ ] **Write tests first:** `internal/api/honeydew/github_test.go`
  - [ ] Test ListRepositories returns repositories
  - [ ] Test GetCommits returns commits with date filtering
  - [ ] Test GetPullRequests returns PRs
  - [ ] Test CloneRepository triggers clone operation
- [ ] Create `internal/api/honeydew/github.go`:
  - [ ] Implement `GitHubListRepositories(ctx, org string) ([]*Repository, error)`
  - [ ] Implement `GitHubGetCommits(ctx, org, repo, startDate, endDate string) ([]*Commit, error)`
  - [ ] Implement `GitHubGetPullRequests(ctx, org, repo string) ([]*PullRequest, error)`
  - [ ] Implement `GitHubCloneRepository(ctx, org, repo, destPath string) error`

#### GitLab Methods
- [ ] **Write tests first:** `internal/api/honeydew/gitlab_test.go`
  - [ ] Test ListProjects returns projects
  - [ ] Test GetCommits returns commits
  - [ ] Test GetMergeRequests returns MRs
- [ ] Create `internal/api/honeydew/gitlab.go`:
  - [ ] Implement `GitLabListProjects(ctx, org string) ([]*Project, error)`
  - [ ] Implement `GitLabGetCommits(ctx, org, project, startDate, endDate string) ([]*Commit, error)`
  - [ ] Implement `GitLabGetMergeRequests(ctx, org, project string) ([]*MergeRequest, error)`
  - [ ] Implement `GitLabCloneRepository(ctx, org, project, destPath string) error`

#### Jira Methods
- [ ] **Write tests first:** `internal/api/honeydew/jira_test.go`
  - [ ] Test ListProjects returns projects
  - [ ] Test GetIssues returns issues with filtering
- [ ] Create `internal/api/honeydew/jira.go`:
  - [ ] Implement `JiraListProjects(ctx, org string) ([]*JiraProject, error)`
  - [ ] Implement `JiraGetIssues(ctx, org, project string) ([]*JiraIssue, error)`

#### Linear Methods
- [ ] **Write tests first:** `internal/api/honeydew/linear_test.go`
  - [ ] Test ListTeams returns teams
  - [ ] Test ListProjects returns projects
  - [ ] Test GetIssues returns issues
- [ ] Create `internal/api/honeydew/linear.go`:
  - [ ] Implement `LinearListTeams(ctx, org string) ([]*LinearTeam, error)`
  - [ ] Implement `LinearListProjects(ctx, org, teamID string) ([]*LinearProject, error)`
  - [ ] Implement `LinearGetIssues(ctx, org, projectID string) ([]*LinearIssue, error)`

#### Bitbucket Methods
- [ ] **Write tests first:** `internal/api/honeydew/bitbucket_test.go`
  - [ ] Test ListWorkspaces returns workspaces
  - [ ] Test ListRepositories returns repositories
  - [ ] Test GetCommits returns commits
- [ ] Create `internal/api/honeydew/bitbucket.go`:
  - [ ] Implement `BitbucketListWorkspaces(ctx, org string) ([]*Workspace, error)`
  - [ ] Implement `BitbucketListRepositories(ctx, org, workspace string) ([]*Repository, error)`
  - [ ] Implement `BitbucketGetCommits(ctx, org, workspace, repo string) ([]*Commit, error)`
  - [ ] Implement `BitbucketCloneRepository(ctx, org, workspace, repo, destPath string) error`

### 7. Command Executor Registry

- [ ] **Write tests first:** `internal/api/honeydew/executor_test.go`
  - [ ] Test executor maps command type to API method
  - [ ] Test executor handles unknown command type
  - [ ] Test executor passes payload correctly
  - [ ] Test executor returns result as JSON
- [ ] Create `internal/api/honeydew/executor.go`:
  - [ ] Define `Executor` interface: `Execute(ctx, commandType string, payload []byte) ([]byte, error)`
  - [ ] Implement `HoneydewExecutor` struct
  - [ ] Create command type to method mapping:
    ```go
    var commandHandlers = map[string]Handler{
        "github.repositories": handleGitHubRepositories,
        "github.commits":      handleGitHubCommits,
        "github.pullRequests": handleGitHubPullRequests,
        // ... etc
    }
    ```
  - [ ] Implement `Execute()` to dispatch to correct handler
  - [ ] Parse payload JSON, call API method, serialize result to JSON

## Deliverable

Daemon can make authenticated Honeydew API calls

## Details

### Client Location

**Location:** `internal/api/honeydew/`

- Uses `genqlient` for type-safe GraphQL queries/mutations
- Schema-first approach with generated Go code
- Automatic authentication header injection
- Token refresh handling

### API Method Behavior

All Honeydew API methods (GitHub*, GitLab*, Jira*, etc.) follow the async execution model:

1. **CLI calls method** (e.g., `GitHubGetCommits`)
2. **Daemon creates a job** internally with command type and parameters
3. **Response returns job_id** immediately
4. **Worker executes** the corresponding GraphQL query against Honeydew API
5. **CLI polls `GetJobStatus`** to retrieve results

### Example Flow

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

### Authentication for Scheduled Jobs

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

### Token Refresh Strategy

| Mechanism | Description |
|-----------|-------------|
| **Proactive refresh** | Refresh if access token expires within 5 minutes |
| **Automatic retry** | If API returns 401, refresh token and retry once |
| **Refresh token expiry** | If refresh token expired, job fails with `AUTH_EXPIRED` |
| **Background refresh** | Daemon can periodically check and refresh tokens |

### Failure Scenarios

| Scenario | Behavior | Job Error Code |
|----------|----------|----------------|
| Access token expired, refresh token valid | Auto-refresh, continue | (none) |
| Access token expired, refresh token expired | Job fails | `AUTH_EXPIRED` |
| API returns 401 after successful refresh | Job fails | `AUTH_INVALID` |
| Network error during token refresh | Retry with backoff, then fail | `AUTH_NETWORK_ERROR` |

### CLI Notification

When authentication fails for scheduled jobs:
1. Job is marked as failed with auth error code
2. `GetAuthStatus` RPC returns `needs_reauth: true`
3. CLI can prompt user to re-login when they next interact
