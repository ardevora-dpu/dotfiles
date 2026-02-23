from pathlib import Path


def get_tutorials_directory() -> Path:
    """Return the central tutorials directory (~/coding-tutor-tutorials/)."""
    return Path.home() / "coding-tutor-tutorials"
