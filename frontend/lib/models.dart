class User {
  final int id;
  final String email;
  final String firstName;
  final String lastName;
  final String role;
  const User({required this.id, required this.email, required this.firstName, required this.lastName, required this.role});
  String get displayName => '$firstName $lastName'.trim();
  factory User.fromJson(Map<String, dynamic> json) => User(id: json['id'] as int, email: json['email'] as String, firstName: json['first_name'] as String? ?? '', lastName: json['last_name'] as String? ?? '', role: json['role'] as String? ?? 'JOB_SEEKER');
}

class Job {
  final int id; final String title; final String companyName; final String location; final String employmentType; final String workMode; final String description; final List<String> skills; final int experienceMin; final num? salaryMin; final num? salaryMax; final String currency; final bool isOpen;
  const Job({required this.id, required this.title, required this.companyName, required this.location, required this.employmentType, required this.workMode, required this.description, required this.skills, required this.experienceMin, required this.salaryMin, required this.salaryMax, required this.currency, required this.isOpen});
  factory Job.fromJson(Map<String, dynamic> json) => Job(id: json['id'] as int, title: json['title'] as String? ?? 'Untitled role', companyName: json['company_name'] as String? ?? '', location: json['location'] as String? ?? '', employmentType: json['employment_type'] as String? ?? 'FULL_TIME', workMode: json['work_mode'] as String? ?? 'HYBRID', description: json['description'] as String? ?? '', skills: List<String>.from(json['skills'] as List? ?? const []), experienceMin: json['experience_min'] as int? ?? 0, salaryMin: json['salary_min'] as num?, salaryMax: json['salary_max'] as num?, currency: json['currency'] as String? ?? 'USD', isOpen: json['is_open'] as bool? ?? true);
  String get employmentLabel => _label(employmentType);
  String get workModeLabel => _label(workMode);
  String get salaryLabel { if (salaryMin == null && salaryMax == null) return 'Salary not listed'; final minimum = salaryMin?.toStringAsFixed(0) ?? '0'; final maximum = salaryMax?.toStringAsFixed(0); return maximum == null ? '$currency $minimum+' : '$currency $minimum - $maximum'; }
}

String _label(String value) => value.replaceAll('_', ' ').toLowerCase().split(' ').map((word) => '${word[0].toUpperCase()}${word.substring(1)}').join(' ');
