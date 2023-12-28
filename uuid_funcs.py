from base64 import urlsafe_b64decode, urlsafe_b64encode
from uuid import UUID


def encode_uuid_to_b64str(uuid: UUID) -> str:
    return urlsafe_b64encode(uuid.bytes).decode("utf8").rstrip("=\n")


def decode_b64str_to_uuid(b64str: str) -> UUID:
    return UUID(bytes=urlsafe_b64decode(f"{b64str}=="))