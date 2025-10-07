import 'dart:convert';
import 'package:cidy/constants.dart';
import 'package:cidy/config.dart';
import 'package:cidy/profiles/teacher/widgets/add_student_to_group_form.dart';
import 'package:cidy/profiles/teacher/widgets/edit_group_form.dart';
import 'package:cidy/profiles/teacher/widgets/teacher_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:cidy/authentication/login.dart';

class TeacherGroupDetailScreen extends StatefulWidget {
  final int groupId;

  const TeacherGroupDetailScreen({super.key, required this.groupId});

  @override
  State<TeacherGroupDetailScreen> createState() =>
      _TeacherGroupDetailScreenState();
}

class _TeacherGroupDetailScreenState extends State<TeacherGroupDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _groupDetail;
  String? _errorMessage;
  final Set<int> _selectedStudentIds = {};
  final TextEditingController _searchController = TextEditingController();
  String? _sortBy;

  final Map<String, String> _sortOptions = {
    'paid_amount_desc': 'Payé (décroissant)',
    'paid_amount_asc': 'Payé (croissant)',
    'unpaid_amount_desc': 'Impayé (décroissant)',
    'unpaid_amount_asc': 'Impayé (croissant)',
  };

  @override
  void initState() {
    super.initState();
    _fetchGroupDetails();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchGroupDetails({bool showLoading = true}) async {
    if (!mounted) return;
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

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

      final queryParams = {
        'search': _searchController.text,
        if (_sortBy != null) 'sort_by': _sortBy!,
      };

      final url = Uri.parse(
        '${Config.backendUrl}/api/teacher/groups/${widget.groupId}/',
      ).replace(queryParameters: queryParams);

      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _groupDetail = json.decode(utf8.decode(response.bodyBytes));
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to load group details.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'An error occurred: $e';
        });
      }
    } finally {
      if (mounted && showLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteGroup() async {
    if (!mounted) return;

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

      final url = Uri.parse('${Config.backendUrl}/api/teacher/groups/delete/');
      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'group_ids': [widget.groupId],
        }),
      );

      if (response.statusCode == 401) {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
        return;
      }

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Groupe supprimé avec succès.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(
            context,
          ).pop(); // Go back to the previous screen (the groups list)
        }
      } else {
        final errorData = json.decode(response.body);
        _showError(
          errorData['error'] ?? 'Erreur lors de la suppression du groupe.',
        );
      }
    } catch (e) {
      _showError('Une erreur est survenue: $e');
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

  @override
  Widget build(BuildContext context) {
    return TeacherLayout(
      title: _groupDetail != null
          ? 'Groupe : ${_groupDetail!['name']}'
          : 'Détails du groupe',
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(child: Text('Erreur : $_errorMessage'));
    }

    if (_groupDetail == null) {
      return const Center(child: Text('Groupe non trouvé.'));
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () => _fetchGroupDetails(showLoading: false),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              8.0,
              8.0,
              8.0,
              _selectedStudentIds.isNotEmpty ? 80.0 : 8.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildGroupDetailsCard(),
                const SizedBox(height: 16),
                _buildKpiCards(),
                const SizedBox(height: 16),
                _buildStudentListCard(),
              ],
            ),
          ),
        ),
        if (_selectedStudentIds.isNotEmpty) _buildStickyActionBar(),
      ],
    );
  }

  Widget _buildGroupDetailsCard() {
    final group = _groupDetail!;
    final bool hasSection =
        group['section'] != null && group['section'].isNotEmpty;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Détails du groupe',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                Row(
                  children: [
                    _buildSquareButton(Icons.edit, () {
                      _showEditGroupDialog();
                    }),
                    const SizedBox(width: 8),
                    _buildSquareButton(Icons.delete, () {
                      _showDeleteGroupConfirmationDialog();
                    }),
                  ],
                ),
              ],
            ),
            const Divider(height: 20),
            _buildDetailRow('Nom', group['name']),
            if (hasSection)
              _buildDetailRow(
                'Niveau & Section',
                '${group['level']} ${group['section']}',
              ),
            if (!hasSection) _buildDetailRow('Niveau', '${group['level']}'),
            _buildDetailRow('Matière', group['subject']),
            _buildDetailRow(
              'Jour et heure',
              '${weekDayEnglishToFrenchMap[group['week_day']]} de ${group['start_time']} à ${group['end_time']}  ${group['is_temporary_schedule'] ? '(Horaire temporaire)' : ''}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSquareButton(IconData icon, VoidCallback onPressed) {
    return Material(
      color: Colors.grey.shade200,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: Icon(icon, color: Theme.of(context).primaryColor),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }

  Widget _buildKpiCards() {
    final group = _groupDetail!;
    final students = group['students']['students'] as List;
    return Row(
      children: [
        Expanded(
          child: _buildKpiCard(
            group['total_paid'].toString(),
            'Payé',
            Colors.green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildKpiCard(
            group['total_unpaid'].toString(),
            'Non payé',
            Colors.red,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildKpiCard(
            students.length.toString(),
            'Élèves',
            Colors.blue.shade800,
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard(String value, String label, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentListCard() {
    final students = _groupDetail!['students']['students'] as List;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${students.length} Élève(s)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    _showAddStudentDialog();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    textStyle: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            _buildStudentFilters(),
            const SizedBox(height: 16),
            if (students.isEmpty)
              _buildNoStudentsUI()
            else
              _buildStudentListView(students),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentFilters() {
    return Column(
      children: [
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
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: (value) => _fetchGroupDetails(showLoading: false),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _sortBy,
          decoration: InputDecoration(
            labelText: 'Trier par',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
          ),
          items: _sortOptions.entries
              .map(
                (entry) => DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() {
              _sortBy = value;
            });
            _fetchGroupDetails(showLoading: false);
          },
        ),
      ],
    );
  }

  Widget _buildNoStudentsUI() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      alignment: Alignment.center,
      child: Text(
        'Aucun élève dans ce groupe.',
        style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
      ),
    );
  }

  Widget _buildStudentListView(List students) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: students.length,
      itemBuilder: (context, index) {
        return _buildStudentCard(students[index]);
      },
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    final isSelected = _selectedStudentIds.contains(student['id']);
    final imageUrl = '${Config.backendUrl}${student['image']}';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: isSelected
            ? BorderSide(color: Theme.of(context).primaryColor, width: 1.5)
            : BorderSide(color: Colors.grey.shade300),
      ),
      child: InkWell(
        onTap: () {
          // TODO: Navigate to student detail screen
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
          child: Row(
            children: [
              Checkbox(
                value: isSelected,
                onChanged: (bool? value) {
                  setState(() {
                    if (value == true) {
                      _selectedStudentIds.add(student['id'] as int);
                    } else {
                      _selectedStudentIds.remove(student['id']);
                    }
                  });
                },
              ),
              CircleAvatar(
                radius: 25,
                backgroundImage: NetworkImage(imageUrl),
                onBackgroundImageError: (_, __) {},
                backgroundColor: Colors.grey.shade300,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  student['fullname'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${student['paid_amount']} Payé',
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${student['unpaid_amount']} Non payé',
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditGroupDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return EditGroupForm(
          group: _groupDetail!,
          onGroupUpdated: () {
            Navigator.of(context).pop();
            _fetchGroupDetails();
          },
        );
      },
    );
  }

  void _showAddStudentDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: AddStudentToGroupForm(
            groupId: widget.groupId,
            onStudentsAdded: () {
              Navigator.of(context).pop();
              _fetchGroupDetails();
            },
          ),
        );
      },
    );
  }

  Future<void> _showDeleteGroupConfirmationDialog() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Text(
                  'Confirmer la suppression',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Content
                Column(
                  children: [
                    Icon(Icons.delete_outline, size: 60, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'Êtes-vous sûr de vouloir supprimer le groupe : ${_groupDetail!['name']} ?',
                      style: const TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                const SizedBox(height: 30),

                // Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Non'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Oui'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed == true) {
      await _deleteGroup();
    }
  }

  Widget _buildStickyActionBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Action groupée',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'remove',
                    child: Text('Retirer du groupe'),
                  ),
                  DropdownMenuItem(
                    value: 'mark_attendance',
                    child: Text('Marquer présence'),
                  ),
                  DropdownMenuItem(
                    value: 'unmark_attendance',
                    child: Text('Annuler présence'),
                  ),
                  DropdownMenuItem(
                    value: 'mark_payment',
                    child: Text('Marquer paiement'),
                  ),
                  DropdownMenuItem(
                    value: 'unmark_payment',
                    child: Text('Annuler paiement'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    _handleGroupAction(value);
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedStudentIds.clear();
                });
              },
              child: const Text('Annuler'),
            ),
          ],
        ),
      ),
    );
  }

  void _handleGroupAction(String action) {
    switch (action) {
      case 'remove':
        _showRemoveStudentsDialog();
        break;
      case 'mark_attendance':
        _showMarkAttendanceDialog();
        break;
      case 'unmark_attendance':
        _showUnmarkAttendanceDialog();
        break;
      case 'mark_payment':
        _showMarkPaymentDialog();
        break;
      case 'unmark_payment':
        _showUnmarkPaymentDialog();
        break;
    }
  }

  void _showRemoveStudentsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Confirmer la suppression (${_selectedStudentIds.length})',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Icon(Icons.person_remove, size: 60, color: Colors.orange),
                const SizedBox(height: 16),
                Text(
                  'Êtes-vous sûr de vouloir retirer les ${_selectedStudentIds.length} élève(s) sélectionné(s) du groupe ?',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Non'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _removeStudentsFromGroup();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Oui'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMarkAttendanceDialog() {
    DateTime selectedDate = DateTime.now();
    TimeOfDay? selectedStartTime;
    TimeOfDay? selectedEndTime;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Marquer présence (${_selectedStudentIds.length})',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Icon(
                      Icons.check_circle_outline,
                      size: 60,
                      color: Colors.green,
                    ),
                    const SizedBox(height: 20),

                    // Date picker
                    ListTile(
                      title: const Text('Date'),
                      subtitle: Text(
                        '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                    ),

                    // Start time picker
                    ListTile(
                      title: const Text('Heure de début'),
                      subtitle: Text(
                        selectedStartTime != null
                            ? selectedStartTime!.format(context)
                            : 'Sélectionner l\'heure',
                      ),
                      trailing: const Icon(Icons.access_time),
                      onTap: () async {
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: selectedStartTime ?? TimeOfDay.now(),
                        );
                        if (picked != null) {
                          setState(() {
                            selectedStartTime = picked;
                          });
                        }
                      },
                    ),

                    // End time picker
                    ListTile(
                      title: const Text('Heure de fin'),
                      subtitle: Text(
                        selectedEndTime != null
                            ? selectedEndTime!.format(context)
                            : 'Sélectionner l\'heure',
                      ),
                      trailing: const Icon(Icons.access_time),
                      onTap: () async {
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: selectedEndTime ?? TimeOfDay.now(),
                        );
                        if (picked != null) {
                          setState(() {
                            selectedEndTime = picked;
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Annuler'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed:
                                selectedStartTime != null &&
                                    selectedEndTime != null
                                ? () {
                                    Navigator.of(context).pop();
                                    _markAttendance(
                                      selectedDate,
                                      selectedStartTime!,
                                      selectedEndTime!,
                                    );
                                  }
                                : null,
                            child: const Text('Marquer'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showUnmarkAttendanceDialog() {
    int numberOfClasses = 1;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Annuler présence (${_selectedStudentIds.length})',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Icon(Icons.cancel_outlined, size: 60, color: Colors.orange),
                    const SizedBox(height: 20),

                    TextFormField(
                      initialValue: numberOfClasses.toString(),
                      decoration: const InputDecoration(
                        labelText: 'Nombre de cours à annuler',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        final parsed = int.tryParse(value);
                        if (parsed != null && parsed > 0) {
                          numberOfClasses = parsed;
                        }
                      },
                    ),

                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Annuler'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _unmarkAttendance(numberOfClasses);
                            },
                            child: const Text('Annuler'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showMarkPaymentDialog() {
    int numberOfClasses = 1;
    DateTime selectedDateTime = DateTime.now();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Marquer paiement (${_selectedStudentIds.length})',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Icon(Icons.payment, size: 60, color: Colors.green),
                    const SizedBox(height: 20),

                    TextFormField(
                      initialValue: numberOfClasses.toString(),
                      decoration: const InputDecoration(
                        labelText: 'Nombre de cours à marquer comme payés',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        final parsed = int.tryParse(value);
                        if (parsed != null && parsed > 0) {
                          numberOfClasses = parsed;
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    ListTile(
                      title: const Text('Date et heure'),
                      subtitle: Text(
                        '${selectedDateTime.day}/${selectedDateTime.month}/${selectedDateTime.year} ${selectedDateTime.hour}:${selectedDateTime.minute.toString().padLeft(2, '0')}',
                      ),
                      trailing: const Icon(Icons.date_range),
                      onTap: () async {
                        final DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: selectedDateTime,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (pickedDate != null) {
                          final TimeOfDay? pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(
                              selectedDateTime,
                            ),
                          );
                          if (pickedTime != null) {
                            setState(() {
                              selectedDateTime = DateTime(
                                pickedDate.year,
                                pickedDate.month,
                                pickedDate.day,
                                pickedTime.hour,
                                pickedTime.minute,
                              );
                            });
                          }
                        }
                      },
                    ),

                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Annuler'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _markPayment(numberOfClasses, selectedDateTime);
                            },
                            child: const Text('Marquer'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showUnmarkPaymentDialog() {
    int numberOfClasses = 1;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Annuler paiement (${_selectedStudentIds.length})',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Icon(Icons.money_off, size: 60, color: Colors.red),
                    const SizedBox(height: 20),

                    TextFormField(
                      initialValue: numberOfClasses.toString(),
                      decoration: const InputDecoration(
                        labelText: 'Nombre de cours à annuler le paiement',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        final parsed = int.tryParse(value);
                        if (parsed != null && parsed > 0) {
                          numberOfClasses = parsed;
                        }
                      },
                    ),

                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Annuler'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _unmarkPayment(numberOfClasses);
                            },
                            child: const Text('Annuler'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _removeStudentsFromGroup() async {
    setState(() {
      _isLoading = true;
    });

    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      if (token == null) return;

      // Using the delete students endpoint with group context
      final url = Uri.parse(
        '${Config.backendUrl}/api/teacher/students/delete/',
      );

      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'student_ids': _selectedStudentIds.toList(),
          'group_id':
              widget.groupId, // Context for removing from specific group
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          _selectedStudentIds.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Élèves retirés avec succès'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchGroupDetails(showLoading: false);
      } else {
        _showError('Erreur lors de la suppression des élèves');
      }
    } catch (e) {
      _showError('Erreur de connexion');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _markAttendance(
    DateTime date,
    TimeOfDay startTime,
    TimeOfDay endTime,
  ) async {
    setState(() {
      _isLoading = true;
    });

    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      if (token == null) return;

      final url = Uri.parse(
        '${Config.backendUrl}/api/teacher/groups/${widget.groupId}/students/mark_attendance/',
      );

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'student_ids': _selectedStudentIds.toList(),
          'date':
              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
          'start_time':
              '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
          'end_time':
              '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          _selectedStudentIds.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Présence marquée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchGroupDetails(showLoading: false);
      } else {
        _showError('Erreur lors du marquage de présence');
      }
    } catch (e) {
      _showError('Erreur de connexion');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _unmarkAttendance(int numberOfClasses) async {
    setState(() {
      _isLoading = true;
    });

    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      if (token == null) return;

      final url = Uri.parse(
        '${Config.backendUrl}/api/teacher/groups/${widget.groupId}/students/unmark_attendance/',
      );

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'student_ids': _selectedStudentIds.toList(),
          'number_of_classes': numberOfClasses,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          _selectedStudentIds.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Présence annulée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchGroupDetails(showLoading: false);
      } else {
        _showError('Erreur lors de l\'annulation de présence');
      }
    } catch (e) {
      _showError('Erreur de connexion');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _markPayment(int numberOfClasses, DateTime dateTime) async {
    setState(() {
      _isLoading = true;
    });

    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      if (token == null) return;

      final url = Uri.parse(
        '${Config.backendUrl}/api/teacher/groups/${widget.groupId}/students/mark_payment/',
      );

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'student_ids': _selectedStudentIds.toList(),
          'number_of_classes': numberOfClasses,
          'datetime': dateTime.toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          _selectedStudentIds.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paiement marqué avec succès'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchGroupDetails(showLoading: false);
      } else {
        _showError('Erreur lors du marquage de paiement');
      }
    } catch (e) {
      _showError('Erreur de connexion');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _unmarkPayment(int numberOfClasses) async {
    setState(() {
      _isLoading = true;
    });

    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      if (token == null) return;

      final url = Uri.parse(
        '${Config.backendUrl}/api/teacher/groups/${widget.groupId}/students/unmark_payment/',
      );

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'student_ids': _selectedStudentIds.toList(),
          'number_of_classes': numberOfClasses,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          _selectedStudentIds.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paiement annulé avec succès'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchGroupDetails(showLoading: false);
      } else {
        _showError('Erreur lors de l\'annulation de paiement');
      }
    } catch (e) {
      _showError('Erreur de connexion');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
