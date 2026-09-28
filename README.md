
<div align="center">

# 🫁 AVATAR — Asthma Monitoring System

### AI-Powered Real-Time Respiratory Health Monitoring

[![FastAPI](https://img.shields.io/badge/FastAPI-0.136+-009688?style=flat-square&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=flat-square&logo=flutter&logoColor=white)](https://flutter.dev)
[![Python](https://img.shields.io/badge/Python-3.10+-3776AB?style=flat-square&logo=python&logoColor=white)](https://python.org)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-Supabase-4169E1?style=flat-square&logo=postgresql&logoColor=white)](https://supabase.com)
[![Docker](https://img.shields.io/badge/Docker-Render-2496ED?style=flat-square&logo=docker&logoColor=white)](https://render.com)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)

**AVATAR** is an IoT-connected health monitoring platform for asthma patients. A wearable bracelet streams physiological data (SpO₂, heart rate, respiratory rate) to a FastAPI backend, which classifies risk in real-time using a **Fuzzy C-Means (FCM) AI model**, stores results in PostgreSQL, and triggers a 3-stage escalating alert system via email and SMS.

[Features](#-features) · [Architecture](#-architecture) · [AI Model](#-ai-model--fuzzy-c-means) · [Quick Start](#-quick-start) · [API Reference](#-api-reference) · [Deployment](#-deployment)

</div>

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Features](#-features)
- [Architecture](#-architecture)
- [Tech Stack](#-tech-stack)
- [Project Structure](#-project-structure)
- [AI Model — Fuzzy C-Means](#-ai-model--fuzzy-c-means)
- [Alert Escalation System](#-alert-escalation-system)
- [Quick Start](#-quick-start)
- [Environment Variables](#-environment-variables)
- [API Reference](#-api-reference)
- [Database Schema](#-database-schema)
- [Deployment](#-deployment)
- [Running Tests](#-running-tests)

---

## 🌟 Overview

AVATAR addresses a critical gap in asthma management: **nocturnal asthma attacks often go undetected** because patients are asleep and cannot self-monitor. The platform provides:

- **Continuous monitoring** of SpO₂, heart rate, and respiratory rate via a wearable bracelet
- **AI-based risk classification** (NORMAL / WARNING / CRITICAL) using a trained Fuzzy C-Means model combined with clinical rule thresholds
- **Automated escalating alerts** that notify emergency contacts by email (or SMS via Twilio) with increasing urgency over time
- **Acknowledgement system** — contacts can stop the escalation cascade by clicking a secure link in the alert email

---

## ✨ Features

### Patient & Medical

- **Real-time vital sign display** — SpO₂, heart rate, respiratory rate with color-coded risk indicators
- **AI risk classification** — FCM model + clinical rules produce NORMAL / WARNING / CRITICAL status per reading
- **3-stage escalating alerts** — Stage 1: very close contacts → Stage 2: close contacts → Stage 3: all contacts (every 30 s if unacknowledged)
- **Alert history** — full log of past alerts with status, provider, and acknowledgement details
- **Emergency contact management** — add contacts with relationship levels (`very close`, `close`, `not that close`)
- **One-click alert acknowledgement** — email contains a secure token link; clicking it stops the escalation cascade

### Technical

- **Fuzzy C-Means AI model** trained on physiological data (HR, RR, SpO₂) with automatic cluster-to-label mapping
- **Clinical rules override** — SpO₂ < 92% or HR > 120 BPM or RR > 30 is always CRITICAL, regardless of ML output
- **Background escalation worker** — async loop polls every 5 seconds, escalates after 30-second stage timeout
- **Dual notification channel** — Email (SMTP) as primary, SMS (Twilio) as fallback
- **JWT authentication** with session persistence via `shared_preferences` on mobile
- **Dockerized backend** deployed on Render via `render.yaml`

---

## 🏗️ Architecture

```
┌────────────────────────────────────────────────────────────────┐
│               FLUTTER MOBILE APP (iOS / Android)               │
│                                                                │
│  Dashboard ── Alerts ── Contacts ── Profile                    │
│       │                                                        │
│  BraceletService (simulated vitals every 30s)                  │
│  ApiService (HTTP + JWT)                                       │
└──────────────────────────┬─────────────────────────────────────┘
                           │ POST /readings  (SpO₂, HR, RR)
┌──────────────────────────▼─────────────────────────────────────┐
│                   FASTAPI BACKEND (Docker / Render)            │
│                                                                │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                 Reading Processing Pipeline              │  │
│  │                                                         │  │
│  │  POST /readings ──► Store physio_variables              │  │
│  │                          │                              │  │
│  │                          ▼                              │  │
│  │             FCM Model + Clinical Rules                  │  │
│  │                 (NORMAL / WARNING / CRITICAL)           │  │
│  │                          │                              │  │
│  │                          ▼                              │  │
│  │                Store predic_results                     │  │
│  │                          │                              │  │
│  │              WARNING or CRITICAL? ──► Stage 1 Alerts   │  │
│  └─────────────────────────────────────────────────────────┘  │
│                                                                │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │            Escalation Worker (background loop)          │  │
│  │   Every 5s: check unacknowledged CRITICAL predictions   │  │
│  │   If stage pending > 30s → escalate to next stage       │  │
│  └─────────────────────────────────────────────────────────┘  │
│                                                                │
│  Routers: auth · users · contacts · readings                   │
│           predictions · alerts · prediction_routes             │
└──────────┬─────────────────────────────────────┬──────────────┘
           │                                     │
┌──────────▼──────────┐            ┌─────────────▼──────────────┐
│  PostgreSQL          │            │  Email (SMTP) / SMS (Twilio)│
│  (Supabase)          │            │  Alert notifications        │
│  5 tables            │            │  + Ack link (token-based)   │
└─────────────────────┘            └────────────────────────────┘
```

### Alert Escalation Flow

```
CRITICAL reading detected
        │
        ▼
  Stage 1 ──── "Very close" contacts notified (email/SMS)
        │                  │
        │         No acknowledgement in 30s
        │                  │
        ▼                  ▼
  Stage 2 ──── "Close" contacts notified
        │                  │
        │         No acknowledgement in 30s
        │                  │
        ▼                  ▼
  Stage 3 ──── "Not that close" contacts notified
                           │
                  Contact clicks ack link ──► All alerts in group marked "acknowledged"
                                              Escalation stops
```

---

## 🛠️ Tech Stack

### Backend

| Category | Technology |
|----------|------------|
| Framework | FastAPI 0.136+ + uvicorn |
| ORM | SQLAlchemy 2.0 |
| Database | PostgreSQL (Supabase) via psycopg2 + psycopg3 |
| Auth | python-jose (JWT HS256) + passlib (bcrypt) |
| Validation | Pydantic v2 |
| AI / ML | scikit-learn · NumPy · SciPy · scikit-fuzzy (FCM) |
| Model Serialization | joblib |
| Email | fastapi-mail (SMTP) |
| SMS | Twilio |
| Packaging | uv + pyproject.toml |
| Containerization | Docker (python:3.12-slim) |

### Frontend

| Category | Technology |
|----------|------------|
| Framework | Flutter (Dart SDK ≥ 3.0) |
| HTTP Client | http ^1.2.0 |
| Local Storage | shared_preferences (JWT + session) |
| Notifications | flutter_local_notifications ^17 |
| Logging | logger ^2.3.0 |
| Timezone | timezone ^0.9.4 |

### Infrastructure

| Service | Purpose |
|---------|---------|
| Render | Backend hosting (Docker, free plan) |
| Supabase | Managed PostgreSQL |
| SMTP (Gmail / custom) | Email alert notifications |
| Twilio (optional) | SMS fallback notifications |

---

## 📁 Project Structure

```
Ashme_bracelet_Avatar/
│
├── AI_model/                        # Standalone model training module
│   ├── train_fcm.py                 # FCM training script (CLI)
│   ├── model_utils.py               # Inference utilities
│   ├── main.py                      # Standalone FastAPI for model testing
│   ├── data_avatar.csv              # Training dataset (HR, RR, SpO₂)
│   ├── fcm_model.joblib             # Trained model artifact
│   ├── requirements.txt             # ML-only dependencies
│   └── README.md                    # Model documentation
│
├── backend/
│   ├── app/
│   │   ├── db/
│   │   │   ├── database.py          # SQLAlchemy engine & session
│   │   │   └── models.py            # ORM models (5 tables + enums)
│   │   ├── routes/
│   │   │   ├── auth.py              # POST /auth/register · /login
│   │   │   ├── users.py             # GET/PATCH /users/{id}
│   │   │   ├── contacts.py          # CRUD /contacts
│   │   │   ├── readings.py          # POST /readings (full pipeline)
│   │   │   ├── predictions.py       # GET /predictions/{user_id}
│   │   │   ├── prediction_routes.py # POST /predict (standalone ML)
│   │   │   ├── alerts.py            # GET/POST /alerts · ack · escalate
│   │   │   └── physio.py            # (placeholder)
│   │   ├── schemas/
│   │   │   ├── user.py
│   │   │   ├── contact.py
│   │   │   ├── readings.py
│   │   │   ├── prediction.py
│   │   │   └── alert.py
│   │   ├── services/
│   │   │   ├── auth_service.py      # JWT creation & verification
│   │   │   ├── auth_dependencies.py # FastAPI dependency: get_current_user
│   │   │   ├── reading_service.py   # Full reading pipeline (store → classify → alert)
│   │   │   ├── prediction_service.py# FCM inference + clinical rules
│   │   │   ├── alert_service.py     # Stage escalation + acknowledgement
│   │   │   ├── notification_service.py # Email/SMS dispatch routing
│   │   │   ├── email_service.py     # SMTP sender (fastapi-mail)
│   │   │   └── escalation_worker.py # Async background escalation loop
│   │   └── main.py                  # App factory + lifespan + routers
│   ├── AI_model/
│   │   ├── fcm_model.joblib         # Deployed model artifact
│   │   └── model_utils.py
│   ├── Dockerfile                   # python:3.12-slim + uv
│   ├── pyproject.toml               # Dependencies (uv)
│   ├── render.yaml                  # Render deployment config
│   ├── .env.example                 # Environment variable template
│   ├── test_db.py                   # DB connectivity test
│   └── test_e2e_api.py              # End-to-end API tests
│
├── frontend/
│   └── lib/
│       ├── main.dart                # App entry point + session check
│       ├── config/
│       │   └── api_config.dart      # API base URL
│       ├── models/
│       │   ├── physio_data.dart     # PhysioData model
│       │   ├── predict_model.dart   # PredictResult model
│       │   ├── alerte_model.dart    # Alerte model
│       │   └── user_model.dart      # User model
│       ├── pages/
│       │   ├── login_page.dart      # Login UI
│       │   └── register_page.dart   # Registration UI
│       ├── screens/
│       │   ├── dashboard/
│       │   │   └── dashboard.dart   # Main monitoring screen (animated)
│       │   ├── alertes/
│       │   │   └── alertes_screen.dart
│       │   ├── contacts/
│       │   │   └── contacts_screen.dart
│       │   ├── profil/
│       │   │   └── profil_screen.dart
│       │   ├── auth/
│       │   │   ├── au_gate.dart     # Auth gate
│       │   │   └── signup.dart
│       │   └── notifs/
│       │       └── notification_service.dart # Local push notifications
│       ├── services/
│       │   ├── api_service.dart     # HTTP client + JWT storage
│       │   ├── bracelet_service.dart# Simulated bracelet vitals + AI sync
│       │   ├── supabase_service.dart# Direct Supabase queries
│       │   └── auth_service.dart    # Auth helpers
│       └── utils/
│           └── risk_status.dart     # Risk status resolution helper
│
├── diagrams/
│   ├── class_diagram.mmd            # Mermaid class diagram
│   └── use_case_diagram.mmd         # Mermaid use case diagram
│
└── render.yaml                      # Root Render deployment config
```

---

## 🤖 AI Model — Fuzzy C-Means

### What is FCM?

**Fuzzy C-Means (FCM)** is an unsupervised clustering algorithm that assigns each data point a *degree of membership* to each cluster, rather than a hard label. This is ideal for medical data where risk levels are rarely black-and-white.

### Training

The model is trained on physiological data with three input features:

| Feature | Description | Normal Range |
|---------|-------------|-------------|
| `heart_rate` | BPM | 60–100 |
| `respiratory_rate` | breaths/min | 12–20 |
| `spo2` | Oxygen saturation % | 95–100 |

Training produces **3 clusters** automatically mapped to risk levels:

```
Severity score = HR + RR − SpO₂
  → Lowest severity  → NORMAL
  → Middle severity  → WARNING
  → Highest severity → CRITICAL
```

**Train the model:**

```bash
cd AI_model
python train_fcm.py --csv data_avatar.csv --out fcm_model.joblib
```

The script auto-detects column names (supports synonyms like `hr`, `pulse`, `frequence cardiaque`), cleans NaN rows, normalizes with `StandardScaler`, and saves the full artifact (scaler + cluster centers + label map) via `joblib`.

### Inference Pipeline

For each new bracelet reading:

```
Input: (HR, RR, SpO₂)
    │
    ▼
StandardScaler.transform()
    │
    ▼
Compute distances to 3 cluster centers (euclidean)
    │
    ▼
Fuzzy memberships = 1/distance (normalized)
    │
    ▼
Assign label of highest-membership cluster
    │
    ▼
Clinical rules override (if applicable):
  SpO₂ < 92  OR  HR > 120  OR  RR > 30  →  always CRITICAL
  SpO₂ < 95  OR  RR > 22               →  at least WARNING
    │
    ▼
Final status: NORMAL / WARNING / CRITICAL
```

**The FCM and clinical rules use `max_severity`** — the more severe of the two outputs always wins.

### Example Response

```json
{
  "risk_score": 0.75,
  "risk_label": "WARNING",
  "status_predict": "warning",
  "memberships": {
    "NORMAL": 0.10,
    "WARNING": 0.75,
    "CRITIQUE": 0.15
  }
}
```

---

## 🚨 Alert Escalation System

### How It Works

When a reading is classified as **WARNING** or **CRITICAL**, the system immediately creates Stage 1 alerts and notifies the patient's *very close* contacts. For **CRITICAL** readings, if no one acknowledges within **30 seconds**, the background worker escalates automatically:

| Stage | Contacts Notified | Relation Level |
|-------|------------------|----------------|
| 1 | Very close contacts | `very_close` |
| 2 | Close contacts | `close` |
| 3 | All remaining contacts | `not_that_close` |

### Notification Channels

1. **Email (primary)** — SMTP via `fastapi-mail`. Every alert email includes a secure one-click acknowledgement link.
2. **SMS (fallback)** — Twilio, used only if the contact has no email address and Twilio is configured.
3. **`NOTIF_DRY_RUN=true`** — disables all real sends (useful for development).

### Acknowledgement

Any contact (or the patient) can stop the escalation by:
- Clicking the link in the alert email: `GET /alerts/ack-link/{token}` (public, no auth required)
- Using the app: `POST /alerts/{id}/ack` (authenticated)

Acknowledging one alert marks **all alerts in the same escalation group** as `acknowledged` and stops further escalation for that prediction.

### Alert Statuses

| Status | Meaning |
|--------|---------|
| `created` | Alert record created, not yet sent |
| `sent` | Notification successfully dispatched |
| `failed` | Notification failed (see `error_message`) |
| `acknowledged` | Contact acknowledged; escalation stopped |

---

## 🚀 Quick Start

### Prerequisites

- **Python** 3.10+
- **Flutter SDK** 3.0+ (with Dart)
- **PostgreSQL** database (or a free [Supabase](https://supabase.com) project)
- **uv** package manager: `curl -LsSf https://astral.sh/uv/install.sh | sh`

---

### 1. Train the AI Model

```bash
cd AI_model
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

# Train on the provided dataset
python train_fcm.py --csv data_avatar.csv --out fcm_model.joblib

# Verify: test the standalone API
uvicorn main:app --reload
# → http://127.0.0.1:8000/docs
```

---

### 2. Backend Setup

```bash
cd backend

# Install dependencies with uv
uv pip install --system .

# Configure environment
cp .env.example .env
# Edit .env with your values (see Environment Variables section)

# Start the development server
uvicorn app.main:app --reload --port 8000
```

API available at **`http://localhost:8000`**
Swagger docs: **`http://localhost:8000/docs`**

The escalation background worker starts automatically with the app (via FastAPI `lifespan`).

---

### 3. Frontend Setup

```bash
cd frontend

# Get Flutter dependencies
flutter pub get

# Configure the API URL
# Edit lib/config/api_config.dart → set your backend URL

# Run on a connected device or emulator
flutter run

# Build for Android
flutter build apk --release

# Build for iOS
flutter build ios --release
```

---

## 🔐 Environment Variables

Copy `backend/.env.example` to `backend/.env` and fill in your values:

```env
# ── Database ───────────────────────────────────────────────────
DATABASE_URL=postgresql+psycopg2://USER:PASSWORD@HOST:5432/DBNAME

# ── Authentication (JWT) ───────────────────────────────────────
JWT_SECRET=change_me_to_a_long_random_secret
JWT_ALGORITHM=HS256
JWT_EXPIRES_MINUTES=1440

# ── Email Alerts (SMTP) ────────────────────────────────────────
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your.email@gmail.com
SMTP_PASS=your_google_app_password   # Use an App Password, not your main password
SMTP_FROM=your.email@gmail.com
SMTP_TLS=true

# ── Public URL (for alert ack links in emails) ─────────────────
PUBLIC_BASE_URL=https://your-backend.onrender.com

# ── CORS ───────────────────────────────────────────────────────
CORS_ORIGINS=*    # or comma-separated list of allowed origins

# ── Notification mode ──────────────────────────────────────────
NOTIF_DRY_RUN=false    # Set to true to disable real sends during development

# ── SMS fallback (optional) ────────────────────────────────────
TWILIO_ACCOUNT_SID=
TWILIO_AUTH_TOKEN=
TWILIO_FROM_PHONE=
```

> **Gmail tip:** Generate an [App Password](https://myaccount.google.com/apppasswords) (requires 2FA enabled). Never use your main Gmail password.

---

## 📡 API Reference

All endpoints except `/auth/register` and `/auth/login` require:
```
Authorization: Bearer <access_token>
```

### Authentication

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/auth/register` | Create a new patient account — returns JWT |
| `POST` | `/auth/login` | Login — returns JWT |

### Users

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/users/{id_user}` | Get user profile |
| `PATCH` | `/users/{id_user}` | Update user profile |

### Contacts

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/contacts/{id_user}` | List emergency contacts |
| `POST` | `/contacts` | Add a contact |
| `DELETE` | `/contacts/{id_contact}` | Remove a contact |

### Readings (Core Pipeline)

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/readings` | Submit a bracelet reading — triggers FCM classification + alert pipeline |
| `GET` | `/readings/latest/{id_user}` | Get the most recent reading |
| `GET` | `/readings/history/{id_user}` | Get full reading history |

**`POST /readings` body:**
```json
{
  "id_user": 1,
  "spo2_value": 94,
  "rr_value": 22,
  "hr_value": 105
}
```

**Response includes:**
```json
{
  "reading": { "id_physio": 42, "spo2_value": 94, ... },
  "prediction": { "id_predict": 7, "status_predict": "warning", ... },
  "alerts": [{ "id_alerte": 3, "stage": 1, "status": "sent", ... }]
}
```

### Predictions

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/predictions/{id_user}` | Get prediction history for a user |
| `POST` | `/predict` | Run FCM inference directly (no DB storage) |

### Alerts

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/alerts/{id_user}` | Get alert history |
| `POST` | `/alerts/{id_alerte}/ack` | Acknowledge an alert (stops escalation group) |
| `POST` | `/alerts/escalate/{id_predict}` | Manually trigger next escalation stage |
| `GET` | `/alerts/ack-link/{token}` | **Public** — one-click ack from email link |

> Full interactive documentation is auto-generated at **`/docs`** (Swagger UI) and **`/redoc`**.

---

## 🗄️ Database Schema

```
users
 ├── physio_variables ──────────────────────┐
 │    └── predic_results ──────────────────►│
 │         └── alertes ◄────────────────────┤
 └── contacts                               │
      └── alertes ◄────────────────────────►┘
```

**Table details:**

| Table | Key Columns | Purpose |
|-------|------------|---------|
| `users` | `id_user`, `email`, `phone`, `age`, `gender` | Patient accounts |
| `physio_variables` | `id_physio`, `spo2_value`, `rr_value`, `hr_value`, `time_of_record` | Raw bracelet readings |
| `predic_results` | `id_predict`, `id_physio`, `status_predict` | AI classification results |
| `contacts` | `id_contact`, `name_contact`, `email_contact`, `phone_contact`, `relation` | Emergency contacts (3 relation levels) |
| `alertes` | `id_alerte`, `stage`, `status`, `escalation_group_id`, `ack_token`, `provider` | Alert tracking with full audit trail |

**Alert audit fields on `alertes`:**

| Column | Description |
|--------|-------------|
| `escalation_group_id` | UUID linking all stages of one escalation sequence |
| `stage` | 1, 2, or 3 |
| `status` | `created` → `sent` → `acknowledged` / `failed` |
| `ack_token` | Unique token for email one-click acknowledgement |
| `sent_at` / `delivered_at` / `failed_at` / `acknowledged_at` | Full audit timestamps |
| `provider` | `email` or `twilio` |
| `error_message` | Error details if send failed |

---

## 🚢 Deployment

### Backend — Render (Docker)

The project includes a ready-to-use `render.yaml`:

```bash
# From the repo root — connect to Render via GitHub
# Render will use render.yaml automatically
```

**Manual setup:**
1. Create a new **Web Service** on [render.com](https://render.com)
2. Connect your GitHub repository
3. Set **Runtime**: Docker
4. Set **Dockerfile path**: `./backend/Dockerfile`
5. Set **Docker context**: `./backend`
6. Add environment variables from `.env.example`
7. `JWT_SECRET` is auto-generated by Render (`generateValue: true`)

The Dockerfile uses `uv` for fast dependency installation on `python:3.12-slim`.

---

### Database — Supabase

1. Create a project at [supabase.com](https://supabase.com)
2. Copy the **Connection string** from Settings → Database
3. Set `DATABASE_URL` in your Render environment variables
4. Tables are created automatically on first startup via SQLAlchemy `create_all`

> **Note:** Run the SQL scripts in `backend/supabase_add_ack_token.sql` if upgrading an existing schema to add the `ack_token` column.

---

### Flutter App

```bash
cd frontend

# Android
flutter build apk --release

# iOS
flutter build ios --release

# Web (for testing)
flutter build web
```

Update `lib/config/api_config.dart` with your production backend URL before building.

---

## 🧪 Running Tests

```bash
cd backend

# Test database connectivity
python test_db.py

# End-to-end API tests
python test_e2e_api.py
```

Set `NOTIF_DRY_RUN=true` in your `.env` before running tests to avoid sending real emails.

---

## 📊 Diagrams

The `diagrams/` folder contains Mermaid source files:

- **`class_diagram.mmd`** — full entity-relationship diagram
- **`use_case_diagram.mmd`** — patient and contact use cases

Render them at [mermaid.live](https://mermaid.live) or in any Mermaid-compatible viewer.

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

---

<div align="center">

Built with ❤️ for nocturnal asthma monitoring · Academic Project 2026

</div>
