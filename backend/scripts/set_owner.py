from __future__ import annotations

import argparse
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.auth import revoke_all_sessions
from app.database import database
from app.scheduling import utc_now


def main() -> None:
    parser = argparse.ArgumentParser(description="Assign the first owner role.")
    parser.add_argument("email")
    args = parser.parse_args()
    email = args.email.strip().lower()
    db = database()
    user = db.users.find_one({"emailLower": email, "deletedAt": None})
    if not user:
        raise SystemExit(f"Utente non trovato: {email}")
    db.users.update_one(
        {"_id": user["_id"]},
        {
            "$set": {
                "role": "owner",
                "roleUpdatedAt": utc_now(),
                "updatedAt": utc_now(),
            }
        },
    )
    revoke_all_sessions(db, str(user["_id"]))
    print(f"Ruolo PROPRIETARIO assegnato a {email} ({user['_id']}).")
    print("L'utente deve uscire e rientrare per aggiornare il token.")


if __name__ == "__main__":
    main()
