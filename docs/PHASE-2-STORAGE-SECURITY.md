# Phase 2: Storage & Security

*Depends on: Phase 1*

## Overview

This phase implements the SQLite storage layer and encryption utilities for secure token storage. All sensitive data (access tokens, refresh tokens) is encrypted at rest using AES-256-GCM with Argon2id key derivation.

## Tasks

### 1. SQLite Database Connection

- [ ] **Write tests first:** `internal/storage/sqlite_test.go`
  - [ ] Test database opens successfully with valid path
  - [ ] Test database creates parent directories if missing
  - [ ] Test in-memory database (`:memory:`) for unit tests
  - [ ] Test connection pool settings are applied
  - [ ] Test Close() releases resources
- [ ] Create `internal/storage/sqlite.go`:
  - [ ] Define `DB` struct wrapping `*sql.DB`
  - [ ] Implement `Open(path string) (*DB, error)`
  - [ ] Implement `OpenInMemory() (*DB, error)` for testing
  - [ ] Configure connection pool (max open conns, max idle, conn lifetime)
  - [ ] Enable WAL mode and foreign keys: `PRAGMA journal_mode=WAL; PRAGMA foreign_keys=ON;`
  - [ ] Implement `Close() error`
  - [ ] Implement `Ping() error` for health checks

### 2. Database Migrations Framework

- [ ] **Write tests first:** `internal/storage/migrations_test.go`
  - [ ] Test migrations run in order
  - [ ] Test migration version is tracked
  - [ ] Test already-applied migrations are skipped
  - [ ] Test rollback on migration failure
  - [ ] Test migration from empty database
- [ ] Create `internal/storage/migrations.go`:
  - [ ] Define `Migration` struct: `Version int`, `Name string`, `Up string`, `Down string`
  - [ ] Create `migrations` slice with all migrations in order
  - [ ] Implement `Migrate(db *DB) error` to run pending migrations
  - [ ] Create `schema_migrations` table to track applied versions
  - [ ] Implement `CurrentVersion(db *DB) (int, error)`
- [ ] Create `migrations/001_initial.sql` with base schema (embedded via `embed`)

### 3. Schema: Jobs Table

- [ ] Add to `001_initial.sql`:
  ```sql
  CREATE TABLE jobs (
      id TEXT PRIMARY KEY,
      command TEXT NOT NULL,
      payload BLOB,
      priority INTEGER DEFAULT 0,
      status TEXT NOT NULL DEFAULT 'pending',
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      started_at DATETIME,
      completed_at DATETIME,
      result BLOB,
      error TEXT,
      retry_count INTEGER DEFAULT 0,
      max_retries INTEGER DEFAULT 3
  );
  CREATE INDEX idx_jobs_status ON jobs(status);
  CREATE INDEX idx_jobs_priority ON jobs(priority DESC, created_at ASC);
  ```
- [ ] **Write tests first:** `internal/storage/jobs_test.go`
  - [ ] Test CreateJob inserts new job
  - [ ] Test GetJob retrieves job by ID
  - [ ] Test GetJob returns error for non-existent job
  - [ ] Test UpdateJobStatus changes status and updated_at
  - [ ] Test ListJobs filters by status
  - [ ] Test ListJobs orders by priority DESC, created_at ASC
  - [ ] Test DeleteJob removes job
  - [ ] Test GetPendingJobs returns jobs ordered for worker pickup
- [ ] Create `internal/storage/jobs.go`:
  - [ ] Define `Job` struct matching schema
  - [ ] Implement `CreateJob(job *Job) error`
  - [ ] Implement `GetJob(id string) (*Job, error)`
  - [ ] Implement `UpdateJobStatus(id, status string) error`
  - [ ] Implement `UpdateJobResult(id string, result []byte, err string) error`
  - [ ] Implement `ListJobs(filter JobFilter) ([]*Job, error)`
  - [ ] Implement `GetPendingJobs(limit int) ([]*Job, error)`
  - [ ] Implement `IncrementRetryCount(id string) error`
  - [ ] Implement `DeleteJob(id string) error`

### 4. Schema: Schedules Table

- [ ] Add to `001_initial.sql`:
  ```sql
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
  CREATE INDEX idx_schedules_enabled ON schedules(enabled);
  ```
- [ ] **Write tests first:** `internal/storage/schedules_test.go`
  - [ ] Test CreateSchedule inserts new schedule
  - [ ] Test CreateSchedule fails on duplicate name
  - [ ] Test GetSchedule retrieves by ID
  - [ ] Test GetScheduleByName retrieves by name
  - [ ] Test UpdateSchedule modifies fields
  - [ ] Test ListSchedules returns all schedules
  - [ ] Test ListEnabledSchedules filters by enabled=1
  - [ ] Test DeleteSchedule removes schedule
  - [ ] Test UpdateLastRunAt sets timestamp
- [ ] Create `internal/storage/schedules.go`:
  - [ ] Define `Schedule` struct matching schema
  - [ ] Implement `CreateSchedule(schedule *Schedule) error`
  - [ ] Implement `GetSchedule(id string) (*Schedule, error)`
  - [ ] Implement `GetScheduleByName(name string) (*Schedule, error)`
  - [ ] Implement `UpdateSchedule(schedule *Schedule) error`
  - [ ] Implement `ListSchedules() ([]*Schedule, error)`
  - [ ] Implement `ListEnabledSchedules() ([]*Schedule, error)`
  - [ ] Implement `DeleteSchedule(id string) error`
  - [ ] Implement `UpdateLastRunAt(id string, t time.Time) error`

### 5. Schema: Config Table

- [ ] Add to `001_initial.sql`:
  ```sql
  CREATE TABLE config (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
  );
  ```
- [ ] **Write tests first:** `internal/storage/config_test.go`
  - [ ] Test SetConfig inserts new key-value
  - [ ] Test SetConfig updates existing key
  - [ ] Test GetConfig retrieves value
  - [ ] Test GetConfig returns error for missing key
  - [ ] Test DeleteConfig removes key
  - [ ] Test ListConfig returns all key-values
- [ ] Create `internal/storage/config.go`:
  - [ ] Implement `SetConfig(key, value string) error`
  - [ ] Implement `GetConfig(key string) (string, error)`
  - [ ] Implement `GetConfigOrDefault(key, defaultValue string) string`
  - [ ] Implement `DeleteConfig(key string) error`
  - [ ] Implement `ListConfig() (map[string]string, error)`

### 6. Schema: API Environments Table

- [ ] Add to `001_initial.sql`:
  ```sql
  CREATE TABLE api_environments (
      id TEXT PRIMARY KEY,
      name TEXT UNIQUE NOT NULL,
      base_url TEXT NOT NULL,
      is_active INTEGER DEFAULT 0,
      description TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
  );
  CREATE INDEX idx_api_environments_active ON api_environments(is_active);
  ```
- [ ] **Write tests first:** `internal/storage/environments_test.go`
  - [ ] Test CreateEnvironment inserts new environment
  - [ ] Test CreateEnvironment fails on duplicate name
  - [ ] Test GetEnvironment retrieves by ID
  - [ ] Test GetEnvironmentByName retrieves by name
  - [ ] Test GetActiveEnvironment returns active environment
  - [ ] Test GetActiveEnvironment returns nil when none active
  - [ ] Test SetActiveEnvironment deactivates previous and activates new
  - [ ] Test ListEnvironments returns all environments
  - [ ] Test DeleteEnvironment fails if environment is active
  - [ ] Test DeleteEnvironment succeeds for inactive environment
- [ ] Create `internal/storage/environments.go`:
  - [ ] Define `Environment` struct matching schema
  - [ ] Implement `CreateEnvironment(env *Environment) error`
  - [ ] Implement `GetEnvironment(id string) (*Environment, error)`
  - [ ] Implement `GetEnvironmentByName(name string) (*Environment, error)`
  - [ ] Implement `GetActiveEnvironment() (*Environment, error)`
  - [ ] Implement `SetActiveEnvironment(id string) error` (transactional)
  - [ ] Implement `ListEnvironments() ([]*Environment, error)`
  - [ ] Implement `DeleteEnvironment(id string) error`

### 7. Schema: Auth Tokens Table

- [ ] Add to `001_initial.sql`:
  ```sql
  CREATE TABLE auth_tokens (
      id TEXT PRIMARY KEY,
      environment_id TEXT NOT NULL,
      username TEXT,
      encrypted_access_token BLOB NOT NULL,
      access_token_expires_at DATETIME,
      encrypted_refresh_token BLOB,
      refresh_token_expires_at DATETIME,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      UNIQUE(environment_id, username),
      FOREIGN KEY (environment_id) REFERENCES api_environments(id) ON DELETE CASCADE
  );
  ```
- [ ] **Write tests first:** `internal/storage/tokens_test.go`
  - [ ] Test SaveTokens inserts new token record
  - [ ] Test SaveTokens updates existing token for same environment/user
  - [ ] Test GetTokens retrieves tokens for environment
  - [ ] Test GetTokens returns error when not found
  - [ ] Test DeleteTokens removes tokens for environment
  - [ ] Test tokens are deleted when environment is deleted (CASCADE)
- [ ] Create `internal/storage/tokens.go`:
  - [ ] Define `AuthTokens` struct (stores encrypted blobs)
  - [ ] Implement `SaveTokens(tokens *AuthTokens) error`
  - [ ] Implement `GetTokens(environmentID string) (*AuthTokens, error)`
  - [ ] Implement `GetTokensByUsername(environmentID, username string) (*AuthTokens, error)`
  - [ ] Implement `DeleteTokens(environmentID string) error`
  - [ ] Implement `DeleteAllTokens() error` (for logout from all)

### 8. AES-256-GCM Encryption

- [ ] **Write tests first:** `internal/crypto/encryption_test.go`
  - [ ] Test Encrypt produces different ciphertext each time (random nonce)
  - [ ] Test Decrypt recovers original plaintext
  - [ ] Test Decrypt fails with wrong key
  - [ ] Test Decrypt fails with tampered ciphertext
  - [ ] Test Encrypt/Decrypt with empty plaintext
  - [ ] Test Encrypt/Decrypt with large plaintext
- [ ] Create `internal/crypto/encryption.go`:
  - [ ] Implement `Encrypt(plaintext, key []byte) ([]byte, error)`
    - [ ] Generate random 12-byte nonce
    - [ ] Create AES-GCM cipher
    - [ ] Seal plaintext with nonce
    - [ ] Return nonce + ciphertext concatenated
  - [ ] Implement `Decrypt(ciphertext, key []byte) ([]byte, error)`
    - [ ] Extract nonce from first 12 bytes
    - [ ] Create AES-GCM cipher
    - [ ] Open and verify ciphertext
  - [ ] Add key length validation (must be 32 bytes for AES-256)

### 9. Argon2id Key Derivation

- [ ] **Write tests first:** `internal/crypto/kdf_test.go`
  - [ ] Test DeriveKey produces 32-byte key
  - [ ] Test DeriveKey with same password+salt produces same key
  - [ ] Test DeriveKey with different passwords produces different keys
  - [ ] Test DeriveKey with different salts produces different keys
  - [ ] Test GenerateSalt produces random 16-byte salt
- [ ] Create `internal/crypto/kdf.go`:
  - [ ] Define Argon2id parameters (time=1, memory=64MB, threads=4)
  - [ ] Implement `DeriveKey(password, salt []byte) []byte`
  - [ ] Implement `GenerateSalt() ([]byte, error)`
  - [ ] Implement `DeriveKeyWithParams(password, salt []byte, time, memory uint32, threads uint8) []byte`

### 10. Token Encryption Integration

- [ ] **Write tests first:** `internal/auth/tokens_test.go`
  - [ ] Test EncryptTokens encrypts access and refresh tokens
  - [ ] Test DecryptTokens recovers original tokens
  - [ ] Test token expiry times are preserved
- [ ] Create `internal/auth/tokens.go`:
  - [ ] Define `Tokens` struct (plaintext tokens + expiry times)
  - [ ] Define `EncryptedTokens` struct (encrypted blobs + expiry times)
  - [ ] Implement `EncryptTokens(tokens *Tokens, key []byte) (*EncryptedTokens, error)`
  - [ ] Implement `DecryptTokens(encrypted *EncryptedTokens, key []byte) (*Tokens, error)`
  - [ ] Implement key management: derive from machine ID or stored secret

## Deliverable

Working database layer with encrypted token storage

## Details

### Database Schema

**Database path:** `~/.honeydew/daemon.db`

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

### Encryption

**Location:** `internal/crypto/`

- **AES-256-GCM** for token encryption at rest
- **Argon2id** for key derivation from user password/system key
- Tokens never stored in plaintext
