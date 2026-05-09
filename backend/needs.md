Real auth: replace mock tokens with JWT + password hashing, protect routes (user can only access their own data).
Proper escalation: stage 1 → stage 2 → stage 3 with timing/ack rules (not only “very_close”), plus a way to acknowledge/stop escalation.
SMS delivery webhooks: endpoint to receive Twilio status callbacks and update alertes (delivered_at, failed_at, etc.).
Background processing: move SMS sending + escalation checks to a worker/cron/queue (so POST /readings stays fast and reliable).
Data validations: normalize/validate phone numbers (E.164), avoid duplicates, handle missing readings safely.
Observability: structured logging + error handling so failures are visible, and alert rows always reflect what happened.
Migrations discipline: Alembic migrations for any future DB changes (columns, tables) instead of manual edits.
ML-ready integration point: keep the classifier behind a clean interface so you can swap it for a model later without touching routes.