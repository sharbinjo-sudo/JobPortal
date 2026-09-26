"""Transactional email delivery through EmailJS.

EmailJS credentials stay in the backend environment. The Flutter client never
receives either key, and registration remains successful if delivery fails so
an email-provider outage cannot prevent account creation.
"""
import logging
from dataclasses import dataclass

import requests
from django.conf import settings
from django.utils import timezone

logger = logging.getLogger('portal.email')
_EMAILJS_SEND_URL = 'https://api.emailjs.com/api/v1.0/email/send'


class EmailDeliveryError(RuntimeError):
    """Raised when EmailJS cannot accept a requested delivery."""


@dataclass(frozen=True)
class EmailDeliveryReceipt:
    status_code: int
    provider_response: str


def is_emailjs_configured() -> bool:
    """The public key is required by EmailJS; the private key protects server calls."""
    return bool(
        settings.EMAILJS_SERVICE_ID
        and settings.EMAILJS_TEMPLATE_ID
        and settings.EMAILJS_PUBLIC_KEY
        and settings.EMAILJS_PRIVATE_KEY
    )


def send_welcome_email(*, recipient_email: str, recipient_name: str, role_label: str, login_url: str) -> EmailDeliveryReceipt:
    """Send the configured welcome template to one newly registered account."""
    if not is_emailjs_configured():
        raise EmailDeliveryError('EmailJS is not fully configured.')

    role_message = (
        'Explore relevant jobs, keep your profile current, and track every application in one place.'
        if role_label == 'Job seeker'
        else 'Create company profiles, publish jobs, and manage your candidate pipeline in one place.'
    )
    payload = {
        'service_id': settings.EMAILJS_SERVICE_ID,
        'template_id': settings.EMAILJS_TEMPLATE_ID,
        'user_id': settings.EMAILJS_PUBLIC_KEY,
        'accessToken': settings.EMAILJS_PRIVATE_KEY,
        'template_params': {
            # Keep both names: EmailJS templates commonly use one or the other.
            'to_email': recipient_email,
            'user_email': recipient_email,
            'user_name': recipient_name or recipient_email,
            'user_role': role_label,
            'app_name': 'Northstar Jobs',
            'registration_date': timezone.localdate().strftime('%B %d, %Y'),
            'role_message': role_message,
            'login_url': login_url,
            'support_email': settings.DEFAULT_FROM_EMAIL,
            'current_year': str(timezone.localdate().year),
        },
    }
    try:
        response = requests.post(
            _EMAILJS_SEND_URL,
            json=payload,
            timeout=settings.EMAILJS_TIMEOUT_SECONDS,
        )
    except requests.RequestException as error:
        raise EmailDeliveryError('Email provider could not be reached.') from error

    if response.status_code != 200:
        logger.warning('emailjs_delivery_rejected', extra={'status_code': response.status_code})
        provider_message = response.text.strip().replace('\n', ' ')[:160]
        suffix = f' {provider_message}' if provider_message else ''
        raise EmailDeliveryError(f'Email provider rejected the request (HTTP {response.status_code}).{suffix}')

    return EmailDeliveryReceipt(status_code=response.status_code, provider_response=response.text[:200])


def welcome_login_url(request=None) -> str:
    if settings.PUBLIC_APP_URL:
        return settings.PUBLIC_APP_URL
    if request is not None:
        return request.build_absolute_uri('/')
    return 'http://localhost:8000/'
