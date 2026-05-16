from availability_service import is_recovery_time_valid


if __name__ == "__main__":
    sample_seconds = 3.5
    print({
        "recovery_seconds": sample_seconds,
        "is_valid": is_recovery_time_valid(sample_seconds),
    })
