from confidentiality_service import is_suspicious_payload


if __name__ == "__main__":
    print({"suspicious": is_suspicious_payload("' OR '1'='1")})
