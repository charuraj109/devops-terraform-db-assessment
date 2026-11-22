# DevOps Assessment: Terraform + Database Reliability

AWS design (`Internet → ALB → ECS/Fargate → RDS PostgreSQL`) in Terraform, plus a local
PostgreSQL setup with migrations, seed data, an optimized query, and backup/restore scripts.
Nothing is deployed to AWS; Terraform is validated with `fmt`, `validate` and `plan`.

```
Internet ──► ALB (public subnets, SG: 80 from 0.0.0.0/0)
               │  only the ALB SG may reach the app port
               ▼
         ECS Fargate tasks (private subnets, SG: app port from ALB SG)
               │  only the ECS SG may reach 5432
               ▼
         RDS PostgreSQL (private subnets, publicly_accessible = false, SG: 5432 from ECS SG)
```

## Repo layout
```
infra/modules/{network,ecs,rds}   reusable modules
infra/envs/{dev,prod}             per-env main/variables/tfvars/backend
db/migrations                     schema + index SQL
db/seed/seed.sql                  seed data (100,000 bookings)
scripts/{backup,restore}.sh       backup and restore
docker-compose.yml                local PostgreSQL 16
.github/workflows                 Terraform PR plan workflow
```

## Part 1: Local database (Docker)

Prerequisites: Docker with Compose v2.

```bash
docker compose up -d          # starts Postgres, runs schema + seed + index automatically
docker compose ps             # wait until "healthy"
docker compose exec db psql -U app -d appdb -c "SELECT count(*) FROM hotel_bookings;"
```
Defaults: user `app`, password `app_password`, db `appdb`, port `5432` (bound to `127.0.0.1` only).
These are throwaway credentials for a local test database with sample data. To override them, copy
`.env.example` to `.env` (gitignored). In AWS there is no password in code: RDS generates it and stores it in Secrets Manager.

**Persistence:** data lives in the named volume `pgdata`, so it survives `docker compose down`/`up`.
`docker compose down -v` deletes the volume. A volume is not a backup; use `scripts/backup.sh` for that.
Init scripts run only on the first start of an empty volume. To reset: `docker compose down -v && docker compose up -d`.

Seed data: 100,000 bookings, 8 cities (incl. `delhi`), 4 organizations, 4 statuses
(`confirmed`, `pending`, `cancelled`, `completed`), ~200k booking events (created / status_changed / refund_issued).

### Query optimization

```sql
SELECT org_id, status, COUNT(*), SUM(amount)
FROM hotel_bookings
WHERE city = 'delhi' AND created_at >= NOW() - INTERVAL '30 days'
GROUP BY org_id, status;
```

Index added (`db/migrations/002_add_indexes.sql`):

```sql
CREATE INDEX idx_hotel_bookings_city_created_cover
    ON hotel_bookings (city, created_at) INCLUDE (org_id, status, amount);
```

Why:
- `city` is an equality filter, so it goes first. `created_at` is a range filter, so it goes second.
  Postgres can then read one contiguous slice of the index.
- `INCLUDE (org_id, status, amount)` stores the other columns the query reads. This enables an
  **index-only scan**: no table lookups at all (`Heap Fetches: 0`).
- The included columns are not part of the sort key, so the index stays smaller than a 4-column key.
- Also added `booking_events (booking_id)` for looking up events of a booking.

Reproduce the comparison: `./scripts/explain_before_after.sh`

| | Plan | Execution time |
|---|---|---|
| Before | Seq Scan on hotel_bookings | ~24 ms |
| After  | Index Only Scan, Heap Fetches: 0 | ~2 ms |

(Measured on a laptop-class container; absolute numbers vary, the plan change is the point.)

## Part 2: Backup and restore

```bash
./scripts/backup.sh      # -> backups/appdb_YYYYMMDD_HHMMSS.dump (pg_dump custom format)
./scripts/restore.sh     # restores the newest dump into a FRESH db "appdb_restore"
./scripts/restore.sh backups/appdb_20260101_120000.dump   # or a specific file
```

`restore.sh` drops and recreates `appdb_restore`, runs `pg_restore`, then **verifies automatically**:
it compares row counts of both tables and the number of indexes between `appdb` and `appdb_restore`
and exits non-zero on any mismatch. Expected output ends with `Restore verified successfully.`

Manual verification:
```bash
docker compose exec db psql -U app -d appdb_restore -c "SELECT count(*) FROM hotel_bookings;"   # 100000
docker compose exec db psql -U app -d appdb_restore -c "SELECT count(*) FROM booking_events;"
docker compose exec db psql -U app -d appdb_restore -c "\di"                                    # indexes present
```
Stronger test: delete rows in `appdb`, restore, and confirm they exist in `appdb_restore`.

## Part 3: Terraform

Prerequisites: Terraform >= 1.5. **No AWS credentials needed**: `plan_only = true` (default in tfvars)
makes the provider skip credential/account checks, and AZs are passed as variables instead of data lookups.

```bash
cd infra
terraform fmt -recursive -check
cd envs/dev          # or envs/prod
terraform init
terraform validate
terraform plan -refresh=false -var-file=terraform.tfvars
```

| Setting | dev | prod |
|---|---|---|
| RDS instance | db.t3.micro | db.t3.large |
| Multi-AZ | no | yes |
| Backup retention | 1 day | 14 days |
| Deletion protection | **false** | **true** |
| Final snapshot | skipped | taken |
| NAT gateways | 1 shared | 1 per AZ |
| Fargate task / count | 0.25 vCPU, 512 MB / 1 | 1 vCPU, 2 GB / 3 |
| Log retention | 7 days | 90 days |

Design decisions:
- **RDS is private**: `publicly_accessible = false`, private subnets only, and its security group allows
  5432 **only from the ECS security group** (no CIDR rules). It has no egress rules.
- **ECS is private**: tasks have no public IPs; only the ALB SG can reach the app port. Outbound is limited
  to 443 (image pull/Secrets Manager/logs via NAT) and 5432 to the RDS SG.
- **No passwords in code**: `manage_master_user_password = true` makes RDS generate and store the credentials in
  Secrets Manager; the ECS execution role can read only that secret and injects it into the container.
- **State per environment**: `backend.tf` uses local state (one file per env) so `terraform init` works
  anywhere. `backend-s3.tf.example` in each env holds the real S3 + DynamoDB lock config with a separate key per
  env; rename it to `backend.tf` to use it.
- Storage is encrypted, gp3, with autoscaling; ALB drops invalid headers; ECS has a deployment circuit breaker.
- The listener is HTTP/80 only because no certificate is available here. In production add an ACM cert, an
  HTTPS:443 listener and an HTTP→HTTPS redirect.
- Commit `.terraform.lock.hcl` after the first `terraform init` for reproducible provider versions.

## Part 4: GitHub Actions (optional)

`.github/workflows/terraform-plan.yml` runs on pull requests touching `infra/**`, for `dev` and `prod`:
`fmt -check` → `init` → `validate` → `plan -refresh=false`. The plan is shown in the **job summary**, uploaded
as an **artifact** (`tfplan-dev` / `tfplan-prod`), and posted/updated as a **PR comment**.
