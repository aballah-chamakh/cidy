import 'dart:convert';
import 'package:cidy/config.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/group_model.dart';

class GroupService {
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<List<Group>> fetchGroups({
    String? name,
    int? levelId,
    int? sectionId,
    int? subjectId,
    String? day,
    String? timeRange,
    String? sortBy,
  }) async {
    final token = await _getToken();
    var url = Uri.parse('${Config.backendUrl}/api/teacher/groups/');
    final Map<String, String> queryParams = {};
    if (name != null) queryParams['name'] = name;
    if (levelId != null) queryParams['level'] = levelId.toString();
    if (sectionId != null) queryParams['section'] = sectionId.toString();
    if (subjectId != null) queryParams['subject'] = subjectId.toString();
    if (day != null) queryParams['day'] = day;
    if (timeRange != null) queryParams['time_range'] = timeRange;
    if (sortBy != null) queryParams['sort_by'] = sortBy;

    if (queryParams.isNotEmpty) {
      url = url.replace(queryParameters: queryParams);
    }

    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<dynamic> groupList = data['results'];
      return groupList.map((json) => Group.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load groups');
    }
  }

  Future<void> deleteGroups(List<int> groupIds) async {
    final token = await _getToken();
    final url = Uri.parse(
      '${Config.backendUrl}/api/teacher/groups/delete_groups/',
    );

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({'group_ids': groupIds}),
    );

    if (response.statusCode != 204) {
      throw Exception('Failed to delete groups');
    }
  }

  Future<Group> createGroup({
    required String name,
    required int levelId,
    int? sectionId,
    required int subjectId,
  }) async {
    final token = await _getToken();
    final url = Uri.parse('${Config.backendUrl}/api/teacher/groups/');
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'name': name,
        'level': levelId,
        'section': sectionId,
        'subject': subjectId,
      }),
    );

    if (response.statusCode == 201) {
      return Group.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to create group');
    }
  }
}
