---

name: run-local
description: Non-developer-friendly way to set up and run the SuMS app on their local machine. Use when user says to "run app", and after user creates a new feature to test runs and builds.

---

## Phase 1 — Pre-flight checks

Run these checks first. Do not proceed to Phase 2 until all are resolved.

### 1.1 Docker installed

```bash
docker --version
```

**If the command is not found:**
Tell the user Docker is not installed and give them the install link: https://www.docker.com/products/docker-desktop/
Tell them to install it, open Docker Desktop until the whale icon shows "running", then invoke `/run-local` again.
Stop here.

### 1.2 Docker running

```bash
docker info
```

**If this errors** (e.g. "Cannot connect to the Docker daemon"):
Tell the user Docker is installed but not running. Ask them to open Docker Desktop and wait until the whale icon in their taskbar/menu bar shows "Docker Desktop is running", then invoke `/run-local` again.
Stop here.

### 1.3 .env file

Check whether `.env` exists.

```bash
ls -la .env 2>/dev/null && echo "EXISTS" || echo "MISSING"
```

**If MISSING:**
- Check whether `.env.example` exists.
- If it does, copy it: `cp .env.example .env`
- Tell the user you have created `.env` from the template and that they need to fill in the required values (see Phase 1.4). Open `.env` for them to review.
- Stop after showing them what needs to be filled in — they need to save it and invoke `/run-local` again.

**If EXISTS:**
Load the file into your shell for later checks:
```bash
set -a; source .env; set +a
```

### 1.4 Required environment variables

Check each variable. Use the exact names below.

**Hard blockers — the app cannot start without these:**

| Variable | What it is |
|---|---|
| `DATABASE_URL` | PostgreSQL connection string |
| `NEXTAUTH_SECRET` | Random 32+ character string for session signing |

**OTPaaS — required for login to work (soft warning if missing):**

| Variable | What it is |
|---|---|
| `OTPAAS_BASE_URL` | Base URL of the OTPaaS service |
| `OTPAAS_NAMESPACE` | Your app's namespace in OTPaaS |
| `OTPAAS_APP_ID` | App identifier used to derive the API key |
| `OTPAAS_SECRET` | HMAC secret for API key generation |

For each variable, run:
```bash
printenv VAR_NAME | wc -c
```
A result of `0` or `1` means it is unset or empty.

**If any hard-blocker variable is missing:**
Tell the user exactly which variable is missing and what it is used for. Ask them to open `.env`, add the value, save the file, then invoke `/run-local` again. Stop here.

**If OTPaaS variables are missing:**
Tell the user the app will start but login will fail until all four are set. Explain they need to contact their OTPaaS administrator (TechPass OTPaaS) to get the values. Reference the docs: https://docs.developer.tech.gov.sg/docs/techpass-otpaas-api/ — then continue.

---

## Phase 2 — Build and start

### 2.1 Check for an existing setup

```bash
docker compose -f docker-compose.local.yml ps --all 2>/dev/null
```

- **If containers are listed:** Tell the user this looks like a returning setup.
  - Ask: "Do you want to rebuild the Docker image? Only needed if you have pulled new code changes."
  - If yes: run `docker compose -f docker-compose.local.yml build` and show progress.
  - If no: skip the build.
- **If no containers:** Tell the user this is a first-time setup and you will build the image now (may take a few minutes).
  - Run: `docker compose -f docker-compose.local.yml build`

**If the build fails**, examine the error output carefully:
- **"no space left on device"** → Tell the user their disk is full. Ask them to run `docker system prune` to free space, then try again.
- **Network errors / timeouts pulling base image** → Ask them to check their internet connection and try again.
- **TypeScript / compile errors in the output** → This is a code issue. Read the error, diagnose it, and offer to fix it.
- **Any other error** → Read the full error message, explain what it means in plain language, and suggest the most likely fix.

### 2.2 Check port 3000

```bash
lsof -ti :3000 2>/dev/null | head -5 || true
```

**If a PID is returned**, something is already using port 3000.
Tell the user and ask: "There is already something running on port 3000. Should I stop it?"
If yes: `kill -9 $(lsof -ti :3000 2>/dev/null)` then confirm the port is free.

### 2.3 Start the services

```bash
docker compose -f docker-compose.local.yml up -d
```

This starts: PostgreSQL, runs database migrations, starts the app.

**If this fails**, check the logs for the failing service:
```bash
docker compose -f docker-compose.local.yml logs --tail=50
```
Then diagnose:
- **Migration failure** (e.g. "relation does not exist", "could not connect to database"):
  - Check postgres is healthy: `docker compose -f docker-compose.local.yml ps postgres`
  - If postgres is not healthy: `docker compose -f docker-compose.local.yml logs postgres`
  - Common fix: `docker compose -f docker-compose.local.yml restart postgres` then retry `up -d`
- **App crash on startup** (e.g. missing env var in logs):
  - Read the app logs: `docker compose -f docker-compose.local.yml logs app`
  - Identify the missing var and guide the user to add it to `.env`
- **Port conflict inside compose** → Confirm port 3000 is free (Phase 2.2) and retry.

### 2.4 Verify the app is responding

Wait a moment for the app to initialise, then check it is up:

```bash
sleep 5 && curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/
```

- **200 or 3xx** → the app is running. Tell the user.
- **000 (connection refused)** → the app has not started yet. Check logs:
  ```bash
  docker compose -f docker-compose.local.yml logs --tail=30 app
  ```
  Wait another 10 seconds and retry the curl. If it still fails after two attempts, read the log output and diagnose the specific error.

---

## Phase 3 — Seed data

Ask the user: "Do you want to seed the database with reference data? This is needed on first setup or after wiping the database."

Explain: The seed loads quota limits, category config, and other values the app needs to display correctly.

If yes:
```bash
docker compose -f docker-compose.local.yml --profile seed run --rm seed
```

**If the seed fails:**
- Read the error output.
- If it is a connection error, check postgres is healthy first.
- If it is a constraint/duplicate error, the database may already be seeded — tell the user this is likely fine.

---

## Phase 4 — Admin user

Ask the user: "Do you need to create an admin user? Skip this if you already have one."

If yes:

**Email:** Check whether `ADMIN_EMAIL` is already set in `.env`.
- If set, show the value and ask if they want to use it.
- If not set, ask them to type it.

**Role:** Ask which role this user should have:
- `admin` (default) — full access
- `director` — read-only elevated access
- `div_rep` — divisional representative; requires a division name

If `div_rep`, ask for the division name.

**OTPaaS reminder:** Before creating the user, tell the user:
> "Important: the email address you are using must be allowlisted in OTPaaS before you can log in. If you see the error 'code: 2005 — Unauthorised email' on the login page, ask your OTPaaS administrator to add this address."

Then run (adjust `--role` and `--division` as needed):
```bash
ADMIN_EMAIL="<email>" docker compose -f docker-compose.local.yml \
  --profile create-admin run --rm create-admin \
  npx tsx scripts/create-admin.ts --role=<role> [--division=<division>]
```

**If the user already exists** (Prisma unique constraint error): Tell the user the account already exists and they can go straight to logging in.

**If the database is not reachable**: Confirm the app services are running (Phase 2.3) and retry.

---

## Phase 5 — Done

Tell the user:

- The app is running at → http://localhost:3000
- Login at → http://localhost:3000/admin/login
- If OTPaaS is configured, an OTP will be sent to their email on login
- If they see "code: 2005", their email is not yet allowlisted — contact the OTPaaS administrator

Useful commands (show these):
```
Stop the app:   docker compose -f docker-compose.local.yml down
View logs:      docker compose -f docker-compose.local.yml logs -f app
Wipe all data:  docker compose -f docker-compose.local.yml down -v
Run again:      /run-local
```

---

## Troubleshooting reference

Use this table when diagnosing errors not covered above.

| Symptom | Likely cause | Fix |
|---|---|---|
| `Cannot connect to the Docker daemon` | Docker not running | Open Docker Desktop |
| `port is already allocated` | Port 3000 or 5432 in use | `lsof -ti :PORT \| xargs kill -9` |
| `password authentication failed` | Wrong DATABASE_URL credentials | Check `DATABASE_URL` in `.env` matches compose postgres settings |
| `relation does not exist` | Migrations not run | `docker compose -f docker-compose.local.yml restart` |
| `code: 2005` on login page | Email not in OTPaaS allowlist | Ask OTPaaS administrator to add the email |
| `NEXTAUTH_SECRET` error | Secret not set or too short | Set `NEXTAUTH_SECRET` in `.env` to a 32+ character random string |
| App returns blank page | JS bundle error | Check browser console; check `docker compose … logs app` |
| `Unique constraint failed` on create-admin | User already exists | Skip — use existing account |
| `ECONNREFUSED` in app logs | App can't reach postgres | Wait for postgres healthcheck to pass; check `docker compose … ps` |
| Build takes very long | First build or large layer cache miss | Normal on first run — wait it out |
| `no space left on device` | Docker disk full | Run `docker system prune -f` to free space |
