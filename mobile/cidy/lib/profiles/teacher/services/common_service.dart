import 'dart:convert';
import 'package:cidy/config.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/level_model.dart';
import '../models/section_model.dart';
import '../models/subject_model.dart';

class CommonService {
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<List<Level>> fetchLevels() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('${Config.backendUrl}/api/common/levels/'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Level.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load levels');
    }
  }

  Future<List<Section>> fetchSections() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('${Config.backendUrl}/api/common/sections/'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Section.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load sections');
    }
  }

  Future<List<Subject>> fetchSubjects() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('${Config.backendUrl}/api/common/subjects/'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Subject.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load subjects');
    }
  }
}
