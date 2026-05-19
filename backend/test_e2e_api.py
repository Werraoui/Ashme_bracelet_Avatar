"""
Quick end-to-end API smoke test (run from backend/ with server up).

    python test_e2e_api.py
    python test_e2e_api.py --base-url https://ashme-bracelet-avatar.onrender.com
"""

from __future__ import annotations

import argparse
import random
import sys

import requests


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-url", default="http://127.0.0.1:8000")
    args = parser.parse_args()
    base = args.base_url.rstrip("/")

    health = requests.get(f"{base}/", timeout=30)
    health.raise_for_status()
    print("health:", health.json())

    ml = requests.post(
        f"{base}/prediction/predict",
        json={"heart_rate": 95, "respiratory_rate": 18, "spo2": 88},
        timeout=30,
    )
    if ml.status_code == 404:
        print("WARN: /prediction/predict missing — redeploy backend to Render")
    else:
        ml.raise_for_status()
        print("ml:", ml.json())

    email = f"smoke_{random.randint(10000, 99999)}@avatar.os"
    signup = requests.post(
        f"{base}/auth/signup",
        json={
            "last_name": "Smoke",
            "first_name": "Test",
            "email": email,
            "phone": f"+336{random.randint(10000000, 99999999)}",
            "age": 30,
            "gender": "male",
            "pass_word": "Test1234!",
        },
        timeout=30,
    )
    signup.raise_for_status()
    user_id = signup.json()["id_user"]

    token = requests.post(
        f"{base}/auth/signin-json",
        json={"email": email, "pass_word": "Test1234!"},
        timeout=30,
    )
    token.raise_for_status()
    headers = {"Authorization": f"Bearer {token.json()['access_token']}"}

    reading = requests.post(
        f"{base}/readings",
        headers=headers,
        json={
            "id_user": user_id,
            "spo2_value": 88,
            "hr_value": 95,
            "rr_value": 18,
        },
        timeout=30,
    )
    reading.raise_for_status()
    physio_id = reading.json()["id_physio"]
    print("physio_variables insert ok:", physio_id)

    pred = requests.get(f"{base}/predictions/latest/{user_id}", headers=headers, timeout=30)
    if pred.status_code == 404:
        print("FAIL: /predictions/latest missing — dashboard risk UI will not work")
        return 1
    pred.raise_for_status()
    print("predic_results:", pred.json())
    return 0


if __name__ == "__main__":
    sys.exit(main())
