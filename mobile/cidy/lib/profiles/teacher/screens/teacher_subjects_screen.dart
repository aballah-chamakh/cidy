import 'dart:convert';
import 'package:cidy/app_styles.dart';
import 'package:cidy/config.dart';
import 'package:cidy/profiles/teacher/widgets/teacher_layout.dart';
import 'package:cidy/profiles/teacher/widgets/teacher_subjects_screen/add_subject_popup.dart';
import 'package:cidy/profiles/teacher/widgets/teacher_subjects_screen/delete_subject_popup.dart';
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
  Map<String, dynamic> _teacherLevels = {};
  Map<String, dynamic> _tesLevels = {};

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
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
        return;
      }

      final response = await http.get(
        Uri.parse(
          '${Config.backendUrl}/api/teacher/get_levels_sections_subjects/',
        ).replace(
          queryParameters: {
            'has_tes': _tesLevels.isNotEmpty ? 'true' : 'false',
          },
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final teacherHierarchy =
            data['teacher_levels_sections_subjects_hierarchy'];
        setState(() {
          _teacherLevels = _asMap(teacherHierarchy);
          if (_tesLevels.isEmpty) {
            final tesHierarchy = data['tes_levels_sections_subjects_hierarchy'];
            _tesLevels = _asMap(tesHierarchy);
          }
        });
      } else if (response.statusCode == 401) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      } else {
        _showError('Erreur du serveur (500)');
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Erreur du serveur (500)');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(fontSize: 16)),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(fontSize: 16)),
        backgroundColor: Colors.green,
      ),
    );
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
          teacherLevels: _teacherLevels,
          tesLevels: _tesLevels,
          onSubjectAdded: () {
            Navigator.of(context).pop();
            _showSuccess('Matière ajoutée avec succès!');
            _fetchSubjects();
          },
          onServerError: () {
            Navigator.of(context).pop();
            _showError('Erreur du serveur (500)');
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
            Navigator.of(context).pop();
            _showSuccess('Matière mise à jour avec succès!');
            _fetchSubjects();
          },
          onServerError: () {
            Navigator.of(context).pop();
            _showError('Erreur du serveur (500)');
          },
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(String type, String name, int id) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return DeleteSubjectPopup(
          name: name,
          id: id,
          onDeleteConfirmed: () {
            Navigator.of(context).pop();
            _showSuccess('Matière supprimée avec succès!');
            _fetchSubjects();
          },
          onServerError: () {
            Navigator.of(context).pop();
            _showError('Erreur du serveur (500)');
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return TeacherLayout(
      title: 'Matières',
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final content = RefreshIndicator(
      color: primaryColor,
      onRefresh: _fetchSubjects,
      child: _teacherLevels.isEmpty ? _buildNoSubjectsUI() : _buildLevelsList(),
    );

    if (_teacherLevels.isEmpty) {
      return content;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: content),
        Container(
          padding: const EdgeInsets.all(10.0),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                spreadRadius: 2,
                blurRadius: 5,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: _showAddSubjectDialog,
            label: const Text(
              'Ajouter une matière',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            icon: const Icon(Icons.add),
            style: primaryButtonStyle,
          ),
        ),
      ],
    );
  }

  Widget _buildNoSubjectsUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.menu_book, size: 100, color: primaryColor),
          const SizedBox(height: 10),
          const Text(
            "Aucune matière trouvée",
            style: TextStyle(fontSize: 20, color: primaryColor),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _showAddSubjectDialog,
            label: const Text(
              'Créez une matière',
              style: TextStyle(fontSize: 16),
            ),
            icon: const Icon(Icons.add),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5.0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelsList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 80.0),
      itemCount: _teacherLevels.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 8.0),
            child: Text(
              "Les niveaux",
              style: TextStyle(
                fontSize: mediumFontSize + 2,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }
        final levelIndex = index - 1;
        final levelName = _teacherLevels.keys.elementAt(levelIndex);
        final levelData = _asMap(_teacherLevels[levelName]);
        final levelId = _extractId(levelData);

        return _buildLevelCard(
          levelName: levelName,
          levelId: levelId,
          onDelete: () =>
              _showDeleteConfirmationDialog('niveau', levelName, levelId!),
          child: _buildLevelContent(levelName, levelData),
        );
      },
    );
  }

  Widget _buildLevelCard({
    required String levelName,
    int? levelId,
    required VoidCallback onDelete,
    required Widget child,
  }) {
    return Card(
      color: Colors.grey.shade100,
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey<String>(levelName),
          title: Text(
            levelName,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: mediumFontSize,
            ),
          ),
          children: [
            Container(
              color: Colors.grey.shade50,
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: child,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelContent(String levelName, Map<String, dynamic> levelData) {
    final sections = levelData['sections'];
    if (sections is Map && sections.isNotEmpty) {
      return _buildSectionsList(levelName, sections.cast<String, dynamic>());
    }

    final subjects = levelData['subjects'];
    if (subjects is List && subjects.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: _buildSubjectsList(List<dynamic>.from(subjects)),
      );
    }
    return const Padding(
      padding: EdgeInsets.all(16.0),
      child: Text(
        "Aucune section ou matière dans ce niveau.",
        style: TextStyle(color: Colors.grey),
      ),
    );
  }

  Widget _buildSectionsList(String levelName, Map<String, dynamic> sections) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16.0, 8.0, 0, 8.0),
          child: Text(
            "Les sections",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        ...sections.entries.map((sectionEntry) {
          final sectionName = sectionEntry.key;
          final sectionData = _asMap(sectionEntry.value);
          final sectionId = _extractId(sectionData);

          return _buildSectionCard(
            sectionName: sectionName,
            sectionId: sectionId,
            onDelete: () => _showDeleteConfirmationDialog(
              'section',
              sectionName,
              sectionId!,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 4.0,
              ),
              child: _buildSubjectsList(_asList(sectionData['subjects'])),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildSectionCard({
    required String sectionName,
    int? sectionId,
    required VoidCallback onDelete,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: PageStorageKey<String>(sectionName),
            title: Text(
              sectionName,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            children: [
              Container(
                color: Colors.grey.shade50,
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectsList(List<dynamic> subjects) {
    if (subjects.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          "Aucune matière dans cette section.",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(8.0, 0.0, 0.0, 8.0),
          child: Text(
            "Les matières",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        ...subjects.map((subject) {
          final subjectName = _extractSubjectName(subject);
          final subjectId = _extractId(subject);
          final priceLabel = _priceLabel(subject);
          final editPrice = _extractPrice(subject) ?? 0;

          return _buildSubjectCard(
            subjectName: subjectName,
            priceLabel: priceLabel,
            subjectId: subjectId,
            onEdit: () =>
                _showEditSubjectDialog(subjectName, subjectId!, editPrice),
            onDelete: () => _showDeleteConfirmationDialog(
              'matière',
              subjectName,
              subjectId!,
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildSubjectCard({
    required String subjectName,
    String? priceLabel,
    int? subjectId,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    return Card(
      color: Colors.grey.shade100,
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subjectName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (priceLabel != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      priceLabel,
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (subjectId != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: primaryColor),
                    onPressed: onEdit,
                    tooltip: 'Modifier',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: primaryColor),
                    onPressed: onDelete,
                    tooltip: 'Supprimer',
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
