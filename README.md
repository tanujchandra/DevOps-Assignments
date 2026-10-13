# DevOps Assessment: Terraform + Database Reliability

Two independent halves in one repo:

| Half | What | Where |
|---|---|---|
| Infrastructure | AWS design in Terraform: `Internet -> ALB -> ECS Fargate -> RDS` (plan-only, nothing is deployed) | `infra/` |
| Database | Local PostgreSQL in Docker: schema, seed data, index, backup and restore | `docker-compose.yml`, `db/`, `scripts/` |

## Repository layout

```
.
├── docker-compose.yml            local PostgreSQL 16
├── .env.example                  optional overrides (defaults already built in)
├── db/
│   ├── migrations/               001 hotel_bookings, 002 booking_events, 003 index
│   ├── seed/seed.sql             20,000 bookings + events
│   └── queries/dashboard_query.sql   the query being optimised
├── scripts/
│   ├── backup.sh                 timestamped dump
│   ├── restore.sh                restore into a fresh DB + automatic verification
│   ├── explain.sh                query plan without / with the index
│   └── common.sh                 shared helpers
├── infra/
│   ├── modules/{network,ecs,rds}/
│   └── envs/{dev,prod}/          backend.tf, variables.tf, *.tfvars per environment
└── .github/workflows/terraform.yml   PR checks (fmt, init, validate, plan)
```

## Prerequisites
- Docker with the Compose plugin (`docker compose`)
- Terraform >= 1.5
- bash (Linux, macOS, WSL, or Git Bash on Windows)

---

## Part A: Database (local)

### 1. Start
```bash
docker compose up -d
docker compose ps          # wait until the db service shows "healthy"
```
On first start PostgreSQL runs, in order: `001` and `002` (tables), `003` (index), then the seed.
The healthcheck only turns healthy after all of that has finished.

Defaults: user `app`, password `app_pass`, database `hotel`, port `5432`
(override with a `.env` file, see `.env.example`).

### 2. Verify schema and seed data
```bash
docker compose exec db psql -U app -d hotel -c "\dt"
docker compose exec db psql -U app -d hotel -c "SELECT count(*) FROM hotel_bookings;"
docker compose exec db psql -U app -d hotel -c "SELECT city, count(*) FROM hotel_bookings GROUP BY city ORDER BY 2 DESC;"
docker compose exec db psql -U app -d hotel -c "SELECT status, count(*) FROM hotel_bookings GROUP BY status;"
docker compose exec db psql -U app -d hotel -c "SELECT count(DISTINCT org_id) AS orgs FROM hotel_bookings;"
docker compose exec db psql -U app -d hotel -c "SELECT event_type, count(*) FROM booking_events GROUP BY 1;"
```
Expected: 2 tables, 20,000 bookings, 5 cities, 4 statuses (CONFIRMED, COMPLETED, PENDING, CANCELLED),
5 organisations, several event types. (The assignment minimum is 100 rows; 20,000 is used so the
index is visible in query plans. Edit `generate_series` in `db/seed/seed.sql` to change it.)

Need a clean start? `docker compose down -v && docker compose up -d` (init scripts only run on an empty volume).

### 3. Query optimisation

The query:
```sql
SELECT org_id, status, COUNT(*), SUM(amount)
FROM hotel_bookings
WHERE city = 'delhi' AND created_at >= NOW() - INTERVAL '30 days'
GROUP BY org_id, status;
```

The index (`db/migrations/003_add_indexes.sql`):
```sql
CREATE INDEX idx_hotel_bookings_city_created_at
    ON hotel_bookings (city, created_at)
    INCLUDE (org_id, status, amount);
```

**Why this index**
1. **`city` first**: it is an equality filter. Equality columns go first so the index narrows to one city immediately.
2. **`created_at` second**: it is a range filter (`>= now - 30 days`). Placed right after the equality column, all matching entries sit next to each other in the index, so PostgreSQL reads one contiguous slice instead of scanning the city and filtering.
3. **`INCLUDE (org_id, status, amount)`**: these columns are only needed for `GROUP BY` and `SUM`, not for searching. Storing them in the index leaf pages lets PostgreSQL answer the whole query from the index (**Index Only Scan**) without reading the table. They are kept out of the key so the search part of the index stays small.
4. Not chosen: separate single-column indexes (the planner would have to combine two, which is slower) and `(created_at, city)` (a range column first cannot be used to seek on the equality column that follows it).

**See the difference**
```bash
./scripts/explain.sh
```
It prints the plan without the index (dropped inside a transaction that is rolled back, so nothing changes) and with it.
Without the index expect a `Seq Scan on hotel_bookings` over all rows; with it expect an
`Index Only Scan using idx_hotel_bookings_city_created_at` and a clearly lower execution time and
fewer buffers. Exact timings depend on your machine.

### 4. Backup
```bash
./scripts/backup.sh
ls -lh backups/
```
Creates `backups/hotel_<YYYYmmdd_HHMMSS>.sql.gz` (a `pg_dump`, gzip-compressed, integrity-tested).
Run it again later to get another timestamped file.

### 5. Restore into a fresh database and verify
```bash
./scripts/restore.sh                      # newest backup
./scripts/restore.sh backups/<file>.sql.gz  # or a specific one
```
The script drops and recreates a **separate** database named `hotel_restored` (it refuses to touch the
source DB), restores the dump into it, then compares source and restored automatically:

| Check | Meaning |
|---|---|
| row counts | `hotel_bookings` and `booking_events` have the same number of rows |
| content md5 | a hash over every row of both tables is identical |
| index exists | `idx_hotel_bookings_city_created_at` was restored |
| report query | the delhi aggregate returns identical results |

It prints `PASS` / `FAIL` per check and exits non-zero on any mismatch. Final line on success:
`Restore verified OK`.

**Manual verification (optional)**
```bash
docker compose exec db psql -U app -d hotel_restored -c "SELECT count(*) FROM hotel_bookings;"
docker compose exec db psql -U app -d hotel_restored -c "SELECT count(*) FROM booking_events;"
docker compose exec db psql -U app -d hotel_restored -c "\di idx_hotel_bookings_city_created_at"
```
The counts must equal the same queries against `-d hotel`.

---

## Part B: Terraform infrastructure

```
Internet -> ALB (public subnets) -> ECS Fargate (private subnets) -> RDS PostgreSQL (private subnets)
```

| Module | Contains |
|---|---|
| `modules/network` | VPC, public and private subnets across 2 AZs, internet gateway, NAT gateway(s), route tables, **ALB / ECS / RDS security groups** |
| `modules/ecs` | ALB, target group, listeners, IAM roles, CloudWatch log group, ECS cluster, Fargate task definition and service (nginx placeholder image) |
| `modules/rds` | Private, encrypted PostgreSQL 16 in a DB subnet group, password generated and stored in Secrets Manager |

### Security model
| Layer | Accepts traffic from |
|---|---|
| ALB security group | Internet on 80/443 |
| ECS security group | ALB security group only (container port) |
| RDS security group | **ECS security group only** (port 5432) |

RDS has `publicly_accessible = false`, lives in private subnets, and its only ingress rule references the ECS security group
(no CIDR blocks), so nothing else can connect. All three security groups are defined in the `network` module, which avoids a
circular dependency between `ecs` and `rds` (order is `network -> rds -> ecs`).

### Environments

| Setting | dev | prod |
|---|---|---|
| RDS instance class | db.t4g.micro | db.m6g.large |
| RDS storage | 20 GB | 100 GB (autoscale to 500) |
| Backup retention | 1 day | 14 days |
| Deletion protection | false | true |
| Multi-AZ | false | true |
| Final snapshot on delete | skipped | taken |
| NAT gateways | 1 shared | 1 per AZ |
| ECS tasks | 1 x (256 CPU / 512 MiB) | 2 x (1024 CPU / 2048 MiB) |
| Log retention | 7 days | 90 days |
| ALB deletion protection | false | true |

Each environment has its own `variables.tf`, `<env>.tfvars`, `backend.tf` (separate S3 bucket, key and lock table), and sizing.

### Verify (no AWS account required)
```bash
terraform fmt -recursive infra/

cd infra/envs/dev
terraform init -backend=false
terraform validate
terraform plan -refresh=false -var-file=dev.tfvars

cd ../prod
terraform init -backend=false
terraform validate
terraform plan -refresh=false -var-file=prod.tfvars
```
- `-backend=false` skips the S3 backend, because the state bucket does not exist in this exercise.
- `mock_credentials = true` (set in the tfvars) lets the AWS provider plan without credentials.
  For a real deployment set it to `false`, create the S3 bucket and DynamoDB lock table named in `backend.tf`, and run a normal `terraform init`.

### GitHub Actions (`.github/workflows/terraform.yml`)
Runs on every pull request touching `infra/`, for both `dev` and `prod`: `terraform fmt -check`, `init`, `validate`, `plan`.
The plan is shared **two ways**: as a **PR comment** (one per environment, updated on every push) and as a downloadable
**workflow artifact** (`terraform-plan-dev`, `terraform-plan-prod`). No secrets are required.

---

## Assumptions and production notes
- Nothing is deployed to AWS; Terraform is validated through `fmt`, `validate` and `plan`.
- RDS master password is generated by RDS (`manage_master_user_password`) and never appears in code, tfvars, or Git.
- NAT gateways cost money but are required so private ECS tasks can pull images and read Secrets Manager. A cheaper alternative is VPC endpoints.
- Set `certificate_arn` (ACM) in the tfvars to enable HTTPS and an automatic HTTP to HTTPS redirect.
- The ECS task gets `DB_HOST`, `DB_PORT`, `DB_NAME` and (from Secrets Manager) `DB_USER` / `DB_PASSWORD`; the nginx placeholder does not use them.
- Local DB credentials in `docker-compose.yml` are for local testing only.
