```md
# guide_service_layer.md — Service Layer Workflow Guide

This guide shows how to move the “reading workflow logic” out of routes and into a **service layer**, so your system can do:

**reading → classification → prediction → alerts**

It is written to be followed manually in your existing FastAPI + SQLAlchemy + Pydantic project.

---

## 1) What you are building (the “guided logic”)

When the API receives a new physiologic reading (HR/SPO2/RR), the backend should:

- **Save the reading** into `physio_variables` (`PhysioVariable`)
- **Classify risk**: `normal | warning | critical` (`StatusPredictEnum`)
- **Save the prediction** into `predic_results` (`PredicResult`)
- **Create alerts** into `alertes` (`Alerte`) for the user’s emergency contacts when needed

This is a workflow that spans multiple tables, so it belongs in a **service**, not a route.

---

## 2) Why the service layer matters

If you keep this logic inside `POST /readings`, the route becomes:
- long
- hard to test
- tightly coupled to HTTP
- hard to extend later (ML, notifications, retries)

With a service layer:
- routes stay “thin” (HTTP in/out)
- services hold “smart behavior” (workflow + rules)
- adding ML later becomes “swap classifier function”, not “rewrite endpoint”

---

## 3) Where to put it (file structure)

Inside:

- `app/services/`

Recommended files (you can start with just one):

- `app/services/readings_service.py`  
  Contains the main workflow: save reading → classify → save prediction → create alerts

Optional (later, for cleanliness):
- `app/services/classification_service.py`
- `app/services/alerts_service.py`

---

## 4) What the service should NOT do

Keep services “application logic”, not infrastructure:

- **DON’T** create/close DB sessions inside services  
  - Routes should pass `db: Session` into the service.
- **DON’T** import FastAPI request/response objects in services
- **DON’T** return raw dicts everywhere  
  - Prefer returning SQLAlchemy objects or a small dataclass-like structure.

---

## 5) Design the workflow function (the core)

### 5.1 Service function signature (recommended)

Goal: one entry point for the reading workflow.

Small snippet:

```python
def process_new_reading(db: Session, payload: ReadingCreate):
    ...
    return reading, prediction, alerts
```

**Why**:
- `db` makes the service testable and consistent.
- `payload` ensures input was validated by Pydantic.
- returning `(reading, prediction, alerts)` gives you flexibility.

### 5.2 “Single transaction” mindset

You want these operations to behave like one unit:
- if saving prediction fails, the reading should not remain orphaned
- if alerts creation fails, you decide whether to rollback or continue

For your first version, keep it simple:
- do all inserts
- commit once at the end
- rollback if anything fails

---

## 6) Risk classification logic (rule-based v1)

### 6.1 Use your existing enum

You already have:
- `StatusPredictEnum = normal | warning | critical`

### 6.2 Define beginner-friendly thresholds

Start with adjustable rules (example only — tune later):

- **critical** if any:
  - `spo2 < 90`
  - `hr > 140`
  - `rr > 30`

- **warning** if any:
  - `90 <= spo2 < 94`
  - `110 < hr <= 140`
  - `20 < rr <= 30`

- else **normal**

Small snippet (core idea only):

```python
def classify_risk(spo2, hr, rr) -> StatusPredictEnum:
    if spo2 is not None and spo2 < 90:
        return StatusPredictEnum.critical
    if hr is not None and hr > 140:
        return StatusPredictEnum.critical
    if rr is not None and rr > 30:
        return StatusPredictEnum.critical

    if spo2 is not None and 90 <= spo2 < 94:
        return StatusPredictEnum.warning
    if hr is not None and 110 < hr <= 140:
        return StatusPredictEnum.warning
    if rr is not None and 20 < rr <= 30:
        return StatusPredictEnum.warning

    return StatusPredictEnum.normal
```

**Why this matters**:
- deterministic (easy to debug)
- matches your DB enum for `status_predict`
- easy to replace with ML later

---

## 7) Saving the reading (PhysioVariable)

### 7.1 What you save

From `ReadingCreate` you typically save:
- `id_user`
- `spo2_value`, `rr_value`, `hr_value`
- timestamp is DB-generated (`time_of_record`)

### 7.2 Important detail

After inserting the reading, you need its generated ID:
- `id_physio`

So you will typically:
- add reading
- flush (or commit + refresh)
- then create prediction using `reading.id_physio`

**Why**:
- `PredicResult.id_physio` needs the reading FK.

---

## 8) Saving the prediction (PredicResult)

Prediction record should store:

- `id_user`
- `id_physio`
- `status_predict` (enum)
- time is DB-generated (`time_of_creation`)

**Why this table matters**:
- it creates a history of risk states
- it links risk classification to the exact reading that caused it

---

## 9) Creating alerts (Alerte)

### 9.1 When to trigger alerts

Beginner-friendly v1 logic:

- if `status_predict == normal`: create **no alerts**
- else (`warning` or `critical`): create alerts for **all contacts** of that user

You can refine later:
- warning: notify only “very close” contacts
- critical: notify all

### 9.2 What an alert row needs

`Alerte` links:
- `id_user`
- `id_predict` (the prediction row you just created)
- `id_contact` (each emergency contact)
- timestamp is DB-generated (`time_of_alert`)

### 9.3 Contact lookup

You’ll query:
- `contacts` table by `id_user`

If user has 0 contacts:
- create 0 alerts (don’t error)

---

## 10) How to connect the service to the route (without rewriting everything)

### 10.1 Keep your route thin

Your route should do:
- receive `payload: ReadingCreate`
- call service `process_new_reading(db, payload)`
- return the response model

Conceptual snippet:

```python
reading, prediction, alerts = process_new_reading(db, payload)
return reading
```

### 10.2 Why not return everything immediately?

For v1, returning the reading is enough.

Later you can create a response schema like:
- `ReadingWithPredictionOut`
that includes reading + status + count of alerts.

---

## 11) Recommended testing workflow (Swagger)

### 11.1 Normal case

Send `POST /readings` with safe values.

Expect in DB:
- 1 new row in `physio_variables`
- 1 new row in `predic_results` with `status_predict = normal`
- 0 new rows in `alertes`

### 11.2 Critical case

Send `POST /readings` with critical values (e.g., spo2 = 88).

Expect:
- reading saved
- prediction saved with `critical`
- alerts created for each contact

### 11.3 What to check

In Supabase Table Editor:
- `physio_variables` new row
- `predic_results` row referencing `id_physio`
- `alertes` rows referencing `id_predict` + `id_contact`

---

## 12) Common mistakes (and how to avoid them)

- **Putting classification logic in the route**
  - Move it to the service function so all endpoints reuse it.

- **Committing too early**
  - If you commit reading, then crash on prediction, you leave inconsistent data.
  - Prefer “one workflow → one commit”.

- **Forgetting rollback**
  - If an exception occurs after `db.add(...)`, call `db.rollback()`.

- **Creating alerts before prediction exists**
  - `Alerte.id_predict` needs prediction’s ID.

- **Not handling `None` values**
  - Readings can be partially missing; classification must handle `None`.

---

## 13) Next steps after service layer is stable

- Replace `classify_risk()` with ML model inference (same interface)
- Add notification delivery (SMS/WhatsApp/email) and delivery status tracking
- Add auth protections so users can only access their own records
- Add real-time updates (WebSocket/Supabase Realtime)
- Add “trend-based risk” (not only threshold-based)

---
```