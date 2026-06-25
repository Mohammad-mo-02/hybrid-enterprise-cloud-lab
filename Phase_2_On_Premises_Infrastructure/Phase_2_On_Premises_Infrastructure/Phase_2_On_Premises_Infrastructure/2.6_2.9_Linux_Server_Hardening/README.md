[Phase 2.6] Secure Linux Operations - SSH Hardening & UFW

- Generated ED25519 SSH key pair, deployed public key to authorized_keys
- Verified key-based authentication before disabling fallback
- Hardened sshd_config: PermitRootLogin no, PasswordAuthentication no
- Configured ufw firewall (default deny incoming, allow SSH)
- Diagnosed and resolved ufw/sshd port mismatch (real-world troubleshooting)

## Phase 2.6: Secure Linux Operations (SSH Hardening)

**Objective:** Eliminate clear-text credential exposure by enforcing 
SSH key-pair authentication, then lock down the attack surface via 
sshd_config hardening and ufw firewall rules.

### Implementation
1. Generated ED25519 key pair on management host (Windows)
2. Deployed public key to `~/.ssh/authorized_keys` on LNX-SRV-01
3. **Verified key login succeeded before removing password fallback** 
   — never cut off current access until the replacement is tested
4. Hardened `/etc/ssh/sshd_config`:
   - `PermitRootLogin no`
   - `PasswordAuthentication no`
5. Configured `ufw`: default deny incoming, explicit allow for SSH

### Incident: Port Mismatch (Real-World Troubleshooting)
During implementation, ufw was configured to allow port 2222 while 
sshd remained on port 22 — a partial port-migration that broke external 
SSH access while the service itself reported healthy.

**Diagnosis:**
- `ping` succeeded, `ssh` timed out → ruled out routing/host-down
- `systemctl status ssh` → service active, listening on port 22 → ruled out service failure
- `ufw status verbose` → only port 2222 allowed → **root cause confirmed**

**Resolution:** `ufw allow 22/tcp` to match sshd's actual listening port.

**Verification:**
- `systemctl status ssh` → active, port 22
- `ufw status verbose` → 22/tcp allowed
- `grep -E "PermitRootLogin|PasswordAuthentication|^Port" sshd_config` → confirmed hardened values
- SSH login → no password prompt, key auth confirmed working

### Outstanding
- Default port (22) not yet changed per Elite Standard — deferred, 
  current config is fully secure (key-only, root disabled) regardless
- Leftover unused `ufw` rule for 2222/tcp — cleanup pending
