import 'package:flutter/material.dart';
import '../models/level_model.dart';
import '../models/section_model.dart';
import '../models/subject_model.dart';
import '../services/common_service.dart';

class CommonProvider with ChangeNotifier {
  final CommonService _commonService = CommonService();

  List<Level> _levels = [];
  List<Section> _sections = [];
  List<Subject> _subjects = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Level> get levels => _levels;
  List<Section> get sections => _sections;
  List<Subject> get subjects => _subjects;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchCommonData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _levels = await _commonService.fetchLevels();
      _sections = await _commonService.fetchSections();
      _subjects = await _commonService.fetchSubjects();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
