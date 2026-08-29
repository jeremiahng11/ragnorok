# rAthena on Coolify

Private Ragnarok Online server (rAthena) packaged as a Docker Compose stack for
Coolify on Debian 12.

## Deploy

1. Push this repo to GitHub.
2. In Coolify: **Sources → GitHub** → install the Coolify GitHub App for this repo.
3. **New Resource → Docker Compose**, select the repo, branch `main`,
   base directory `/`, compose file `docker-compose.yaml`.
4. Add the environment variables from `.env.example`. `PACKETVER` must be
   available at build time.
5. Leave the FQDN / domain fields **empty** on both services. Ragnarok is raw
   TCP; if Traefik tries to route it, nothing will connect.
6. Deploy. The first build takes 5–15 minutes — `make server` is the slow part.

## Post-deploy config

The `conf/import` volume starts empty, so rAthena boots on defaults and cannot
reach the database. Open a terminal into the `rathena` container:

```bash
cp /opt/rathena/conf/import-tmpl/* /opt/rathena/conf/import/
```

Then edit `/opt/rathena/conf/import/inter_conf.txt`:

```
login_server_ip: db
login_server_db: ragnarok
login_server_id: ragnarok
login_server_pw: <DB_PASSWORD>

ipban_db_ip: db
ipban_db_db: ragnarok
ipban_db_id: ragnarok
ipban_db_pw: <DB_PASSWORD>

char_server_ip: db
char_server_db: ragnarok
char_server_id: ragnarok
char_server_pw: <DB_PASSWORD>

map_server_ip: db
map_server_db: ragnarok
map_server_id: ragnarok
map_server_pw: <DB_PASSWORD>

web_server_ip: db
web_server_db: ragnarok
web_server_id: ragnarok
web_server_pw: <DB_PASSWORD>

log_db_ip: db
log_db_db: ragnarok_logs
log_db_id: ragnarok
log_db_pw: <DB_PASSWORD>
```

`db` is the compose service name — Docker's internal DNS resolves it.

Change the inter-server credentials in `login_conf.txt`, `char_conf.txt` and
`map_conf.txt`. The defaults (`s1` / `p1`) are publicly known.

Because `conf/import` is a named volume, all of this survives redeploys.

Restart the resource from Coolify to pick up the changes.

## Networking (behind NAT)

rAthena tells the client which IP to connect to next, so `127.0.0.1` breaks any
non-local client.

In `conf/import/char_conf.txt` set `char_ip`, and in `map_conf.txt` set
`map_ip`, to your public IP or DDNS hostname.

Then edit `conf/subnet_athena.conf` so LAN clients get the LAN address rather
than hairpinning through the router. Format is `netmask:char_ip:map_ip`:

```
subnet: 255.255.255.0:192.168.1.10:192.168.1.10
```

Forward TCP 6900, 6121 and 5121 on the router to the Coolify host.

Two things to verify with your ISP:

- **CGNAT.** If `curl ifconfig.me` does not match the WAN address in your
  router admin page, you are behind CGNAT and port forwarding will not work.
  Workaround is a cheap VPS with WireGuard plus iptables DNAT.
- **Dynamic IP.** rAthena resolves the hostname once at startup, so a DDNS
  update will not be picked up without a restart.

## Creating an account

Enable auto-registration temporarily in `conf/import/login_conf.txt`:

```
new_account: yes
```

Log in with `yourname_M` (M or F sets gender) and the account is created.
Turn it back off afterwards.

For a GM account, insert directly:

```sql
INSERT INTO login (userid, user_pass, sex, email, group_id)
VALUES ('admin', 'yourpassword', 'M', 'a@b.com', 99);
```

Group 99 is full GM.

## Client

`PACKETVER` must match your client exactly. A mismatch shows up as the client
connecting and instantly disconnecting with nothing useful in the logs.

The server is open source but the client assets are Gravity's — get the client
from an official kRO/iRO source rather than a repacked "full client" bundle.

In the client's `data/clientinfo.xml`:

```xml
<address>YOUR.PUBLIC.IP</address>
<port>6900</port>
<version>55</version>
<langtype>1</langtype>
```

## Rates and game config

Override in `conf/import/battle_conf.txt` rather than editing files under
`conf/battle/`, so upstream changes do not conflict.

```
base_exp_rate: 500
job_exp_rate: 500
item_rate_common: 200
```

Values are percentages — 100 is 1x.

## Ports

| Port | Service |
|------|---------|
| 6900 | login   |
| 6121 | char    |
| 5121 | map     |

MariaDB is not published — it is reachable only on the internal Coolify network.
