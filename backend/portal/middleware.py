"""Request auditing middleware — request IDs, latency, and access logs."""
import logging
import time
import uuid

logger = logging.getLogger('portal.audit')

# Paths that carry no audit value and would flood the trail.
SKIP_PREFIXES = ('/static/', '/media/', '/favicon', '/robots.txt')
SKIP_PATHS = {'/api/health/'}

SLOW_REQUEST_MS = 1000


class RequestAuditMiddleware:
    """Audits every API request: request id, actor, latency, status, IP.

    Adds an X-Request-ID response header so clients can reference a
    specific request in logs and support tickets.
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        path = request.path
        if path.startswith(SKIP_PREFIXES) or path in SKIP_PATHS:
            return self.get_response(request)

        request_id = request.headers.get('X-Request-ID') or str(uuid.uuid4())
        request.request_id = request_id
        start = time.monotonic()

        response = self.get_response(request)

        duration_ms = round((time.monotonic() - start) * 1000, 2)
        response['X-Request-ID'] = request_id

        user = getattr(request, 'user', None)
        authenticated = getattr(user, 'is_authenticated', False)
        level = logger.warning if response.status_code >= 500 else logger.info
        level(
            'request',
            extra={
                'event': 'request',
                'method': request.method,
                'path': path,
                'status_code': response.status_code,
                'duration_ms': duration_ms,
                'user_id': user.pk if authenticated else None,
                'user_email': user.email if authenticated else None,
                'ip': request.META.get('REMOTE_ADDR'),
                'request_id': request_id,
            },
        )
        if duration_ms >= SLOW_REQUEST_MS:
            logger.warning(
                'slow_request',
                extra={
                    'event': 'slow_request',
                    'method': request.method,
                    'path': path,
                    'duration_ms': duration_ms,
                    'request_id': request_id,
                },
            )
        return response


def get_request_id(request):
    return getattr(request, 'request_id', '')
