from pathlib import Path
from rest_framework.exceptions import ValidationError

MAX_RESUME_BYTES = 5 * 1024 * 1024
MAX_IMAGE_BYTES = 2 * 1024 * 1024
RESUME_EXTENSIONS = {'.pdf', '.doc', '.docx'}
IMAGE_EXTENSIONS = {'.png', '.jpg', '.jpeg', '.webp'}


def validate_resume(upload):
    extension = Path(upload.name).suffix.lower()
    if extension not in RESUME_EXTENSIONS:
        raise ValidationError({'resume': 'Upload a PDF, DOC, or DOCX file.'})
    if upload.size > MAX_RESUME_BYTES:
        raise ValidationError({'resume': 'Resume files must be 5 MB or smaller.'})
    header = upload.read(8)
    upload.seek(0)
    if extension == '.pdf' and not header.startswith(b'%PDF'):
        raise ValidationError({'resume': 'The uploaded PDF is not valid.'})
    if extension == '.docx' and not header.startswith(b'PK'):
        raise ValidationError({'resume': 'The uploaded DOCX is not valid.'})
    return upload


def validate_logo(upload):
    extension = Path(upload.name).suffix.lower()
    if extension not in IMAGE_EXTENSIONS:
        raise ValidationError({'logo': 'Upload a PNG, JPG, JPEG, or WEBP image.'})
    if upload.size > MAX_IMAGE_BYTES:
        raise ValidationError({'logo': 'Company images must be 2 MB or smaller.'})
    return upload
