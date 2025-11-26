import 'dart:convert';
import 'package:cidy/app_styles.dart';
import 'package:cidy/app_tools.dart';
import 'package:cidy/constants.dart';
import 'package:cidy/config.dart';
import 'package:cidy/profiles/teacher/widgets/teacher_group_detail_screen/add_student_popup.dart';
import 'package:cidy/profiles/teacher/widgets/teacher_group_detail_screen/delete_group_popup.dart';
import 'package:cidy/profiles/teacher/widgets/teacher_group_detail_screen/edit_group_popup.dart';
import 'package:cidy/profiles/teacher/widgets/teacher_group_detail_screen/unmark_payment_popup.dart';
import 'package:cidy/profiles/teacher/widgets/teacher_layout.dart';
import 'package:cidy/profiles/teacher/screens/teacher_student_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:cidy/authentication/login.dart';

import '../widgets/teacher_group_detail_screen/mark_attendance_and_payment_popup.dart';
import '../widgets/teacher_group_detail_screen/mark_attendance_popup.dart';
import '../widgets/teacher_group_detail_screen/mark_payment_popup.dart';
import '../widgets/teacher_group_detail_screen/remove_students_popup.dart';
import '../widgets/teacher_group_detail_screen/unmark_attendance_popup.dart';
import '../widgets/teacher_group_detail_screen/action_result_popup.dart';
import '../widgets/teacher_group_detail_screen/mark_absence_popup.dart';
import '../widgets/teacher_group_detail_screen/unmark_absence_popup.dart';

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
  String? _sortBy = '';
  final ScrollController _studentListScrollController = ScrollController();
  final ScrollController _pageScrollController = ScrollController();
  bool _isStudentListAtEdge = true;
  final GlobalKey _stickyActionBarKey = GlobalKey();
  double _stickyActionBarHeight = 0;

  final Map<String, String> _sortOptions = {
    '': 'Par défaut',
    'paid_amount_desc': 'Payé (décroissant)',
    'paid_amount_asc': 'Payé (croissant)',
    'unpaid_amount_desc': 'Non payé (décroissant)',
    'unpaid_amount_asc': 'Non payé (croissant)',
  };

  @override
  void initState() {
    super.initState();
    _fetchGroupDetails();
    _studentListScrollController.addListener(_onStudentListScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _studentListScrollController.removeListener(_onStudentListScroll);
    _studentListScrollController.dispose();
    _pageScrollController.dispose();
    super.dispose();
  }

  void _onStudentListScroll() {
    if (!_studentListScrollController.hasClients) return;
    final atEdge = _studentListScrollController.position.atEdge;
    if (atEdge != _isStudentListAtEdge) {
      setState(() {
        _isStudentListAtEdge = atEdge;
      });
    }
  }

  void _propagateStudentListScroll(double delta) {
    if (!_pageScrollController.hasClients || delta.abs() < 0.01) return;
    final position = _pageScrollController.position;
    final double target = (position.pixels + delta)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();

    if (target != position.pixels) {
      position.jumpTo(target);
    }
  }

  void _updateStickyActionBarHeight() {
    if (!mounted) return;
    final context = _stickyActionBarKey.currentContext;
    if (context == null) return;
    final renderBox = context.findRenderObject();
    if (renderBox is! RenderBox) return;
    final newHeight = renderBox.size.height;
    if (newHeight <= 0) return;
    if ((newHeight - _stickyActionBarHeight).abs() > 0.5) {
      setState(() {
        _stickyActionBarHeight = newHeight;
      });
    }
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
      if (!mounted) return;
      if (token == null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
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
      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _groupDetail = json.decode(utf8.decode(response.bodyBytes));
        });
      } else if (response.statusCode == 401) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      } else {
        setState(() {
          _errorMessage = 'Failed to load group details.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'An error occurred: $e';
      });
    } finally {
      if (mounted && showLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteGroup() async {
    setState(() {
      _isLoading = true;
    });

    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      if (!mounted) return;

      if (token == null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
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
      if (!mounted) return;

      if (response.statusCode == 200) {
        // i started by pushing a success snackbar in the snackbar queue because he
        // need a mounted context
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Groupe supprimé avec succès.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else if (response.statusCode == 401) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      } else {
        _showError("erreur du serveur (500)");
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      _showError("erreur du serveur (500)");
      Navigator.pop(context);
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
      SnackBar(
        content: Text(message, style: TextStyle(fontSize: 16)),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(fontSize: 16)),
        backgroundColor: Colors.green,
      ),
    );
  }

  void clearFiltersAndSelectedStudents() {
    setState(() {
      _searchController.text = '';
      _sortBy = '';
      _selectedStudentIds.clear();
    });
  }

  bool _areAllStudentsSelected(List students) {
    if (students.isEmpty) {
      return false;
    }
    return students.every(
      (student) => _selectedStudentIds.contains(student['id'] as int),
    );
  }

  void _toggleSelectAllStudents(List students) {
    final allSelected = _areAllStudentsSelected(students);
    setState(() {
      if (allSelected) {
        _selectedStudentIds.clear();
      } else {
        _selectedStudentIds
          ..clear()
          ..addAll(students.map<int>((student) => student['id'] as int));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return TeacherLayout(
      title: _groupDetail != null ? 'Groupe : ${_groupDetail!['name']}' : '...',
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: primaryColor),
      );
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
          onRefresh: () async {
            if (!mounted) return;
            await _fetchGroupDetails(showLoading: false);
          },
          child: SingleChildScrollView(
            controller: _pageScrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildGroupDetailsCard(),
                const SizedBox(height: 10),
                _buildKpiCards(),
                const SizedBox(height: 10),
                _buildStudentListCard(),
                if (_selectedStudentIds.isNotEmpty)
                  SizedBox(
                    height: _stickyActionBarHeight > 0
                        ? _stickyActionBarHeight
                        : 160,
                  ), // Spacer for sticky bar
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
      color: Color(0xFFF5F7FA),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
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
                    color: primaryColor,
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
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.grey.shade400, // 👈 border color here
              width: 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: primaryColor),
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
            formatToK((group['total_paid'] ?? 0)),
            'Payé',
            Colors.green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildKpiCard(
            formatToK((group['total_unpaid'] ?? 0)),
            'Non payé',
            Colors.red,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildKpiCard(
            students.length.toString(),
            'Étudiants',
            Colors.blue.shade800,
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard(String value, String label, Color color) {
    return Card(
      color: Color(0xFFF5F7FA),
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
            Text(label, style: TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentListCard() {
    final students = _groupDetail!['students']['students'] as List;
    return Card(
      color: Color(0xFFF5F7FA),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${students.length} Étudiant(s)',
                  style: TextStyle(
                    fontSize: mediumFontSize,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
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
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            _buildStudentFilters(students),
            if (students.isEmpty)
              _buildNoStudentsUI()
            else
              _buildStudentListView(students),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentFilters(List students) {
    final bool allSelected = _areAllStudentsSelected(students);
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
            fillColor: Colors.white,
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
            filled: true,
            fillColor: Colors.white,
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
        Row(
          mainAxisAlignment: MainAxisAlignment.start,

          children: [
            Transform.scale(
              scale: 1.2,
              child: Checkbox(
                activeColor: primaryColor, // color when checked
                checkColor: Colors.white,
                value: allSelected,
                onChanged: students.isEmpty
                    ? null
                    : (_) => _toggleSelectAllStudents(students),
              ),
            ),
            Text(
              allSelected ? 'Désélectionner tous' : 'Sélectionner tous',
              style: const TextStyle(fontSize: mediumFontSize),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNoStudentsUI() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      alignment: Alignment.center,
      child: Text(
        _searchController.text.isNotEmpty
            ? "Aucun étudiant ne correspond à votre recherche."
            : 'Aucun étudiant dans ce groupe.',
        style: TextStyle(fontSize: mediumFontSize),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildStudentListView(List students) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Container(
      constraints: BoxConstraints(
        maxHeight: 0.7 * screenHeight, // 👈 50% of the screen height
      ),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.axis != Axis.vertical) return false;

          if (notification is OverscrollNotification) {
            _propagateStudentListScroll(notification.overscroll);
          } else if (notification is ScrollUpdateNotification &&
              notification.metrics.atEdge &&
              (notification.scrollDelta ?? 0.0) != 0.0) {
            _propagateStudentListScroll(notification.scrollDelta!);
          }
          return false;
        },
        child: Scrollbar(
          controller: _studentListScrollController,
          thumbVisibility: true,
          child: ListView.builder(
            controller: _studentListScrollController,
            shrinkWrap: true,
            physics: const ClampingScrollPhysics(),
            itemCount: students.length,
            itemBuilder: (context, index) {
              return _buildStudentCard(students[index]);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    final isSelected = _selectedStudentIds.contains(student['id']);
    final imageUrl = '${Config.backendUrl}${student['image']}';

    return Card(
      color: Color(0xFFF5F7FA),
      margin: EdgeInsets.symmetric(vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: isSelected
            ? const BorderSide(color: primaryColor, width: 1.5)
            : BorderSide(color: Colors.grey.shade300),
      ),
      child: InkWell(
        onTap: () async {
          final rawId = student['id'];
          final studentId = rawId is int ? rawId : int.tryParse('$rawId');
          if (studentId == null) return;
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TeacherStudentDetailScreen(studentId: studentId),
            ),
          );
          if (!mounted) return;
          if (result == true) {
            _fetchGroupDetails();
          }
        },
        onLongPress: () {
          setState(() {
            if (isSelected) {
              _selectedStudentIds.remove(student['id']);
            } else {
              _selectedStudentIds.add(student['id'] as int);
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
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
                  style: const TextStyle(fontSize: mediumFontSize),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${formatToK(student['paid_amount'])} DT',
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${formatToK(student['unpaid_amount'])} DT',
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 16,
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
        return EditGroupPopup(
          group: _groupDetail!,
          onGroupUpdated: () {
            if (mounted) {
              _showSuccess('Groupe modifié avec succès');
              Navigator.of(context).pop();
              clearFiltersAndSelectedStudents();
              _fetchGroupDetails();
            }
          },
          onServerError: (errorMessage) {
            if (mounted) {
              _showError(errorMessage);
              Navigator.of(context).pop();
              clearFiltersAndSelectedStudents();
              _fetchGroupDetails();
            }
          },
        );
      },
    );
  }

  void _showAddStudentDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AddStudentPopup(
          groupId: widget.groupId,
          onStudentsAdded:
              ({
                String message = 'L’étudiant a été créé et ajouté avec succès.',
              }) {
                if (mounted) {
                  _showSuccess(message);
                  Navigator.of(context).pop();
                  clearFiltersAndSelectedStudents();
                  _fetchGroupDetails();
                }
              },
          onServerError: () {
            if (mounted) {
              _showError('Erreur du serveur (500)');
              Navigator.of(context).pop();
              clearFiltersAndSelectedStudents();
              _fetchGroupDetails();
            } else {
              print("onServerError Context is not mounted");
            }
          },
        );
      },
    );
  }

  Future<void> _showDeleteGroupConfirmationDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (BuildContext _) {
        return DeleteGroupPopup(
          groupName: _groupDetail!['name'],
          onDelete: _deleteGroup,
        );
      },
    );
    if (!mounted) return;
  }

  Widget _buildStickyActionBar() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateStickyActionBarHeight();
    });
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        key: _stickyActionBarKey,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(10),
            topRight: Radius.circular(10),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              hint: const Text(
                'Action groupée',
                style: TextStyle(fontSize: mediumFontSize),
              ),
              decoration: InputDecoration(
                labelText: 'Action groupée',
                labelStyle: const TextStyle(color: primaryColor),
                border: OutlineInputBorder(),
                contentPadding: inputContentPadding,
              ),
              items: const [
                DropdownMenuItem(
                  value: 'mark_attendance_and_payment',
                  child: Text(
                    'Marquer la présence et le paiement',
                    style: TextStyle(fontSize: mediumFontSize),
                  ),
                ),
                DropdownMenuItem(
                  value: 'mark_attendance',
                  child: Text(
                    'Marquer la présence',
                    style: TextStyle(fontSize: mediumFontSize),
                  ),
                ),
                DropdownMenuItem(
                  value: 'unmark_attendance',
                  child: Text(
                    'Annuler la présence',
                    style: TextStyle(fontSize: mediumFontSize),
                  ),
                ),
                DropdownMenuItem(
                  value: 'mark_absence',
                  child: Text(
                    "Marquer l'absence",
                    style: TextStyle(fontSize: mediumFontSize),
                  ),
                ),
                DropdownMenuItem(
                  value: 'unmark_absence',
                  child: Text(
                    "Annuler l'absence",
                    style: TextStyle(fontSize: mediumFontSize),
                  ),
                ),
                DropdownMenuItem(
                  value: 'mark_payment',
                  child: Text(
                    'Marquer le paiement',
                    style: TextStyle(fontSize: mediumFontSize),
                  ),
                ),
                DropdownMenuItem(
                  value: 'unmark_payment',
                  child: Text(
                    'Annuler le paiement',
                    style: TextStyle(fontSize: mediumFontSize),
                  ),
                ),
                DropdownMenuItem(
                  value: 'remove',
                  child: Text(
                    'Retirer du groupe',
                    style: TextStyle(fontSize: mediumFontSize),
                  ),
                ),
              ],
              onChanged: (value) {
                if (mounted && value != null) {
                  _handleGroupAction(value);
                }
              },
            ),

            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: primaryButtonStyle,
                onPressed: () {
                  if (!mounted) return;
                  setState(() {
                    _selectedStudentIds.clear();
                  });
                },
                child: Text(
                  'Annuler (${_selectedStudentIds.length})',
                  style: const TextStyle(fontSize: mediumFontSize),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleGroupAction(String action) {
    switch (action) {
      case 'mark_attendance_and_payment':
        _showMarkAttendanceAndPaymentDialog();
        break;
      case 'remove':
        _showRemoveStudentsDialog();
        break;
      case 'mark_attendance':
        _showMarkAttendanceDialog();
        break;
      case 'unmark_attendance':
        _showUnmarkAttendanceDialog();
        break;
      case 'mark_absence':
        _showMarkAbsenceDialog();
        break;
      case 'unmark_absence':
        _showUnmarkAbsenceDialog();
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
        return RemoveStudentsPopup(
          studentCount: _selectedStudentIds.length,
          studentIds: _selectedStudentIds,
          groupId: widget.groupId,
          onSuccess: () {
            if (!mounted) return;
            Navigator.of(context).pop();
            _showSuccess('Étudiants retirés avec succès');
            clearFiltersAndSelectedStudents();
            _fetchGroupDetails(showLoading: false);
          },
          onError: () {
            if (!mounted) return;
            Navigator.of(context).pop();
            _showError('Erreur du serveur (500)');
            clearFiltersAndSelectedStudents();
            _fetchGroupDetails(showLoading: false);
          },
        );
      },
    );
  }

  void _showMarkAttendanceAndPaymentDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return MarkAttendanceAndPaymentPopup(
          studentCount: _selectedStudentIds.length,
          groupId: _groupDetail!['id'],
          studentIds: _selectedStudentIds,
          groupStartTime: _groupDetail!['start_time'],
          groupEndTime: _groupDetail!['end_time'],
          weekDay: _groupDetail!['week_day'],
          onSuccess: () {
            if (!mounted) return;
            Navigator.of(context).pop();
            _showSuccess('Présence(s) et paiement(s) marqués avec succès');
            clearFiltersAndSelectedStudents();
            _fetchGroupDetails(showLoading: true);
          },
          onError: () {
            if (!mounted) return;
            Navigator.of(context).pop();
            _showError('Erreur du serveur (500)');
            clearFiltersAndSelectedStudents();
            _fetchGroupDetails(showLoading: true);
          },
          onOverlapDetected: (int studentsMarkedCount, List overlappingStudents) {
            if (!mounted) return;
            Navigator.of(context).pop();
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return ActionResultPopup(
                  type: 'time_conflict',
                  successKpi: {
                    'value': studentsMarkedCount,
                    'label': "Étudiant(s) marqué(s) comme présents et payés",
                  },
                  failedKpi: {
                    'value': overlappingStudents.length,
                    'label': "Étudiant(s) non marqués comme présents et payés",
                  },
                  failedListTitle: "Étudiants non marqués présents et payés",
                  failedListDescription:
                      "Ces étudiants n’ont pas été marqués comme présents et payés en raison d’un conflit d’horaire avec une autre séance.",
                  failedList: overlappingStudents,
                  onClose: () {
                    if (!mounted) return;
                    Navigator.of(context).pop();
                    clearFiltersAndSelectedStudents();
                    _fetchGroupDetails(showLoading: true);
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  void _showMarkAttendanceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return MarkAttendancePopup(
          studentCount: _selectedStudentIds.length,
          groupId: _groupDetail!['id'],
          studentIds: _selectedStudentIds,
          groupStartTime: _groupDetail!['start_time'],
          groupEndTime: _groupDetail!['end_time'],
          weekDay: _groupDetail!['week_day'],
          onSuccess: () {
            if (!mounted) return;
            Navigator.of(context).pop();
            _showSuccess('Présence(s) marquée(s) avec succès');
            clearFiltersAndSelectedStudents();
            _fetchGroupDetails(showLoading: true);
          },
          onError: () {
            if (!mounted) return;
            Navigator.of(context).pop();
            _showError('Erreur du serveur (500)');
            clearFiltersAndSelectedStudents();
            _fetchGroupDetails(showLoading: true);
          },
          onOverlapDetected: (int studentsMarkedCount, List overlappingStudents) {
            if (!mounted) return;
            Navigator.of(context).pop();
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return ActionResultPopup(
                  type: 'time_conflict',
                  successKpi: {
                    'value': studentsMarkedCount,
                    'label': "Étudiant(s) marqué(s) comme présent(s)",
                  },
                  failedKpi: {
                    'value': overlappingStudents.length,
                    'label': "Étudiant(s) non marqués comme présent(s)",
                  },
                  failedListTitle: "Les étudiants non marqués présents",
                  failedListDescription:
                      "Ces étudiants n’ont pas été marqués comme présents en raison d’un conflit d’horaire avec une autre séance.",
                  failedList: overlappingStudents,
                  onClose: () {
                    if (!mounted) return;
                    Navigator.of(context).pop();
                    clearFiltersAndSelectedStudents();
                    _fetchGroupDetails(showLoading: true);
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  void _showUnmarkAttendanceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return UnmarkAttendancePopup(
          groupId: _groupDetail!['id'],
          studentCount: _selectedStudentIds.length,
          studentIds: _selectedStudentIds,
          onSuccess:
              ({
                required int requestedClasses,
                required int fullyUnmarkedCount,
                required List studentsWithMissingClasses,
              }) {
                if (!mounted) return;
                Navigator.of(context).pop();

                if (studentsWithMissingClasses.isEmpty) {
                  _showSuccess('Présence(s) annulée(s) avec succès');
                  clearFiltersAndSelectedStudents();
                  _fetchGroupDetails(showLoading: true);
                } else {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return ActionResultPopup(
                        type: 'missing_classes',
                        successKpi: {
                          'value': fullyUnmarkedCount,
                          'label':
                              "Étudiant(s) – présence(s) complètement annulée(s)",
                        },
                        failedKpi: {
                          'value': studentsWithMissingClasses.length,
                          'label':
                              "Étudiant(s) - présence(s) incomplètement annulée(s)",
                        },
                        failedListTitle:
                            "Étudiants avec des séances marquées présentes manquantes",
                        failedListDescription:
                            "Ces étudiants n’avaient pas suffisamment de séances marquées comme présentes pour annuler les $requestedClasses prévues.",
                        failedList: studentsWithMissingClasses,

                        onClose: () {
                          if (!mounted) return;
                          Navigator.of(context).pop();
                          clearFiltersAndSelectedStudents();
                          _fetchGroupDetails(showLoading: true);
                        },
                      );
                    },
                  );
                }
              },
          onError: () {
            if (!mounted) return;
            Navigator.of(context).pop();
            _showError('Erreur du serveur (500)');
            clearFiltersAndSelectedStudents();
            _fetchGroupDetails(showLoading: true);
          },
        );
      },
    );
  }

  void _showMarkAbsenceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return MarkAbsencePopup(
          studentCount: _selectedStudentIds.length,
          groupId: _groupDetail!['id'],
          studentIds: _selectedStudentIds,
          groupStartTime: _groupDetail!['start_time'],
          groupEndTime: _groupDetail!['end_time'],
          weekDay: _groupDetail!['week_day'],
          onSuccess: () {
            if (!mounted) return;
            Navigator.of(context).pop();
            _showSuccess('Absence(s) marquée(s) avec succès');
            clearFiltersAndSelectedStudents();
            _fetchGroupDetails(showLoading: true);
          },
          onError: () {
            if (!mounted) return;
            Navigator.of(context).pop();
            _showError('Erreur du serveur (500)');
            clearFiltersAndSelectedStudents();
            _fetchGroupDetails(showLoading: true);
          },
          onOverlapDetected: (int studentsMarkedCount, List overlappingStudents) {
            if (!mounted) return;
            Navigator.of(context).pop();
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return ActionResultPopup(
                  type: 'time_conflict',
                  successKpi: {
                    'value': studentsMarkedCount,
                    'label': "Étudiant(s) marqué(s) comme absent(s)",
                  },
                  failedKpi: {
                    'value': overlappingStudents.length,
                    'label': "Étudiant(s) non marqués comme absent(s)",
                  },
                  failedListTitle: "Les étudiants non marqués absents",
                  failedListDescription:
                      "Ces étudiants n’ont pas été marqués comme absents en raison d’un conflit d’horaire avec une autre séance.",
                  failedList: overlappingStudents,
                  onClose: () {
                    if (!mounted) return;
                    Navigator.of(context).pop();
                    clearFiltersAndSelectedStudents();
                    _fetchGroupDetails(showLoading: true);
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  void _showUnmarkAbsenceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return UnmarkAbsencePopup(
          groupId: _groupDetail!['id'],
          studentCount: _selectedStudentIds.length,
          studentIds: _selectedStudentIds,
          onSuccess:
              ({
                required int requestedClasses,
                required int fullyUnmarkedCount,
                required List studentsWithMissingClasses,
              }) {
                if (!mounted) return;
                Navigator.of(context).pop();

                if (studentsWithMissingClasses.isEmpty) {
                  _showSuccess('Absence(s) annulée(s) avec succès');
                  clearFiltersAndSelectedStudents();
                  _fetchGroupDetails(showLoading: true);
                } else {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return ActionResultPopup(
                        type: 'missing_classes',
                        successKpi: {
                          'value': fullyUnmarkedCount,
                          'label':
                              "Étudiant(s) – absence(s) complètement annulée(s)",
                        },
                        failedKpi: {
                          'value': studentsWithMissingClasses.length,
                          'label':
                              "Étudiant(s) - absence(s) incomplètement annulée(s)",
                        },
                        failedListTitle:
                            "Étudiants avec des séances marquées absentes manquantes",
                        failedListDescription:
                            "Ces étudiants n’avaient pas suffisamment de séances marquées comme absentes pour annuler les $requestedClasses prévues.",
                        failedList: studentsWithMissingClasses,

                        onClose: () {
                          if (!mounted) return;
                          Navigator.of(context).pop();
                          clearFiltersAndSelectedStudents();
                          _fetchGroupDetails(showLoading: true);
                        },
                      );
                    },
                  );
                }
              },
          onError: () {
            if (!mounted) return;
            Navigator.of(context).pop();
            _showError('Erreur du serveur (500)');
            clearFiltersAndSelectedStudents();
            _fetchGroupDetails(showLoading: true);
          },
        );
      },
    );
  }

  void _showMarkPaymentDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return MarkPaymentPopup(
          studentCount: _selectedStudentIds.length,
          studentIds: _selectedStudentIds,
          groupId: widget.groupId,
          onSuccess:
              ({
                required int requestedClasses,
                required int fullyUnmarkedCount,
                required List studentsWithMissingClasses,
              }) {
                if (!mounted) return;
                Navigator.of(context).pop();

                if (studentsWithMissingClasses.isEmpty) {
                  _showSuccess('Paiement(s) marqué(s) avec succès');
                  clearFiltersAndSelectedStudents();
                  _fetchGroupDetails(showLoading: true);
                } else {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return ActionResultPopup(
                        type: 'missing_classes',
                        successKpi: {
                          'value': fullyUnmarkedCount,
                          'label':
                              "Étudiant(s) – paiement(s) complètement marqué(s)",
                        },
                        failedKpi: {
                          'value': studentsWithMissingClasses.length,
                          'label':
                              "Étudiant(s) - paiement(s) incomplètement marqué(s)",
                        },
                        failedListTitle:
                            "Étudiants avec des séances marquées présentes manquantes",
                        failedListDescription:
                            "Ces étudiants n’avaient pas suffisamment de séances marquées comme présentes pour marquer les $requestedClasses prévues.",
                        failedList: studentsWithMissingClasses,

                        onClose: () {
                          if (!mounted) return;
                          Navigator.of(context).pop();
                          clearFiltersAndSelectedStudents();
                          _fetchGroupDetails(showLoading: true);
                        },
                      );
                    },
                  );
                }
              },
          onError: () {
            if (!mounted) return;
            Navigator.of(context).pop();
            _showError('Erreur du serveur (500)');
            clearFiltersAndSelectedStudents();
            _fetchGroupDetails(showLoading: true);
          },
        );
      },
    );
  }

  void _showUnmarkPaymentDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return UnmarkPaymentPopup(
          groupId: _groupDetail!['id'],
          studentCount: _selectedStudentIds.length,
          studentIds: _selectedStudentIds,
          onSuccess:
              ({
                required int requestedClasses,
                required int fullyUnmarkedCount,
                required List studentsWithMissingClasses,
              }) {
                if (!mounted) return;
                Navigator.of(context).pop();

                if (studentsWithMissingClasses.isEmpty) {
                  _showSuccess('Paiement(s) annulé(s) avec succès');
                  clearFiltersAndSelectedStudents();
                  _fetchGroupDetails(showLoading: true);
                } else {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return ActionResultPopup(
                        type: 'missing_classes',
                        successKpi: {
                          'value': fullyUnmarkedCount,
                          'label':
                              "Étudiant(s) – paiement(s) complètement annulé(s)",
                        },
                        failedKpi: {
                          'value': studentsWithMissingClasses.length,
                          'label':
                              "Étudiant(s) - paiement(s) incomplètement annulé(s)",
                        },
                        failedListTitle:
                            "Étudiants avec des séances marquées payées manquantes",
                        failedListDescription:
                            "Ces étudiants n’avaient pas suffisamment de séances marquées comme payées pour annuler les $requestedClasses prévues.",
                        failedList: studentsWithMissingClasses,

                        onClose: () {
                          if (!mounted) return;
                          Navigator.of(context).pop();
                          clearFiltersAndSelectedStudents();
                          _fetchGroupDetails(showLoading: true);
                        },
                      );
                    },
                  );
                }
              },
          onError: () {
            if (!mounted) return;
            Navigator.of(context).pop();
            _showError('Erreur du serveur (500)');
            clearFiltersAndSelectedStudents();
            _fetchGroupDetails(showLoading: true);
          },
        );
      },
    );
  }
}
