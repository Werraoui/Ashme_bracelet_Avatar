# `alertes` — New Attributes (Simple Explanation)

These columns were added to the `alertes` table so you can support:

- **Step-by-step escalation** (very_close → close → not_that_close)
- **SMS sending + tracking** (sent / delivered / failed)
- **Acknowledgement tracking** (someone confirms the alert)

---

## Escalation columns

- **`escalation_group_id`** (UUID)
  - **What it is**: an identifier that groups alerts created for the same event (usually one prediction / one reading workflow).
  - **Why**: lets you find “all alerts belonging to the same escalation”.
  - **Example**: one prediction triggers 3 alerts (3 contacts) → all share the same `escalation_group_id`.

- **`stage`** (smallint)
  - **What it is**: the escalation step number.
  - **How to use**:
    - `1` = contacts with relation `very_close`
    - `2` = contacts with relation `close`
    - `3` = contacts with relation `not_that_close`
  - **Why**: you can escalate later by creating stage 2, then stage 3.

- **`status`** (text)
  - **What it is**: the current state of this alert record.
  - **Typical values**:
    - `created` (alert row exists; notification not attempted yet)
    - `sent` (notification was sent successfully)
    - `failed` (notification sending failed)
    - `acknowledged` (user confirmed / stopped escalation)
  - **Why**: you can track what happened without guessing.

---

## Provider tracking columns

- **`provider`** (text, nullable)
  - **What it is**: which notification channel/provider was used.
  - **Example values**: `email`, `twilio`, `dry-run`.

- **`provider_message_id`** (text, nullable)
  - **What it is**: a provider identifier (Twilio SID, etc.) or a placeholder for email.
  - **Why**: used to debug and track what was sent.

---

## Timing columns (timestamps)

- **`sent_at`** (timestamp, nullable)
  - **When it is set**: when you successfully send the SMS request.

- **`delivered_at`** (timestamp, nullable)
  - **When it is set**: when the provider tells you the SMS was delivered (usually via webhook later).

- **`failed_at`** (timestamp, nullable)
  - **When it is set**: when sending fails.

---

## Acknowledgement columns

- **`acknowledged_at`** (timestamp, nullable)
  - **When it is set**: when the alert is acknowledged (user or contact confirms).

- **`acknowledged_by`** (text, nullable)
  - **What it stores**: who acknowledged the alert.
  - **Example values**: `user`, `contact`, `system`.

---

## Error column

- **`error_message`** (text, nullable)
  - **When it is set**: if sending fails, store the error reason here.
  - **Why**: helps you debug provider/API issues without checking server logs only.

---

## Quick example (how a single alert row evolves)

1. Create alert row:
   - `stage = 1`, `status = "created"`
2. Send notification:
   - `provider = "email"` (or `twilio`), `provider_message_id = "..."`
   - `status = "sent"`, `sent_at = now()`
3. If someone confirms:
   - `status = "acknowledged"`, `acknowledged_at = now()`, `acknowledged_by = "contact"`

