"""Audit trail — append-only records for security-relevant events."""
import logging

from django.conf import settings
from django.db import models

audit_logger = logging.getLogger('portal.audit')
db_logger = logging.getLogger('portal.db')


class AuditLog(models.Model):
    """Append-only audit trail for security-relevant and business events."""

    class Action(models.TextChoices):
        LOGIN = 'LOGIN', 'Login'
        LOGIN_FAILED = 'LOGIN_FAILED', 'Login failed'
        REGISTER = 'REGISTER', 'Registration'
        WELCOME_EMAIL_SENT = 'WELCOME_EMAIL_SENT', 'Welcome email sent'
        WELCOME_EMAIL_FAILED = 'WELCOME_EMAIL_FAILED', 'Welcome email failed'
        JOB_CREATED = 'JOB_CREATED', 'Job created'
        JOB_UPDATED = 'JOB_UPDATED', 'Job updated'
        JOB_CLOSED = 'JOB_CLOSED', 'Job closed'
        APPLICATION_SUBMITTED = 'APPLICATION_SUBMITTED', 'Application submitted'
        APPLICATION_STATUS_CHANGED = 'APPLICATION_STATUS_CHANGED', 'Application status changed'
        RESUME_UPLOADED = 'RESUME_UPLOADED', 'Resume uploaded'
        LOGO_UPLOADED = 'LOGO_UPLOADED', 'Logo uploaded'
        USER_DEACTIVATED = 'USER_DEACTIVATED', 'User deactivated'

    actor = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, blank=True,
        on_delete=models.SET_NULL, related_name='audit_logs',
    )
    action = models.CharField(max_length=40, choices=Action.choices, db_index=True)
    object_type = models.CharField(max_length=60, blank=True)
    object_id = models.CharField(max_length=60, blank=True)
    ip = models.GenericIPAddressField(null=True, blank=True)
    user_agent = models.CharField(max_length=255, blank=True)
    request_id = models.CharField(max_length=36, blank=True)
    metadata = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['actor', '-created_at']),
            models.Index(fields=['action', '-created_at']),
        ]

    def __str__(self):
        who = self.actor.email if self.actor_id else 'anonymous'
        return f'{self.created_at:%Y-%m-%d %H:%M:%S} {who} {self.action}'


def record_audit(request, *, action: str, obj=None, metadata: dict | None = None) -> None:
    """Persist an audit row and mirror it to the structured log.

    Best-effort by design: audit failures must never break the user-facing
    request, but they are still logged so operators can investigate.
    """
    try:
        from .middleware import get_request_id
        request_id = get_request_id(getattr(request, '_request', request))
    except Exception:
        request_id = ''

    user = getattr(request, 'user', None)
    actor = user if getattr(user, 'is_authenticated', False) else None

    try:
        AuditLog.objects.create(
            actor=actor,
            action=action,
            object_type=type(obj).__name__ if obj is not None else '',
            object_id=str(obj.pk) if obj is not None and getattr(obj, 'pk', None) else '',
            ip=getattr(request, 'META', {}).get('REMOTE_ADDR') or None,
            user_agent=(getattr(request, 'META', {}).get('HTTP_USER_AGENT') or '')[:255],
            request_id=request_id,
            metadata=metadata or {},
        )
    except Exception:
        audit_logger.exception('audit_write_failed', extra={'event': 'audit_write_failed', 'action': action})

    audit_logger.info(
        action,
        extra={
            'event': action,
            'user_id': getattr(actor, 'pk', None),
            'user_email': getattr(actor, 'email', None) if actor else None,
            'ip': getattr(request, 'META', {}).get('REMOTE_ADDR'),
            'request_id': request_id,
            'object': f'{type(obj).__name__}:{getattr(obj, "pk", "")}' if obj is not None else '',
            'metadata': metadata or {},
        },
    )
