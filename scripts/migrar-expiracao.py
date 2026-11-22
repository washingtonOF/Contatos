#!/usr/bin/env python3
"""Preenche a expiração de compartilhamentos antigos do IsaMig Mensagens."""

import argparse
import json
import os
import subprocess
import urllib.error
import urllib.request
from datetime import datetime, timedelta


LIFETIMES = {"sharedLocation": 1, "sharedUsage": 24, "statuses": 24}
PAGE_SIZE = 200


def migrate(project, apply):
    emulator = os.environ.get("FIRESTORE_EMULATOR_HOST")
    origin = f"http://{emulator}" if emulator else "https://firestore.googleapis.com"
    token = "owner" if emulator else subprocess.check_output(
        ["gcloud", "auth", "print-access-token"], text=True
    ).strip()
    root = f"projects/{project}/databases/(default)/documents"

    def request(method, path, payload):
        call = urllib.request.Request(
            f"{origin}/v1/{path}",
            data=json.dumps(payload).encode(),
            headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
            method=method,
        )
        with urllib.request.urlopen(call, timeout=30) as response:
            return json.load(response)

    for collection, hours in LIFETIMES.items():
        cursor = None
        eligible = updated = conflicts = invalid = 0
        while True:
            query = {
                "from": [{"collectionId": collection, "allDescendants": True}],
                "select": {"fields": [{"fieldPath": "createdAt"}, {"fieldPath": "expiresAt"}]},
                "orderBy": [{"field": {"fieldPath": "__name__"}, "direction": "ASCENDING"}],
                "limit": PAGE_SIZE,
            }
            if cursor is not None:
                query["startAt"] = {"values": [{"referenceValue": cursor}], "before": False}

            results = request("POST", f"{root}:runQuery", {"structuredQuery": query})
            documents = [row["document"] for row in results if "document" in row]
            for document in documents:
                name = document["name"]
                relative_path = name.removeprefix(root + "/").split("/")
                if len(relative_path) != 4 or relative_path[0] != "familyLinks":
                    continue
                fields = document.get("fields", {})
                if "expiresAt" in fields:
                    continue
                created = fields.get("createdAt", {}).get("timestampValue")
                if created is None:
                    invalid += 1
                    continue
                expires = datetime.fromisoformat(created.replace("Z", "+00:00")) + timedelta(
                    hours=hours, minutes=5
                )
                eligible += 1
                if not apply:
                    continue
                try:
                    request("POST", f"{root}:commit", {"writes": [{
                        "update": {
                            "name": name,
                            "fields": {"expiresAt": {"timestampValue": expires.isoformat()}},
                        },
                        "updateMask": {"fieldPaths": ["expiresAt"]},
                        "currentDocument": {"updateTime": document["updateTime"]},
                    }]})
                    updated += 1
                except urllib.error.HTTPError as error:
                    details = json.load(error).get("error", {})
                    if details.get("status") not in {"FAILED_PRECONDITION", "NOT_FOUND"}:
                        raise
                    conflicts += 1

            if len(documents) < PAGE_SIZE:
                break
            cursor = documents[-1]["name"]

        print(f"{collection} — elegíveis {eligible}, atualizados {updated}, "
              f"alterados durante a leitura {conflicts}, sem data válida {invalid}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", required=True, help="ID do projeto Firebase")
    parser.add_argument("--apply", action="store_true", help="grava as datas calculadas")
    args = parser.parse_args()
    print(f"Projeto {args.project} — {'gravação' if args.apply else 'simulação'}")
    migrate(args.project, args.apply)
