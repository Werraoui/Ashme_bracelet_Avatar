Step-by-step plan (escalation + SMS) and what columns to add
You already have: PhysioVariable (reading), PredicResult (status), Alerte (links to contact).
To support step-based escalation + SMS delivery tracking, you need your DB to remember:

what stage was sent
whether it was sent/delivered/failed
when to escalate next
whether someone acknowledged
Below is a clean, incremental path.

Step 1 — Decide where “state” lives
You have 2 choices:

Option A (recommended): store state in alertes
Each Alerte row becomes “an alert attempt to one contact”. This is natural because you already link to id_contact.

Option B: create a new table like alert_campaigns
That’s cleaner long-term, but it’s more work.

For now, do Option A (add columns to alertes).

Step 2 — Add columns to alertes (Alerte)
Add these columns in Supabase (SQL editor) and then reflect them in SQLAlchemy later.

Core escalation columns (must-have)
stage (smallint / int):
1 = very_close
2 = close
3 = not_that_close
status (text or enum):
created, sending, sent, delivered, failed, acknowledged
sent_at (timestamp, nullable)
delivered_at (timestamp, nullable)
failed_at (timestamp, nullable)
error_message (text, nullable)
SMS provider tracking (must-have if sending SMS)
provider (text): twilio / vonage / etc.
provider_message_id (text, nullable): the ID returned by the SMS provider
Acknowledgement tracking (recommended)
acknowledged_at (timestamp, nullable)
acknowledged_by (text, nullable)
Example values: user, contact, system
Optional but very useful (for escalation timing)
escalation_group_id (uuid or text)
A single reading/prediction can create multiple alerts; group them so you can escalate cleanly.
Example: one escalation_group_id per id_predict
Minimal set if you want to keep it very small:

stage, status, sent_at, provider_message_id, error_message, escalation_group_id
Step 3 — Add (or reuse) the relation order
You already have Contact.relation with values:

very close
close
not that close
Define the stage mapping:

stage 1 → very_close
stage 2 → close
stage 3 → not_that_close
Step 4 — Update the “escalation service” logic (still synchronous for now)
Your service should do this:

When a new reading is warning/critical
Create PredicResult
Determine stage = 1
Fetch contacts with relation = very_close
Insert Alerte rows for those contacts with:
stage = 1
status = created
escalation_group_id = <same value for all alerts of this prediction>
Then send SMS for each created alert
For each Alerte:
call send_sms(contact.phone_contact, message)
update:
status = sent (or failed)
sent_at = now()
provider_message_id = ...
error_message if failed
Why store before sending? If SMS fails or the server crashes, you still have a DB record showing what should have happened.

Step 5 — Add a manual “escalate next stage” endpoint (for now)
Because you don’t want background jobs yet, you can test escalation step-by-step using Swagger.

Add an endpoint conceptually like:

POST /alerts/escalate/{id_predict}
What it does:

Find the latest stage already created for this id_predict (or by escalation_group_id)
If stage == 1 → create stage 2 alerts (close)
If stage == 2 → create stage 3 alerts (not_that_close)
If stage == 3 → stop
This keeps your system step-based without timers.

Step 6 — Add SMS sending (provider wrapper)
Create a small service notification_service.py with ONE job:

send_sms(to_phone: str, message: str) -> (provider_message_id: str)
What provider to choose
Twilio is simplest to start with (docs + Python SDK are straightforward)
What you store
Save the returned provider_message_id into the alert row so you can:

query delivery later
reconcile logs
debug failures
Step 7 — Delivery callbacks (later, but plan now)
Most SMS providers send webhook callbacks for delivery status.

Later you’ll add:

POST /webhooks/sms-status This endpoint updates:
status = delivered and delivered_at = now()
You don’t need this today, but your columns should support it.

Step 8 — How you test in Swagger (step-by-step)
POST /readings with warning/critical values
Expect:

physio_variables row
predic_results row
alertes rows for stage 1 contacts
status fields updated as SMS is attempted
POST /alerts/escalate/{id_predict}
Expect stage 2 rows created + SMS sent

Run it again for stage 3

Exactly what I need from you to finalize the column list
Answer these decisions (short answers):

Do you want escalation timing like “after 2 minutes escalate”, or only manual testing for now?
Who can acknowledge? user, contact, or both?
Which SMS provider do you want first (Twilio / Vonage / other)?
If you answer those 3, I’ll give you:

the final exact column list (minimal but complete)
the recommended SQL types (Supabase-friendly)
the exact escalation flow rules (when to move to next stage)



