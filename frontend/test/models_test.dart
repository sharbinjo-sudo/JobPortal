import 'package:flutter_test/flutter_test.dart';
import 'package:job_portal/models.dart';

void main() {
  test('job model reads API contract', () {
    final j = Job.fromJson({'id': 1, 'title': 'Engineer', 'company_name': 'Acme', 'location': 'Remote', 'employment_type': 'FULL_TIME', 'skills': ['Dart'], 'experience_min': 3, 'salary_min': 1000, 'salary_max': 2000});
    expect(j.title, 'Engineer');
    expect(j.skills.single, 'Dart');
    expect(j.experienceMin, 3);
    expect(j.salaryLabel, contains('1000'));
  });

  test('application model maps applicant and history', () {
    final a = ApplicationItem.fromJson({
      'id': 5,
      'job': 2,
      'job_title': 'Engineer',
      'company_name': 'Acme',
      'status': 'SHORTLISTED',
      'applied_at': '2026-09-25T10:00:00Z',
      'applicant': {'id': 9, 'first_name': 'Ada', 'last_name': 'Lovelace', 'email': 'ada@example.com'},
      'resume_url': 'https://example.com/ada.pdf',
      'history': [{'old_status': 'APPLIED', 'new_status': 'SHORTLISTED', 'changed_by': {'first_name': 'Riya', 'last_name': 'Shah'}, 'note': 'good fit', 'created_at': '2026-09-25T11:00:00Z'}],
    });
    expect(a.jobId, 2);
    expect(a.applicantName, 'Ada Lovelace');
    expect(a.applicantEmail, 'ada@example.com');
    expect(a.resumeUrl, 'https://example.com/ada.pdf');
    expect(a.history.single.newStatus, 'SHORTLISTED');
    expect(a.history.single.changedByName, 'Riya Shah');
  });

  test('status palette covers every application status', () {
    for (final status in applicationStatuses) {
      expect(statusPalette[status], isNotNull);
    }
  });
}
