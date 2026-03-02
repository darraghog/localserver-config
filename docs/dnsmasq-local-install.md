# Install dnsmasq Locally on darragh-pc

Native dnsmasq (not container) so it listens on 192.168.86.237:53 and is reachable from LAN. Use this when darragh-pc runs WSL on Windows—containers can't expose UDP 53 via Windows port forwarding.

---

## 1. Stop and remove the Podman dnsmasq container

If it was running:

```bash
cd ~/localserver-config/compose/local-dns
podman compose down
```

---

## 2. Disable systemd-resolved stub (free port 53)

systemd-resolved uses 127.0.0.53:53. We'll configure dnsmasq to listen on 192.168.86.237 only to avoid conflict.

```bash
# Ensure resolv.conf isn't overwritten by resolved (optional, if you use Tailscale)
# We'll configure dnsmasq to not conflict
```

Actually: systemd-resolved binds 127.0.0.53. Binding dnsmasq to 192.168.86.237 only should work without disabling resolved.

---

## 3. Install dnsmasq

```bash
sudo apt-get update
sudo apt-get install -y dnsmasq
```

---

## 4. Create config

```bash
sudo tee /etc/dnsmasq.d/thelearningcto.com.conf << 'EOF'
# Local DNS for thelearningcto.com - split horizon with Route53
# Listen on LAN IP only (avoid conflict with systemd-resolved 127.0.0.53)
listen-address=192.168.86.237
bind-interfaces
port=53

# Local overrides
address=/darragh-pc.thelearningcto.com/192.168.86.237
address=/n8n.thelearningcto.com/192.168.86.237
address=/thelearningcto.com/192.168.86.237
address=/www.thelearningcto.com/192.168.86.237
address=/darragh-pc/192.168.86.237

# Upstream
server=1.1.1.1
server=8.8.8.8
no-resolv
no-poll
EOF
```

Adjust `192.168.86.237` if your LAN IP differs.

---

## 5. Disable default config (optional)

The default `/etc/dnsmasq.conf` may include `conf-dir` which loads extra files. Ensure no conflicting config:

```bash
# Check for conflicts
ls /etc/dnsmasq.d/
```

Remove any that might conflict, or add `conf-file=/etc/dnsmasq.d/thelearningcto.com.conf` and nothing else.

---

## 6. Update resolv.conf (use dnsmasq as default resolver)

**Stop dnsmasq first** so nothing overwrites resolv.conf while you edit it:

```bash
sudo systemctl stop dnsmasq
```

Then configure WSL and resolv.conf:

```bash
# Prevent WSL from overwriting resolv.conf
sudo bash -c 'echo -e "[network]\ngenerateResolvConf = false" >> /etc/wsl.conf'

# Set dnsmasq as primary resolver (will start in step 7)
sudo tee /etc/resolv.conf << 'EOF'
nameserver 192.168.86.237
nameserver 1.1.1.1
EOF
```

Restart WSL for wsl.conf to take effect (from PowerShell: `wsl --shutdown`, then reopen WSL).

---

## 7. Start and enable dnsmasq

```bash
sudo systemctl start dnsmasq
sudo systemctl enable dnsmasq
```

---

## 8. Verify

```bash
# From darragh-pc
dig @192.168.86.237 darragh-pc.thelearningcto.com +short
# Expected: 192.168.86.237

# From another LAN device (after setting DNS to 192.168.86.237)
dig @192.168.86.237 darragh-pc.thelearningcto.com +short
```

---

## 9. Configure your network

Point LAN devices to use 192.168.86.237 as DNS:

- **Google Home / Nest Wifi:** Advanced networking → DNS → Custom → `192.168.86.237`
- **FIOS router:** DHCP settings → DNS server → `192.168.86.237`
- **Per-device:** Set DNS to `192.168.86.237` in network settings

---

## WSL on Windows note

If darragh-pc is WSL on Windows, the host's LAN IP 192.168.86.237 may be on the Windows side. With **mirrored networking** (WSL 2.0+), WSL shares the host IP—dnsmasq binding to 192.168.86.237 should be reachable from the LAN. Without mirrored mode, you'd need the desktop to be native Linux for this to work from other devices. For same-machine (WSL) resolution, use `scripts/setup-wsl-hosts.sh` instead.
