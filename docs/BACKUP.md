# Backup and restore

Off-box backups of every Podman-managed database, the non-database state, and the secrets needed to
make any of it usable again. Target is **Azure Blob Storage** via **restic**, weekly, keeping 12
weeks.

- `scripts/backup.sh` — the weekly job (dump → upload → retention → integrity check)
- `scripts/restic.sh` — thin wrapper to run any restic command with the right mounts and credentials
- `systemd/user/localserver-backup.{service,timer}` — the schedule

## What is backed up

| Data | Method | Why |
|---|---|---|
| n8n Postgres (`n8n`) | `pg_dump` | workflows + credentials |
| LiteLLM Postgres (`litellm`) | `pg_dump` | API keys, spend history |
| WordPress MariaDB (`wordpress`) | `mariadb-dump --single-transaction` | the blog: 63 posts, 3 pages, 28 attachments |
| `wordpress_wordpress-data` | file copy | the **whole** `/var/www/html`: WordPress core, `wp-content` (uploads/themes/plugins) *and* `wp-config.php`. A DB restore alone gives you a blog with no images |
| `n8n_n8n-data` | file copy | n8n instance data |
| `weather-mcp_oauth-store` | file copy | issued OAuth tokens |
| GQLDB graphs (`gqldb`) | `BACKUP DATABASE` | the graph store; the server writes and verifies its own per-graph archives while serving |
| GQLDB Manager store | cold file copy | saved connections + console users; the container is stopped for the copy |
| `.env` | file copy | **see below** |
| `~/.cloudflared/` | file copy | tunnel credentials + origin cert |
| `certs/` | file copy | local CA (regenerable, but cheap to keep) |

### The two things people get wrong

**1. `.env` is the most important file in the backup.** It holds `N8N_ENCRYPTION_KEY`. Restore the
n8n database without it and every stored credential is ciphertext you can never decrypt — the
database restores "successfully" and is useless. It also holds `POSTGRES_PASSWORD` (shared by both
Postgres instances), `MARIADB_ROOT_PASSWORD`, `WORDPRESS_DB_PASSWORD` and the cloud API keys. It is
gitignored, so this backup is its only copy.

**2. The database volumes are excluded on purpose.** `postgres-data`,
`litellm_litellm-postgres` and `wordpress_wordpress-db` are never copied as files. Copying a running
database's data directory without a filesystem snapshot produces a torn image that often will not
restore. `scripts/restic.sh` mounts only the non-database volumes so this cannot happen by accident.

**3. Restoring the graph database resets its admin password.** `RESTORE DATABASE` overwrites
`__system__`, which is where GQLDB keeps its RBAC users — so after a restore the admin password is
the one that was in force **when the backup was taken**, not whatever `GQLDB_ADMIN_PASSWORD` the
container was started with. This is verified behaviour, not a guess: a restore into a fresh
instance rejected the new container's password and accepted the backup's. Expect it, or you will
conclude the restore failed when it actually worked.

Because the snapshot contains `.env`, **restic's client-side encryption is load-bearing**, not a
nicety: anyone with the Azure storage key still cannot read the backup without `RESTIC_PASSWORD`.

## One-time setup

1. Storage account and key:
   ```bash
   az login
   az storage account list -o table
   az storage account keys list -n <account> --query "[0].value" -o tsv
   ```
2. On beeblebox, create `~/.config/localserver/backup.env` — **`chmod 600`, never in the repo**:
   ```
   AZURE_ACCOUNT_NAME=<account>
   AZURE_ACCOUNT_KEY=<key>
   RESTIC_REPOSITORY=azure:beeblebox-backups:/
   RESTIC_PASSWORD=<long random passphrase>
   ```
   `scripts/restic.sh` refuses to run if this file is group- or world-readable.
   restic creates the blob container itself; you do not need to pre-create it.

3. **Put `RESTIC_PASSWORD` in your password manager before the first run.** If it lives only on
   beeblebox, the disaster that destroys beeblebox also destroys the only means of reading the
   backups. This is the most common way a scheme like this fails.

4. Initialise and run once by hand:
   ```bash
   ./scripts/restic.sh init
   ./scripts/backup.sh
   ```

5. Install and start the schedule:
   ```bash
   ./scripts/sudo/bootstrap-host.sh        # installs the .timer too
   systemctl --user start localserver-backup.timer
   systemctl --user list-timers localserver-backup.timer
   ```

Consider replacing the account key with a **SAS token** (`AZURE_ACCOUNT_SAS`) scoped to just that
blob container — it limits the blast radius if beeblebox is compromised.

## Routine checks

```bash
./scripts/restic.sh snapshots           # expect one per week, newest first
./scripts/restic.sh check               # structural integrity
./scripts/restic.sh stats latest        # size of the most recent snapshot
systemctl --user status localserver-backup.service   # last run's exit status
journalctl --user -u localserver-backup.service -n 50
```

## Restore

Everything lands under `/backup/...` inside a snapshot. `scripts/restic.sh` mounts
`~/restic-work` as `/work`, which is where restores should go.

**Restored files contain plaintext secrets. Delete the restore directory when finished.**

### Find and extract

```bash
./scripts/restic.sh snapshots
./scripts/restic.sh restore latest --target /work/restore            # everything
./scripts/restic.sh restore latest --target /work/restore --include /backup/dumps
ls -R ~/restic-work/restore | head -40
cat ~/restic-work/restore/backup/dumps/manifest.txt   # which image versions produced the dumps
```

Check `manifest.txt` before restoring a Postgres dump — a PG 16 dump will not load into PG 15.

### WordPress

```bash
# database
zcat ~/restic-work/restore/backup/dumps/wordpress-mariadb.sql.gz \
  | podman exec -i -e MYSQL_PWD="$MARIADB_ROOT_PASSWORD" wordpress_db_1 mariadb -u root

# the whole site tree (core + wp-content + wp-config.php). uid 33 = www-data in the
# Debian-based wordpress image; the Alpine-based wordpress:cli image uses 82, which is
# why scripts/wp-cli.sh resolves the owning uid rather than assuming.
podman run --rm \
  -v ~/restic-work/restore/backup/volumes/wordpress_wordpress-data:/src:ro \
  -v wordpress_wordpress-data:/dst \
  docker.io/library/alpine:latest sh -c 'cp -a /src/. /dst/ && chown -R 33:33 /dst'

./scripts/wp-cli.sh post list --post_type=post --post_status=publish --format=count
```

### n8n / LiteLLM

```bash
zcat ~/restic-work/restore/backup/dumps/n8n-postgres.sql.gz \
  | podman exec -i -e PGPASSWORD="$POSTGRES_PASSWORD" n8n_postgres_1 psql -U n8n -d n8n
```

Restore `.env` **first** if you are rebuilding the host — the dump's credentials are encrypted with
the `N8N_ENCRYPTION_KEY` inside it. Then recreate the container so it re-reads the environment
(`./scripts/start-stack.sh n8n up`); a plain restart does not.

LiteLLM is the same with `-U litellm -d litellm`, into a **PG 16** instance.

### GQLDB

The archive is a *directory* per run (one `<graph>.gqlbackup.tar.gz` each, plus
`db_backup_meta.json` and `meta.json`), not a single file. Stage it where the container can see it
and restore with the `OVERWRITE` keyword — without it the restore stops at the first graph that
already exists:

```bash
podman cp ~/restic-work/restore/backup/dumps/gqldb gqldb_gqldb_1:/restore
podman exec -i gqldb_gqldb_1 sh -c '
  S=$(jq -nc --arg u admin --arg p "$GQLDB_RBAC_ADMIN_PASSWORD" "{username:\$u,password:\$p}" |
      grpcurl -plaintext -import-path /opt/gqldb -proto gqldb.proto -d @ \
        127.0.0.1:60061 gqldb.SessionService/Login | jq -r .sessionId)
  jq -nc "{gql:\"RESTORE DATABASE FROM \\\"/restore\\\" OVERWRITE\"}" |
    grpcurl -plaintext -import-path /opt/gqldb -proto gqldb.proto \
      -H "session-id: $S" -d @ 127.0.0.1:60061 gqldb.QueryService/Gql'
```

Then log in with the password **from the backup** (see gotcha 3 above) and check the data is there.

Community Edition allows **2 user graphs** (`__system__` does not count — measured, the server
refuses the third with `database limit exceeded: current 2, limit 2`). A restore that would exceed
that fails, so restoring alongside existing graphs may need one dropped first.

The console's own store is backed up as a whole-volume tar (`gqldb-manager.tar`, taken with the
container stopped). Restore it the same way, with the stack down:

```bash
./scripts/start-stack.sh gqldb down
podman volume rm gqldb_manager-data
podman volume import gqldb_manager-data ~/restic-work/restore/backup/dumps/gqldb-manager.tar
./scripts/start-stack.sh gqldb up
```

`.env` must be restored first: the saved connection passwords inside that store are encrypted with
`MANAGER_ENCRYPTION_KEY`, exactly as n8n's credentials depend on `N8N_ENCRYPTION_KEY`. Without it
the console starts fine and every saved connection is undecryptable — delete and re-create them.

### Rebuilding the host from nothing

1. Install Podman, clone this repo, run `./scripts/sudo/bootstrap-host.sh`.
2. Restore `backup/config/env` to `~/localserver-config/.env` — **before** anything else.
3. Restore `backup/config/cloudflared/` to `~/.cloudflared/` (tunnel credentials; the tunnel is
   registered to that credential file, so a new one means re-routing DNS).
4. `./scripts/deploy.sh` to bring the stacks up empty.
5. Load the three dumps, then the `wordpress-data` volume.
6. Verify per the checks above.

## Testing the restore

A backup that has never been restored is not a backup. Once a quarter, load the WordPress dump into
a **throwaway** MariaDB container — never into `wordpress_db_1` — and confirm the counts:

```bash
podman run -d --name restore-test -e MARIADB_ROOT_PASSWORD=test docker.io/library/mariadb:11.8
sleep 20
zcat ~/restic-work/restore/backup/dumps/wordpress-mariadb.sql.gz \
  | podman exec -i -e MYSQL_PWD=test restore-test mariadb -u root
podman exec -e MYSQL_PWD=test restore-test mariadb -u root -N -e \
  "SELECT post_type, post_status, COUNT(*) FROM wordpress.wp_posts
    GROUP BY post_type, post_status ORDER BY 3 DESC;"
podman rm -f restore-test
```

**Compare that against production rather than against fixed numbers** — the counts drift as you
publish, trash and edit, so a hardcoded expectation goes stale and starts producing false alarms:

```bash
podman exec -e MYSQL_PWD="$MARIADB_ROOT_PASSWORD" wordpress_db_1 mariadb -u root -N -e \
  "SELECT post_type, post_status, COUNT(*) FROM wordpress.wp_posts
    GROUP BY post_type, post_status ORDER BY 3 DESC;"
```

The two outputs must match line for line. (Verified 2026-08-30: they did — 63 published posts,
29 attachments, 29 categories, 126 tags, identical in both.)

Finally, remove the restore directory — it holds a plaintext `.env`, `wp-config.php` and the
cloudflared credentials.

**Plain `rm -rf` will not work**, and this trips people up every time. restic runs as root inside
the container and restores the original ownership, so the WordPress files come back owned by
container uid 33 — which rootless podman maps to a subuid (e.g. `100032`) that your login user does
not own. `rm` returns "Permission denied" per file and silently leaves the secrets on disk. Delete
from inside the user namespace instead:

```bash
podman unshare rm -rf ~/restic-work/restore-test
```

Always confirm it is actually gone (`ls -A ~/restic-work`) rather than assuming the `rm` succeeded.
