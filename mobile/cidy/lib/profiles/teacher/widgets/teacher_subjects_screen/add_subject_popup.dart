import 'dart:convert';
import 'package:cidy/app_styles.dart';
import 'package:cidy/config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:cidy/authentication/login.dart';

class AddSubjectPopup extends StatefulWidget {
  final VoidCallback onSubjectAdded;

  const AddSubjectPopup({super.key, required this.onSubjectAdded});

  @override
  State<AddSubjectPopup> createState() => _AddSubjectPopupState();
}

class _AddSubjectPopupState extends State<AddSubjectPopup> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  Map<String, dynamic> _tunisianEducationSystem = {};
  String? _selectedLevel;
  String? _selectedSection;
  String? _selectedSubject;

  @override
  void initState() {
    super.initState();
    _fetchTunisianEducationSystem();
  }

  Future<void> _fetchTunisianEducationSystem() async {
    // In a real app, this would likely be fetched from a dedicated endpoint or a local asset.
    // For now, we'll use a hardcoded map based on typical Tunisian education structure.
    setState(() {
      _tunisianEducationSystem = {
        "1st Year Secondary": {
          "subjects": [
            "Math",
            "Physics",
            "Science",
            "French",
            "English",
            "Arabic",
            "History",
            "Geography",
            "Computer Science",
          ],
        },
        "2nd Year Secondary": {
          "sections": {
            "Science": {
              "subjects": [
                "Math",
                "Physics",
                "Science",
                "French",
                "English",
                "Arabic",
              ],
            },
            "Letters": {
              "subjects": [
                "Philosophy",
                "French",
                "English",
                "Arabic",
                "History",
                "Geography",
              ],
            },
            "Economics": {
              "subjects": [
                "Economics",
                "Management",
                "Math",
                "History",
                "Geography",
              ],
            },
            "Technical": {
              "subjects": ["Technology", "Math", "Physics"],
            },
          },
        },
        "3rd Year Secondary": {
          "sections": {
            "Math": {
              "subjects": [
                "Math",
                "Physics",
                "Science",
                "Philosophy",
                "French",
                "English",
              ],
            },
            "Experimental Science": {
              "subjects": ["Science", "Math", "Physics", "French", "English"],
            },
            "Computer Science": {
              "subjects": ["Computer Science", "Math", "Physics", "Algorithms"],
            },
            "Economics and Management": {
              "subjects": [
                "Economics",
                "Management",
                "Math",
                "History",
                "Geography",
              ],
            },
            "Technical Science": {
              "subjects": ["Technology", "Math", "Physics"],
            },
            "Letters": {
              "subjects": [
                "Philosophy",
                "French",
                "English",
                "Arabic",
                "History",
                "Geography",
              ],
            },
          },
        },
        "Baccalaureate": {
          "sections": {
            "Math": {
              "subjects": [
                "Math",
                "Physics",
                "Science",
                "Philosophy",
                "French",
                "English",
              ],
            },
            "Experimental Science": {
              "subjects": ["Science", "Math", "Physics", "French", "English"],
            },
            "Computer Science": {
              "subjects": ["Computer Science", "Math", "Physics", "Algorithms"],
            },
            "Economics and Management": {
              "subjects": [
                "Economics",
                "Management",
                "Math",
                "History",
                "Geography",
              ],
            },
            "Technical Science": {
              "subjects": ["Technology", "Math", "Physics"],
            },
            "Letters": {
              "subjects": [
                "Philosophy",
                "French",
                "English",
                "Arabic",
                "History",
                "Geography",
              ],
            },
          },
        },
      };
    });
  }

  Future<void> _addSubject() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      const storage = FlutterSecureStorage();
      final accessToken = await storage.read(key: 'accessToken');
      if (accessToken == null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (Route<dynamic> route) => false,
        );
        return;
      }

      final response = await http.post(
        Uri.parse('${Config.backendUrl}/api/teacher/subject/add/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'level': _selectedLevel,
          'section': _selectedSection,
          'subject': _selectedSubject,
        }),
      );

      if (response.statusCode == 201) {
        widget.onSubjectAdded();
        Navigator.of(context).pop();
      } else {
        final errorData = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _errorMessage = errorData['detail'] ?? 'Failed to add subject.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred. Please try again.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Add a subject', style: AppStyles.title),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                ),
              const SizedBox(height: 10),
              _buildLevelDropdown(),
              const SizedBox(height: 15),
              _buildSectionDropdown(),
              const SizedBox(height: 15),
              _buildSubjectDropdown(),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: primaryButtonStyle,
                  onPressed: _isLoading ? null : _addSubject,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text('Add'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLevelDropdown() {
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(
        labelText: 'Level',
        border: OutlineInputBorder(),
      ),
      value: _selectedLevel,
      items: _tunisianEducationSystem.keys.map((String level) {
        return DropdownMenuItem<String>(value: level, child: Text(level));
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedLevel = value;
          _selectedSection = null;
          _selectedSubject = null;
        });
      },
      validator: (value) => value == null ? 'Please select a level' : null,
    );
  }

  Widget _buildSectionDropdown() {
    final levelData = _selectedLevel != null
        ? _tunisianEducationSystem[_selectedLevel]
        : null;
    final sections = levelData != null && levelData.containsKey('sections')
        ? levelData['sections'] as Map<String, dynamic>
        : null;
    final bool isEnabled = sections != null;

    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: 'Section',
        border: const OutlineInputBorder(),
        filled: !isEnabled,
        fillColor: Colors.grey[200],
      ),
      value: _selectedSection,
      items: isEnabled
          ? sections.keys.map((String section) {
              return DropdownMenuItem<String>(
                value: section,
                child: Text(section),
              );
            }).toList()
          : [],
      onChanged: isEnabled
          ? (value) {
              setState(() {
                _selectedSection = value;
                _selectedSubject = null;
              });
            }
          : null,
      validator: (value) {
        if (isEnabled && value == null) {
          return 'Please select a section';
        }
        return null;
      },
    );
  }

  Widget _buildSubjectDropdown() {
    List<String> subjects = [];
    bool isEnabled = false;

    if (_selectedLevel != null) {
      final levelData = _tunisianEducationSystem[_selectedLevel];
      if (levelData.containsKey('subjects')) {
        subjects = List<String>.from(levelData['subjects']);
        isEnabled = true;
      } else if (levelData.containsKey('sections') &&
          _selectedSection != null) {
        final sectionData = levelData['sections'][_selectedSection];
        if (sectionData != null && sectionData.containsKey('subjects')) {
          subjects = List<String>.from(sectionData['subjects']);
          isEnabled = true;
        }
      }
    }

    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: 'Subject',
        border: const OutlineInputBorder(),
        filled: !isEnabled,
        fillColor: Colors.grey[200],
      ),
      value: _selectedSubject,
      items: subjects.map((String subject) {
        return DropdownMenuItem<String>(value: subject, child: Text(subject));
      }).toList(),
      onChanged: isEnabled
          ? (value) {
              setState(() {
                _selectedSubject = value;
              });
            }
          : null,
      validator: (value) =>
          isEnabled && value == null ? 'Please select a subject' : null,
    );
  }
}
