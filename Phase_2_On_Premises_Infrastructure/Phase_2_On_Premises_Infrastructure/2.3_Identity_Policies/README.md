# 2.3: Identity Policies & Help Desk Operations

## What This Contains
- FGPP (Fine-Grained Password Policies) scripts
- Group Policy Objects (GPO) scripts
- Help desk runbook with 10 scenarios

# Phase 2.3A: Fine-Grained Password Policies (FGPP)

## Overview
Three tiered Password Settings Objects (PSOs) enforce role-appropriate password
and lockout rules, applied to tier-based security groups (not OUs — AD does not
permit PSOs to target OUs; they apply to users or global security groups only).

## Policy Matrix

| Setting | PSO-Tier0-Admins | PSO-Tier1-Admins | PSO-Tier2-Users |
|---|---|---|---|
| Precedence | 10 | 20 | 30 |
| Applied to group | SG-Tier0-Admins | SG-Tier1-Admins | SG-Tier2-Users |
| Min password length | 16 | 14 | 12 |
| Complexity | Enabled | Enabled | Enabled |
| Password history | 12 | 8 | 5 |
| Max password age | 30 days | 45 days | 60 days |
| Min password age | 1 day | 1 day | 1 day |
| Lockout threshold | 3 | 5 | 5 |
| Lockout duration | 60 min | 30 min | 30 min |
| Lockout observation window | 60 min | 30 min | 30 min |

## Precedence Rules
A PSO carries a precedence value. If a user is subject to more than one PSO
(e.g. via membership in two targeted groups), AD does **not** merge the policies
or auto-select the strictest. It applies the single PSO with the **lowest
precedence number** and ignores the rest. Tier 0 is therefore set to 10 so the
most privileged accounts always receive the strictest policy. The spec intent
("most restrictive wins") is realised through deliberate precedence ordering.

## Verification
Per-user resultant policy confirmed with:
`Get-ADUserResultantPasswordPolicy -Identity <user>`
ForestAdmin-1 resolves to PSO-Tier0-Admins (Precedence 10, MinLength 16,
Lockout 3, Duration 1hr), confirming correct end-to-end application.

## Idempotency
The creation script is safe to re-run: existing PSOs are updated via
Set-ADFineGrainedPasswordPolicy rather than recreated, and group bindings are
checked before being added.
