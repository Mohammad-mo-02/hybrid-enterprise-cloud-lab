# Phase 2.6–2.9: Linux Server Hardening & Web Operations

**Server:** LNX-SRV-01 (Ubuntu Server 26.04 LTS)
**Network:** Host-only `VMnet1` (10.0.0.20/24) + NAT `VMnet8` (ens37, internet egress)

---

## Phase 2.6: Secure Linux Operations (SSH Hardening)

**Objective:** Eliminate clear-text credential exposure by enforcing SSH key-pair
authentication, then lock down the attack surface via `sshd_config` hardening
and `ufw` firewall rules.

### Implementation

1. Generated an ED25519 key pair on the management host (Windows):
   ```
   ssh-keygen -t ed25519 -C "lnx-srv-01-access"
   ```
2. Deployed the public key to `~/.ssh/authorized_keys` on LNX-SRV-01.
3. **Verified key-based login succeeded before removing the password fallback** —
   never cut off the current access method until the replacement is tested working.
4. Hardened `/etc/ssh/sshd_config`:
   - `PermitRootLogin no`
   - `PasswordAuthentication no`
5. Configured `ufw`: default deny incoming, explicit allow for SSH.

**Verification — SSH service active and listening:**

![SSH service active](2.6-ssh-service-active.png)

### Incident: ufw / sshd Port Mismatch (Real-World Troubleshooting)

During implementation, `ufw` was configured to allow port `2222` while `sshd`
remained listening on port `22` — a partial port-migration that broke external
SSH access while the service itself reported healthy.

**Evidence of the broken state — `ufw` only permitting 2222/tcp:**

![ufw mismatch incident](2.6-ufw-mismatch-incident.png)

**Diagnosis process:**
- `ping 10.0.0.20` succeeded → ruled out host-down / routing failure
- `ssh 10.0.0.20` timed out → isolated the fault to a specific service/port
- `systemctl status ssh` → service `active (running)`, listening on port 22
  → ruled out SSH service failure
- `ufw status verbose` → only port `2222` allowed → **root cause confirmed**

**Resolution:**
```
sudo ufw allow 22/tcp
```

**Recovery confirmed — first attempt times out (pre-fix), second attempt succeeds (post-fix):**

![Recovery login success](2.6-recovery-login-success.png)

**Final verified state — firewall rules and sshd_config hardening confirmed together:**

![Final verified config](2.6-final-verified-config.png)

```
sudo ufw status verbose
sudo grep -E "PermitRootLogin|PasswordAuthentication|^Port" /etc/ssh/sshd_config
```

### Outstanding
- Default port (22) not yet changed per Elite Standard — deferred. Current
  configuration is fully secure (key-only auth, root login disabled)
  independent of which port is in use.
- Leftover unused `ufw` rule for `2222/tcp` — cosmetic cleanup pending
  (`sudo ufw delete allow 2222/tcp`).

---

## Phase 2.7: Linux Web Administration (Nginx)

*Pending.*

## Phase 2.8: Cryptographic Certificate Lifecycle (OpenSSL)

*Pending.*

## Phase 2.9: Local Name Resolution (DNS)

*Pending.*
