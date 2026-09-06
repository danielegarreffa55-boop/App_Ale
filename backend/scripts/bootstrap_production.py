from __future__ import annotations

import argparse
from pathlib import Path
import sys

from pymongo.errors import DuplicateKeyError

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.database import database, ensure_indexes
from app.scheduling import DEFAULT_OPENING_HOURS, utc_now


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Create the initial MongoDB production configuration.",
    )
    parser.add_argument("--studio-name", default="Alessio Garreffa Hair")
    parser.add_argument("--phone", default="+39 342 535 5594")
    parser.add_argument("--email", default="")
    parser.add_argument("--address", default="Via Cottolengo 44, 10048 Vinovo TO")
    args = parser.parse_args()
    db = database()
    ensure_indexes(db)
    try:
        db.studio.insert_one(
            {
                "_id": "config",
                "studioName": args.studio_name.strip(),
                "supportPhone": args.phone.strip(),
                "supportEmail": args.email.strip(),
                "address": args.address.strip(),
                "timezone": "Europe/Rome",
                "currency": "EUR",
                "reminderTime": "18:00",
                "slotMinutes": 30,
                "minimumLeadMinutes": 120,
                "bookingHorizonDays": 90,
                "cancellationNoticeHours": 24,
                "openingHours": DEFAULT_OPENING_HOURS,
                "createdAt": utc_now(),
                "updatedAt": utc_now(),
            }
        )
    except DuplicateKeyError:
        print("Configurazione già presente: nessun dato è stato sovrascritto.")
        return
    print("Configurazione iniziale creata senza account o servizi demo.")


if __name__ == "__main__":
    main()
