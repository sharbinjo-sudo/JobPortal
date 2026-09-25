class User {
  final int id;
  final String email;
  final String firstName;
  final String lastName;
  final String phone;
  final String role;
  final bool isActive;
  final int applicationCount;

  const User({required this.id, required this.email, required this.firstName, required this.lastName, required this.phone, required this.role, this.isActive = true, this.applicationCount = 0});
  String get displayName => '$firstName $lastName'.trim();
  bool get isAdmin => role == 'ADMIN';
  bool get isRecruiter => role == 'RECRUITER';
  bool get isSeeker => role == 'JOB_SEEKER';
  factory User.fromJson(Map<String, dynamic> json) => User(id: json['id'] as int, email: json['email'] as String? ?? '', firstName: json['first_name'] as String? ?? '', lastName: json['last_name'] as String? ?? '', phone: json['phone'] as String? ?? '', role: json['role'] as String? ?? 'JOB_SEEKER', isActive: json['is_active'] as bool? ?? true, applicationCount: json['application_count'] as int? ?? 0);
  Map<String, dynamic> toJson() => {'id': id, 'email': email, 'first_name': firstName, 'last_name': lastName, 'phone': phone, 'role': role, 'is_active': isActive};
}

class Job {
  final int id;
  final int companyId;
  final String title;
  final String companyName;
  final String location;
  final String employmentType;
  final String workMode;
  final String status;
  final String description;
  final List<String> skills;
  final int experienceMin;
  final num? salaryMin;
  final num? salaryMax;
  final String currency;
  final bool isOpen;

  const Job({required this.id, required this.companyId, required this.title, required this.companyName, required this.location, required this.employmentType, required this.workMode, required this.status, required this.description, required this.skills, required this.experienceMin, required this.salaryMin, required this.salaryMax, required this.currency, required this.isOpen});
  String get employmentLabel => displayLabel(employmentType);
  String get workModeLabel => displayLabel(workMode);
  String get salaryLabel => salaryMin == null && salaryMax == null ? 'Salary not listed' : salaryMax == null ? '$currency ${salaryMin!.toStringAsFixed(0)}+' : '$currency ${salaryMin?.toStringAsFixed(0) ?? '0'} - ${salaryMax!.toStringAsFixed(0)}';
  factory Job.fromJson(Map<String, dynamic> json) => Job(
    id: json['id'] as int,
    companyId: json['company'] as int? ?? 0,
    title: json['title'] as String? ?? 'Untitled role',
    companyName: json['company_name'] as String? ?? '',
    location: json['location'] as String? ?? '',
    employmentType: json['employment_type'] as String? ?? 'FULL_TIME',
    workMode: json['work_mode'] as String? ?? 'HYBRID',
    status: json['status'] as String? ?? 'OPEN',
    description: json['description'] as String? ?? '',
    skills: List<String>.from(json['skills'] as List? ?? const []),
    experienceMin: json['experience_min'] as int? ?? 0,
    salaryMin: parseNum(json['salary_min']),
    salaryMax: parseNum(json['salary_max']),
    currency: json['currency'] as String? ?? 'USD',
    isOpen: json['is_open'] as bool? ?? true,
  );
}

class Company {
  final int id;
  final String name;
  final String description;
  final String industry;
  final String website;
  final String location;
  final String logoUrl;
  final bool isActive;
  final int openJobs;
  final int jobCount;
  final String ownerName;

  const Company({required this.id, required this.name, required this.description, required this.industry, required this.website, required this.location, required this.logoUrl, required this.isActive, this.openJobs = 0, this.jobCount = 0, this.ownerName = ''});
  factory Company.fromJson(Map<String, dynamic> json) {
    final owner = json['owner'];
    return Company(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      industry: json['industry'] as String? ?? '',
      website: json['website'] as String? ?? '',
      location: json['location'] as String? ?? '',
      logoUrl: (json['logo_file_url'] as String?) ?? (json['logo_url'] as String?) ?? '',
      isActive: json['is_active'] as bool? ?? true,
      openJobs: json['open_jobs'] as int? ?? 0,
      jobCount: json['job_count'] as int? ?? 0,
      ownerName: owner is Map ? '${owner['first_name'] ?? ''} ${owner['last_name'] ?? ''}'.trim() : '',
    );
  }
}

class HistoryEntry {
  final String oldStatus;
  final String newStatus;
  final String changedByName;
  final String note;
  final String createdAt;
  const HistoryEntry({required this.oldStatus, required this.newStatus, required this.changedByName, required this.note, required this.createdAt});
  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    final changedBy = json['changed_by'];
    return HistoryEntry(oldStatus: json['old_status'] as String? ?? '', newStatus: json['new_status'] as String? ?? '', changedByName: changedBy is Map ? '${changedBy['first_name'] ?? ''} ${changedBy['last_name'] ?? ''}'.trim() : '', note: json['note'] as String? ?? '', createdAt: json['created_at'] as String? ?? '');
  }
}

class ApplicationItem {
  final int id;
  final int jobId;
  final String jobTitle;
  final String companyName;
  final String applicantName;
  final String applicantEmail;
  final String status;
  final String appliedAt;
  final String coverLetter;
  final String resumeUrl;
  final List<HistoryEntry> history;

  const ApplicationItem({required this.id, required this.jobId, required this.jobTitle, required this.companyName, required this.applicantName, required this.applicantEmail, required this.status, required this.appliedAt, required this.coverLetter, required this.resumeUrl, required this.history});
  factory ApplicationItem.fromJson(Map<String, dynamic> json) {
    final applicant = json['applicant'];
    return ApplicationItem(
      id: json['id'] as int,
      jobId: json['job'] as int? ?? 0,
      jobTitle: json['job_title'] as String? ?? 'Role',
      companyName: json['company_name'] as String? ?? '',
      applicantName: applicant is Map ? '${applicant['first_name'] ?? ''} ${applicant['last_name'] ?? ''}'.trim() : 'Candidate',
      applicantEmail: applicant is Map ? applicant['email'] as String? ?? '' : '',
      status: json['status'] as String? ?? 'APPLIED',
      appliedAt: json['applied_at'] as String? ?? '',
      coverLetter: json['cover_letter'] as String? ?? '',
      resumeUrl: json['resume_url'] as String? ?? '',
      history: (json['history'] as List? ?? const []).map((item) => HistoryEntry.fromJson(Map<String, dynamic>.from(item as Map))).toList(),
    );
  }
}

const applicationStatuses = ['APPLIED', 'SHORTLISTED', 'INTERVIEW', 'SELECTED', 'REJECTED'];

const employmentTypes = {'FULL_TIME': 'Full time', 'PART_TIME': 'Part time', 'CONTRACT': 'Contract', 'INTERNSHIP': 'Internship'};

const workModes = {'REMOTE': 'Remote', 'HYBRID': 'Hybrid', 'ONSITE': 'On-site'};

String displayLabel(String value) => value.replaceAll('_', ' ').toLowerCase().split(' ').map((part) => part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}').join(' ');

/// DRF serializes DecimalField values as JSON strings ("2800000.00"); accept
/// both numbers and strings so parsing never crashes on either shape.
num? parseNum(dynamic value) {
  if (value is num) return value;
  if (value is String) return num.tryParse(value);
  return null;
}

/// Stable palette per application status so lists, chips, and charts agree.
const statusPalette = <String, int>{
  'APPLIED': 0xff1e88e5,
  'SHORTLISTED': 0xff7b1fa2,
  'INTERVIEW': 0xffef6c00,
  'SELECTED': 0xff2e7d32,
  'REJECTED': 0xffc62828,
};
