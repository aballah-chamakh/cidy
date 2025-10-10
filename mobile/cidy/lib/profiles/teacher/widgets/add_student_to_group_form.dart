import 'dart:convert';

import 'package:cidy/config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:cidy/authentication/login.dart';

class AddStudentToGroupForm extends StatefulWidget {
  final int groupId;
  final VoidCallback onStudentsAdded;

  const AddStudentToGroupForm({
    super.key,
    required this.groupId,
    required this.onStudentsAdded,
  });

  @override
  State<AddStudentToGroupForm> createState() => _AddStudentToGroupFormState();
}

class _AddStudentToGroupFormState extends State<AddStudentToGroupForm> {
  String? _selectedOption;
  bool _isLoading = false;
  Map<String, dynamic>? _groupData;

  // For existing students
  List<Map<String, dynamic>> _availableStudents = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  final Set<int> _selectedStudentIds = {};
  final TextEditingController _searchController = TextEditingController();
  bool _isLoadingStudents = false;

  // For new student creation
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String? _selectedGender;

  @override
  void initState() {
    super.initState();
    _fetchGroupData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _fetchGroupData() async {
    setState(() {
      _isLoading = true;
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
        '${Config.backendUrl}/api/teacher/groups/${widget.groupId}/',
      );

      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _groupData = json.decode(utf8.decode(response.bodyBytes));
          });
        }
      }
    } catch (e) {
      // Handle error
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchAvailableStudents() async {
    if (_groupData == null) return;

    setState(() {
      _isLoadingStudents = true;
    });

    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      if (token == null) return;

      final queryParams = {
        'level': _groupData!['level'],
        if (_groupData!['section'] != null && _groupData!['section'].isNotEmpty)
          'section': _groupData!['section'],
        'exclude_group': widget.groupId.toString(),
        if (_searchController.text.isNotEmpty) 'search': _searchController.text,
      };

      final url = Uri.parse(
        '${Config.backendUrl}/api/teacher/students/',
      ).replace(queryParameters: queryParams);

      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            _availableStudents = List<Map<String, dynamic>>.from(
              data['students'],
            );
            _filteredStudents = _availableStudents;
          });
        }
      }
    } catch (e) {
      // Handle error
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingStudents = false;
        });
      }
    }
  }

  Future<void> _addExistingStudents() async {
    if (_selectedStudentIds.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      if (token == null) return;

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
              content: Text('Élèves ajoutés avec succès'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
          widget.onStudentsAdded();
        }
      } else {
        _showError('Erreur lors de l\'ajout des élèves');
      }
    } catch (e) {
      _showError('Erreur de connexion');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _createAndAddStudent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      if (token == null) return;

      final url = Uri.parse(
        '${Config.backendUrl}/api/teacher/groups/${widget.groupId}/students/create/',
      );

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'fullname': _fullNameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'gender': _selectedGender!,
          'level': _groupData!['level'],
          if (_groupData!['section'] != null &&
              _groupData!['section'].isNotEmpty)
            'section': _groupData!['section'],
        }),
      );

      if (response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Élève créé et ajouté avec succès'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
          widget.onStudentsAdded();
        }
      } else {
        _showError('Erreur lors de la création de l\'élève');
      }
    } catch (e) {
      _showError('Erreur de connexion');
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
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Widget _buildInitialScreen() {
    return Container(
      width: MediaQuery.of(context).size.width * 0.9,
      constraints: const BoxConstraints(maxWidth: 500),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ajouter élève(s)',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const Divider(height: 20),

          // Content
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Column(
              children: [
                Icon(
                  Icons.person_add,
                  size: 60,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Choisissez entre ajouter des élèves existants ou créer un nouvel élève puis l\'ajouter',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: _selectedOption,
                  decoration: InputDecoration(
                    labelText: 'Option *',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'existing',
                      child: Text('Ajouter des élèves existants'),
                    ),
                    DropdownMenuItem(
                      value: 'create',
                      child: Text('Créer un nouvel élève puis l\'ajouter'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedOption = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez sélectionner une option';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),

          // Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: _selectedOption != null ? _handleNext : null,
                child: const Text('Suivant'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleNext() {
    if (_selectedOption == 'existing') {
      _fetchAvailableStudents();
    }
    setState(() {});
  }

  Widget _buildExistingStudentsScreen() {
    if (_isLoadingStudents) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_availableStudents.isEmpty) {
      return _buildNoStudentsMessage();
    }

    return Container(
      width: MediaQuery.of(context).size.width * 0.9,
      height: MediaQuery.of(context).size.height * 0.8,
      constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ajouter élèves existants',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const Divider(height: 20),

          // Search
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Rechercher par nom...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30.0),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey[200],
            ),
            onChanged: (value) {
              setState(() {
                if (value.isEmpty) {
                  _filteredStudents = _availableStudents;
                } else {
                  _filteredStudents = _availableStudents
                      .where(
                        (student) => student['fullname'].toLowerCase().contains(
                          value.toLowerCase(),
                        ),
                      )
                      .toList();
                }
              });
            },
          ),
          const SizedBox(height: 16),

          // Students count
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${_filteredStudents.length} Élèves',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Students list
          Expanded(
            child: ListView.builder(
              itemCount: _filteredStudents.length,
              itemBuilder: (context, index) {
                final student = _filteredStudents[index];
                final isSelected = _selectedStudentIds.contains(student['id']);

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: student['image'] != null
                          ? NetworkImage(
                              '${Config.backendUrl}${student['image']}',
                            )
                          : null,
                      backgroundColor: Colors.grey.shade300,
                      child: student['image'] == null
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    title: Text(student['fullname']),
                    trailing: Checkbox(
                      value: isSelected,
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            _selectedStudentIds.add(student['id']);
                          } else {
                            _selectedStudentIds.remove(student['id']);
                          }
                        });
                      },
                    ),
                  ),
                );
              },
            ),
          ),

          // Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedOption = null;
                    _selectedStudentIds.clear();
                  });
                },
                child: const Text('Retour'),
              ),
              ElevatedButton(
                onPressed: _selectedStudentIds.isNotEmpty && !_isLoading
                    ? _addExistingStudents
                    : null,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Ajouter'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoStudentsMessage() {
    final hasSection =
        _groupData?['section'] != null && _groupData!['section'].isNotEmpty;

    final message = hasSection
        ? 'Vous n\'avez aucun élève dans le même niveau et section que ce groupe'
        : 'Vous n\'avez aucun élève dans le même niveau que ce groupe';

    return Container(
      width: MediaQuery.of(context).size.width * 0.9,
      constraints: const BoxConstraints(maxWidth: 500),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Information',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const Divider(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: [
                Icon(Icons.info_outline, size: 60, color: Colors.orange),
                const SizedBox(height: 20),
                Text(
                  message,
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateStudentScreen() {
    return Container(
      width: MediaQuery.of(context).size.width * 0.9,
      height: MediaQuery.of(context).size.height * 0.8,
      constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Créer un nouvel élève',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(height: 20),

            // Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Profile image placeholder
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey.shade300,
                      ),
                      child: const Icon(
                        Icons.person,
                        size: 50,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Full name
                    TextFormField(
                      controller: _fullNameController,
                      decoration: InputDecoration(
                        labelText: 'Nom complet *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Le nom complet est requis';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Phone number
                    TextFormField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: 'Numéro de téléphone *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(8),
                      ],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Le numéro de téléphone est requis';
                        }
                        if (value.length != 8) {
                          return 'Le numéro doit contenir exactement 8 chiffres';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Gender
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Genre *',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Row(
                          children: [
                            Radio<String>(
                              value: 'M',
                              groupValue: _selectedGender,
                              onChanged: (value) {
                                setState(() {
                                  _selectedGender = value;
                                });
                              },
                            ),
                            const Text('Masculin'),
                            Radio<String>(
                              value: 'F',
                              groupValue: _selectedGender,
                              onChanged: (value) {
                                setState(() {
                                  _selectedGender = value;
                                });
                              },
                            ),
                            const Text('Féminin'),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedOption = null;
                    });
                  },
                  child: const Text('Retour'),
                ),
                ElevatedButton(
                  onPressed: !_isLoading ? _createAndAddStudent : null,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Ajouter'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _groupData == null) {
      return const Dialog(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Chargement...'),
            ],
          ),
        ),
      );
    }

    Widget content;
    if (_selectedOption == null) {
      content = _buildInitialScreen();
    } else if (_selectedOption == 'existing') {
      content = _buildExistingStudentsScreen();
    } else {
      content = _buildCreateStudentScreen();
    }

    return Dialog(
      child: Padding(padding: const EdgeInsets.all(15), child: content),
    );
  }
}
