from django.core.management.base import BaseCommand, CommandError

from portal.emailing import EmailDeliveryError, send_welcome_email


class Command(BaseCommand):
    help = 'Send one explicit EmailJS welcome-email verification message.'

    def add_arguments(self, parser):
        parser.add_argument('--to', required=True, help='Recipient email address.')
        parser.add_argument('--name', default='Northstar tester', help='Recipient name shown in the template.')
        parser.add_argument('--role', default='Job seeker', help='Role shown in the template.')
        parser.add_argument('--login-url', default=None, help='Optional public application URL.')

    def handle(self, *args, **options):
        from portal.emailing import welcome_login_url

        try:
            receipt = send_welcome_email(
                recipient_email=options['to'],
                recipient_name=options['name'],
                role_label=options['role'],
                login_url=options['login_url'] or welcome_login_url(),
            )
        except EmailDeliveryError as error:
            raise CommandError(str(error)) from error
        self.stdout.write(self.style.SUCCESS(f'EmailJS accepted the welcome email (HTTP {receipt.status_code}).'))
