import 'dart:convert';
import 'package:cidy/app_styles.dart';
import 'package:cidy/config.dart';
import 'package:cidy/profiles/teacher/widgets/teacher_layout.dart';
import 'package:cidy/profiles/teacher/widgets/teacher_subjects_screen/add_subject_popup.dart';
import 'package:cidy/profiles/teacher/widgets/teacher_subjects_screen/confirm_delete_popup.dart';
import 'package:cidy/profiles/teacher/widgets/teacher_subjects_screen/edit_subject_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:cidy/authentication/login.dart';

class TeacherSubjectsScreen extends StatefulWidget {
  const TeacherSubjectsScreen({super.key});

  @override
  State<TeacherSubjectsScreen> createState() => _TeacherSubjectsScreenState();
}

class _TeacherSubjectsScreenState extends State<TeacherSubjectsScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _levels = {};
  final Set<String> _expandedLevels = {};
  final Set<String> _expandedSections = {};

  @override
  void initState() {
    super.initState();
    _fetchSubjects();
  }

  Future<void> _fetchSubjects() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      if (token == null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
        return;
      }

      final response = await http.get(
        Uri.parse('${Config.backendUrl}/api/teacher/levels_sections_subjects/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final hierarchy = data['teacher_levels_sections_subjects_hierarchy'];
        setState(() {
          _levels = _asMap(hierarchy);
        });
      } else if (response.statusCode == 401) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      } else {
        _showError('Erreur du serveur');
      }
    } catch (e) {
      _showError('An error occurred. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _toggleLevel(String levelName) {
    setState(() {
      if (_expandedLevels.contains(levelName)) {
        _expandedLevels.remove(levelName);
      } else {
        _expandedLevels.add(levelName);
      }
    });
  }

  void _toggleSection(String levelName, String sectionName) {
    setState(() {
      final key = '$levelName-$sectionName';
      if (_expandedSections.contains(key)) {
        _expandedSections.remove(key);
      } else {
        _expandedSections.add(key);
      }
    });
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, dynamic val) => MapEntry(key.toString(), val));
    }
    return <String, dynamic>{};
  }

  List<dynamic> _asList(dynamic value) {
    if (value is List) {
      return List<dynamic>.from(value);
    }
    return <dynamic>[];
  }

  int? _extractId(dynamic data) {
    if (data is Map) {
      final map = _asMap(data);
      final idValue =
          map['id'] ?? map['teacher_subject_id'] ?? map['teacherSubjectId'];
      if (idValue is int) {
        return idValue;
      }
      if (idValue is String) {
        return int.tryParse(idValue);
      }
    }
    if (data is int) {
      return data;
    }
    if (data is String) {
      return int.tryParse(data);
    }
    return null;
  }

  double? _asDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      final normalised = value.replaceAll(',', '.');
      return double.tryParse(normalised);
    }
    return null;
  }

  double? _extractPrice(dynamic data) {
    if (data is Map) {
      final map = _asMap(data);
      final priceValue =
          map['price'] ?? map['price_per_class'] ?? map['pricePerClass'];
      return _asDouble(priceValue);
    }
    return _asDouble(data);
  }

  String _extractSubjectName(dynamic data) {
    if (data is Map) {
      final map = _asMap(data);
      final nameValue =
          map['name'] ?? map['subject_name'] ?? map['subjectName'];
      if (nameValue != null) {
        return nameValue.toString();
      }
    }
    if (data != null) {
      return data.toString();
    }
    return 'Unknown subject';
  }

  String? _priceLabel(dynamic data) {
    final price = _extractPrice(data);
    if (price != null) {
      final hasDecimals = (price % 1) != 0;
      final formatted = hasDecimals
          ? price.toStringAsFixed(2)
          : price.toStringAsFixed(0);
      return '$formatted DT';
    }

    if (data is Map) {
      final map = _asMap(data);
      final raw =
          map['price'] ?? map['price_per_class'] ?? map['pricePerClass'];
      if (raw != null) {
        return '${raw.toString()} DT';
      }
    }

    return null;
  }

  void _showAddSubjectDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AddSubjectPopup(
          onSubjectAdded: () {
            _fetchSubjects();
            _showSuccess('Subject added successfully!');
          },
        );
      },
    );
  }

  void _showEditSubjectDialog(
    String subjectName,
    int teacherSubjectId,
    double currentPrice,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return EditSubjectPopup(
          subjectName: subjectName,
          teacherSubjectId: teacherSubjectId,
          initialPrice: currentPrice,
          onSubjectUpdated: () {
            _fetchSubjects();
            _showSuccess('Subject updated successfully!');
          },
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(String type, String name, int id) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ConfirmDeletePopup(
          type: type,
          name: name,
          id: id,
          onDeleteConfirmed: () {
            _fetchSubjects();
            _showSuccess('$type deleted successfully!');
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return TeacherLayout(
      title: 'Subjects',
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        Expanded(
          child: _levels.isEmpty ? _buildNoSubjectsUI() : _buildLevelsList(),
        ),
        _buildStickyFooter(),
      ],
    );
  }

  Widget _buildNoSubjectsUI() {
    return const Center(
      child: Text(
        'There are no levels yet',
        style: TextStyle(fontSize: 18, color: Colors.grey),
      ),
    );
  }

  Widget _buildLevelsList() {
    return ListView(
      padding: const EdgeInsets.all(8.0),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Text('Levels', style: AppStyles.title),
        ),
        ..._levels.entries.map((levelEntry) {
          final levelName = levelEntry.key;
          final levelData = _asMap(levelEntry.value);
          final levelId = _extractId(levelData);
          final isExpanded = _expandedLevels.contains(levelName);
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
            child: Column(
              children: [
                ListTile(
                  title: Text(levelName, style: AppStyles.title),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: levelId == null
                            ? null
                            : () => _showDeleteConfirmationDialog(
                                'level',
                                levelName,
                                levelId,
                              ),
                      ),
                      IconButton(
                        icon: Icon(
                          isExpanded
                              ? Icons.arrow_drop_up
                              : Icons.arrow_drop_down,
                        ),
                        onPressed: () => _toggleLevel(levelName),
                      ),
                    ],
                  ),
                ),
                if (isExpanded)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 16.0,
                      right: 16.0,
                      bottom: 8.0,
                    ),
                    child: _buildLevelContent(levelName, levelData),
                  ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildLevelContent(String levelName, Map<String, dynamic> levelData) {
    final sections = levelData['sections'];
    if (sections is Map) {
      return _buildSectionsList(levelName, sections.cast<String, dynamic>());
    }

    final subjects = levelData['subjects'];
    if (subjects is List) {
      return _buildSubjectsList(List<dynamic>.from(subjects));
    }
    return const SizedBox.shrink();
  }

  Widget _buildSectionsList(String levelName, Map<String, dynamic> sections) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Sections', style: AppStyles.title),
        ...sections.entries.map((sectionEntry) {
          final sectionName = sectionEntry.key;
          final sectionData = _asMap(sectionEntry.value);
          final sectionId = _extractId(sectionData);
          final isExpanded = _expandedSections.contains(
            '$levelName-$sectionName',
          );
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4.0),
            child: Column(
              children: [
                ListTile(
                  title: Text(sectionName, style: AppStyles.title),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: sectionId == null
                            ? null
                            : () => _showDeleteConfirmationDialog(
                                'section',
                                sectionName,
                                sectionId,
                              ),
                      ),
                      IconButton(
                        icon: Icon(
                          isExpanded
                              ? Icons.arrow_drop_up
                              : Icons.arrow_drop_down,
                        ),
                        onPressed: () => _toggleSection(levelName, sectionName),
                      ),
                    ],
                  ),
                ),
                if (isExpanded)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 16.0,
                      right: 16.0,
                      bottom: 8.0,
                    ),
                    child: _buildSubjectsList(_asList(sectionData['subjects'])),
                  ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildSubjectsList(List<dynamic> subjects) {
    if (subjects.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Subjects', style: AppStyles.title),
          SizedBox(height: 4.0),
          Text('No subjects added yet.', style: TextStyle(color: Colors.grey)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Subjects', style: AppStyles.title),
        ...subjects.map((subject) {
          final subjectName = _extractSubjectName(subject);
          final subjectId = _extractId(subject);
          final priceLabel = _priceLabel(subject);
          final editPrice = _extractPrice(subject) ?? 0;

          final actionButtons = <Widget>[];
          if (subjectId != null) {
            actionButtons.add(
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _showDeleteConfirmationDialog(
                  'subject',
                  subjectName,
                  subjectId,
                ),
              ),
            );
            actionButtons.add(
              IconButton(
                icon: const Icon(Icons.edit, color: primaryColor),
                onPressed: () =>
                    _showEditSubjectDialog(subjectName, subjectId, editPrice),
              ),
            );
          }

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4.0),
            child: ListTile(
              title: Text(subjectName),
              subtitle: priceLabel != null ? Text(priceLabel) : null,
              trailing: actionButtons.isEmpty
                  ? null
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: actionButtons,
                    ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildStickyFooter() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Colors.white,
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: primaryButtonStyle,
          onPressed: _showAddSubjectDialog,
          child: const Text('Add a subject'),
        ),
      ),
    );
  }
}
