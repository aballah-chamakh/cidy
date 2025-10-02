import 'package:flutter/material.dart';
import '../models/group_model.dart';
import '../services/group_service.dart';

class GroupProvider with ChangeNotifier {
  final GroupService _groupService = GroupService();

  List<Group> _groups = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Group> get groups => _groups;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchGroups({
    String? name,
    int? levelId,
    int? sectionId,
    int? subjectId,
    String? day,
    String? timeRange,
    String? sortBy,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _groups = await _groupService.fetchGroups(
        name: name,
        levelId: levelId,
        sectionId: sectionId,
        subjectId: subjectId,
        day: day,
        timeRange: timeRange,
        sortBy: sortBy,
      );
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteGroups(List<int> groupIds) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _groupService.deleteGroups(groupIds);
      await fetchGroups(); // Refresh the list after deletion
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createGroup({
    required String name,
    required int levelId,
    int? sectionId,
    required int subjectId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _groupService.createGroup(
        name: name,
        levelId: levelId,
        sectionId: sectionId,
        subjectId: subjectId,
      );
      await fetchGroups(); // Refresh the list after creation
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
