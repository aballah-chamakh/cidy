import 'dart:convert';

import 'package:cidy/config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:cidy/authentication/login.dart';

class AddExistingStudentForm extends StatefulWidget {
  final int groupId;
  final VoidCallback onStudentsAdded;
  final VoidCallback? onBack;

  const AddExistingStudentForm({
    super.key,
    required this.groupId,
    required this.onStudentsAdded,
    this.onBack,
  });

  @override
  State<AddExistingStudentForm> createState() => _AddExistingStudentFormState();
}

class _AddExistingStudentFormState extends State<AddExistingStudentForm> {
  List<Map<String, dynamic>> _availableStudents = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  final Set<int> _selectedStudentIds = {};
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchAvailableStudents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAvailableStudents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');

      if (token == null) {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
        return;
      }

      final url = Uri.parse(
        '${Config.backendUrl}/api/teacher/students/available-for-group/${widget.groupId}/',
      );

      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as List;
        if (mounted) {
          setState(() {
            _availableStudents = data.cast<Map<String, dynamic>>();
            _filteredStudents = List.from(_availableStudents);
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Erreur lors du chargement des élèves disponibles.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Une erreur est survenue. Veuillez réessayer.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _filterStudents(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredStudents = List.from(_availableStudents);
      } else {
        _filteredStudents = _availableStudents
            .where(
              (student) => student['full_name']
                  .toString()
                  .toLowerCase()
                  .contains(query.toLowerCase()),
            )
            .toList();
      }
    });
  }

  Future<void> _addStudentsToGroup() async {
    if (_selectedStudentIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Veuillez sélectionner au moins un élève.',
            style: TextStyle(fontSize: 16.0),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');

      if (token == null) {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
        return;
      }

      final url = Uri.parse(
        '${Config.backendUrl}/api/teacher/groups/${widget.groupId}/students/add/',
      );

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'student_ids': _selectedStudentIds.toList()}),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Élèves ajoutés avec succès.',
                style: TextStyle(fontSize: 16.0),
              ),
            ),
          );
          widget.onStudentsAdded();
        }
      } else {
        final errorData = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _errorMessage =
              errorData['detail'] ?? 'Erreur lors de l\'ajout des élèves.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Une erreur est survenue. Veuillez réessayer.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _toggleStudentSelection(int studentId) {
    setState(() {
      if (_selectedStudentIds.contains(studentId)) {
        _selectedStudentIds.remove(studentId);
      } else {
        _selectedStudentIds.add(studentId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            const Divider(height: 16),
            _buildSearchField(),
            const SizedBox(height: 8),
            _buildStudentsHeader(),
            const SizedBox(height: 8),
            _buildStudentsList(),
            if (_errorMessage != null) _buildErrorMessage(),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Ajouter des élèves existants',
          style: TextStyle(
            fontSize: 18.0,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
        IconButton(
          icon: Icon(
            Icons.close,
            weight: 2.0,
            color: Theme.of(context).primaryColor,
          ),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }

  Widget _buildStudentsHeader() {
    int studentCount = _filteredStudents.length;
    return Text(
      '$studentCount Élèves',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Rechercher un élève...',
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Theme.of(context).primaryColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: Theme.of(context).primaryColor,
            width: 2,
          ),
        ),
      ),
      onChanged: _filterStudents,
    );
  }

  Widget _buildStudentsList() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_availableStudents.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16.0),
        child: Center(
          child: Text(
            'Aucun élève disponible à ajouter.',
            style: TextStyle(fontStyle: FontStyle.italic, fontSize: 16.0),
          ),
        ),
      );
    }

    if (_filteredStudents.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16.0),
        child: Center(
          child: Text(
            'Aucun résultat correspondant à votre recherche.',
            style: TextStyle(fontStyle: FontStyle.italic, fontSize: 16.0),
          ),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _filteredStudents.length,
        itemBuilder: (context, index) {
          final student = _filteredStudents[index];
          final studentId = student['id'] as int;
          final isSelected = _selectedStudentIds.contains(studentId);

          return Card(
            elevation: 1,
            margin: const EdgeInsets.symmetric(vertical: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.transparent,
                width: isSelected ? 1 : 0,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  // Profile image rounded
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: student['profile_image'] != null
                        ? NetworkImage(student['profile_image'])
                        : null,
                    child: student['profile_image'] == null
                        ? Text(
                            student['full_name'].toString()[0].toUpperCase(),
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  // Full name
                  Expanded(
                    child: Text(
                      student['full_name'].toString(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  // Checkbox
                  Checkbox(
                    value: isSelected,
                    activeColor: Theme.of(context).primaryColor,
                    onChanged: (bool? value) {
                      _toggleStudentSelection(studentId);
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        _errorMessage!,
        style: const TextStyle(color: Colors.red),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              style: TextButton.styleFrom(
                side: BorderSide(color: Theme.of(context).primaryColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _isSubmitting
                  ? null
                  : () {
                      if (widget.onBack != null) {
                        widget.onBack!();
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
              child: const Text('Retour', style: TextStyle(fontSize: 16.0)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedStudentIds.isEmpty
                    ? Colors.grey
                    : Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              onPressed: (_isSubmitting || _selectedStudentIds.isEmpty)
                  ? null
                  : _addStudentsToGroup,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Ajouter', style: TextStyle(fontSize: 16.0)),
            ),
          ),
        ],
      ),
    );
  }
}
