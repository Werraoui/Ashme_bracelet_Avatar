# SMS_system.md — SMS Notifications (Step-by-step)

This document explains how to integrate an SMS notification system into your current backend **without breaking existing routes**, using your **service layer** and the new `alertes` tracking columns.

The goal is:

`POST /readings` → reading saved → prediction saved → alerts created → **SMS sent to the escalated contacts** → alert rows updated (`status`, `sent_at`, `provider_message_id`, etc.)

---

## 1) What you already have (current state)

- **Contacts** table includes phone numbers (`contacts.phone_contact`)
- **Alerts** table (`alertes`) links a prediction to a contact (`id_predict`, `id_contact`)
- **New alertes columns** exist to track sending:
  - `status`, `provider`, `provider_message_id`
  - `sent_at`, `delivered_at`, `failed_at`
  - `error_message`
  - `stage`, `escalation_group_id`

Right now, your code creates `alertes` rows but does **not** send SMS yet.

---

## 2) Recommended provider (simple choice)

Use **Twilio** first (most common + good Python SDK).  
If you prefer another provider (Vonage, MessageBird), the architecture stays the same: only the provider wrapper changes.

---

## 3) Step 1 — Create a notification service (provider wrapper)

### Where

Create:

`app/services/notification_service.py`

### Why

You want one small module whose only job is:
- take `phone_number` + `message`
- call the provider
- return `provider_message_id`

So later, switching providers won’t require touching your reading pipeline logic.

### What functions to add (minimal)

- `send_sms(to_phone: str, message: str) -> str`

Keep this file independent from FastAPI routes.

---

## 4) Step 2 — Add environment variables

In your `.env` (or Supabase secrets), add:

- `SMS_PROVIDER=twilio`
- `TWILIO_ACCOUNT_SID=...`
- `TWILIO_AUTH_TOKEN=...`
- `TWILIO_FROM_PHONE=...`

### Why

Never hardcode credentials. Your service reads them from environment variables.

---

## 5) Step 3 — Decide the SMS message format (very important)

Keep the first version short and clear:

- Identify the patient (optional for privacy; you can use first name or “Patient #id_user”)
- Include status: WARNING / CRITICAL
- Include last reading values (HR, RR, SpO2)
- Include action request (“Please check on the patient”)

Example template (concept):

> Asthma Alert (CRITICAL) for user 2. SpO2=91, RR=32, HR=128. Please check immediately.

### Why this matters

It makes testing easier and later you can add localization / personalization.

---

## 6) Step 4 — Update the reading pipeline to send SMS after creating alerts

### Where to integrate

In your service layer (current file):

`app/services/reading_service.py`

After you create stage-1 alert rows (very_close), you should:

1. Fetch the contact phone numbers (already available through the `Contact` rows)
2. For each created alert:
   - call `send_sms(contact.phone_contact, message)`
   - update the alert row:
     - `provider = "twilio"`
     - `provider_message_id = <id>`
     - `status = "sent"`
     - `sent_at = now()`
3. If sending fails:
   - set `status = "failed"`
   - set `failed_at = now()`
   - set `error_message`

### Why store alert rows first

Because the DB becomes your source of truth:
- If sending fails, you still have the alert record
- You can retry later
- You can audit who should have been notified

---

## 7) Step 5 — Delivery status (later, but you should plan it now)

Sending SMS ≠ delivered SMS.

Most providers (Twilio) can send you delivery updates via webhook.

### What you’ll add later

- A new route file (recommended):
  - `app/routes/webhooks.py`
- Endpoint example:
  - `POST /webhooks/sms-status`

### What it updates in DB

When provider confirms delivery:
- `status = "delivered"`
- `delivered_at = now()`

When provider confirms failure:
- `status = "failed"`
- `failed_at = now()`
- `error_message = ...`

### Why you want this

Delivery tracking is required for a real escalation engine:
- “If not delivered in X minutes, escalate to stage 2”

---

## 8) Step 6 — Escalation + SMS together (how it should work)

### Stage mapping (your current design)

- Stage 1 → `very_close`
- Stage 2 → `close`
- Stage 3 → `not_that_close`

### Practical rule (simple)

1. On warning/critical reading:
   - create stage-1 alerts
   - send SMS to stage-1 contacts
2. Escalate later (manual endpoint for now):
   - create stage-2 alerts
   - send SMS to stage-2 contacts

### Why stage-based

You avoid notifying everyone immediately and you create a clear escalation path.

---

## 9) How to test SMS safely (recommended workflow)

### Option A (recommended): provider “test mode”

Twilio provides test credentials and test numbers.
Use them so you don’t send real messages while developing.

### Option B: “dry run” mode (development)

Add an env flag:
- `SMS_DRY_RUN=true`

If `true`, your `send_sms()` function does not call Twilio and returns a fake ID like:
- `mock-<uuid>`

Your DB still updates:
- `status = "sent"`
- `provider_message_id = "mock-..."`

This is the easiest way to validate the whole flow in Swagger without cost.

---

## 10) Swagger test plan (end-to-end)

1. Create a user and at least one **very_close** contact with a valid phone number.
2. Call `POST /readings` with values that trigger **warning** or **critical**.
3. Verify in Supabase:
   - `predic_results` has a new row
   - `alertes` has new rows with:
     - `stage = 1`
     - `status = sent` (or failed)
     - `provider_message_id` filled (or error_message filled)

---

## 11) Common mistakes to avoid

- Putting Twilio SDK calls inside route functions (keep it in services)
- Not updating DB status after sending (then you can’t debug)
- Not handling provider exceptions (always catch, store `error_message`, rollback/commit properly)
- Sending to invalid phone format (normalize or validate contact phone numbers)
- Hardcoding secrets in code (use `.env`)

---

## 12) Next improvements (after SMS works)

- Add retry logic for failed SMS (with a max retry count column)
- Add acknowledgement flow:
  - contact replies “OK”
  - webhook marks alert as acknowledged
- Add automatic escalation:
  - cron/job/queue checks unacknowledged alerts after X minutes

