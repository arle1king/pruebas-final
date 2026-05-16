from integrity_service import is_payload_unchanged


if __name__ == "__main__":
    payload = {"id": "RPT-1", "total": 1500.5}
    print({"integrity_ok": is_payload_unchanged(payload, payload)})
