import 'package:flutter_test/flutter_test.dart';
import 'package:job_portal/models.dart';
void main(){test('job model reads API contract',(){final j=Job.fromJson({'id':1,'title':'Engineer','company_name':'Acme','location':'Remote','employment_type':'FULL_TIME','skills':['Dart']});expect(j.title,'Engineer');expect(j.skills.single,'Dart');});}
