from __future__ import annotations

import argparse
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from firebase_admin import auth

from app.accounts import claims_for_role
from app.firebase import database, ensure_firebase_app
from app.scheduling import utc_now


def main() -> None:
    parser = argparse.ArgumentParser(description="Assign the first owner role.")
    parser.add_argument("email")
    args = parser.parse_args()
    email = args.email.strip().lower()
    ensure_firebase_app()
    user = auth.get_user_by_email(email)
    auth.set_custom_user_claims(
        user.uid,
        claims_for_role(user.custom_claims, "owner"),
    )
    database().collection("users").document(user.uid).set(
        {
            "isAdmin": True,
            "isOwner": True,
            "role": "owner",
            "roleUpdatedAt": utc_now(),
        },
        merge=True,
    )
    auth.revoke_refresh_tokens(user.uid)
    print(f"Ruolo PROPRIETARIO assegnato a {email} ({user.uid}).")
    print("L'utente deve uscire e rientrare per aggiornare il token.")


if __name__ == "__main__":
    main()
