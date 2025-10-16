import 'dart:convert';
import 'package:cidy/app_styles.dart';
import 'package:cidy/app_tools.dart';
import 'package:cidy/constants.dart';
import 'package:cidy/config.dart';
import 'package:cidy/profiles/teacher/widgets/teacher_group_detail_screen/add_student_popup.dart';
import 'package:cidy/profiles/teacher/widgets/teacher_group_detail_screen/delete_group_popup.dart';
import 'package:cidy/profiles/teacher/widgets/teacher_group_detail_screen/edit_group_form.dart';
import 'package:cidy/profiles/teacher/widgets/teacher_group_detail_screen/unmark_payment_popup.dart';
import 'package:cidy/profiles/teacher/widgets/teacher_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:cidy/authentication/login.dart';

import '../widgets/teacher_group_detail_screen/mark_attendance_popup.dart';
import '../widgets/teacher_group_detail_screen/mark_payment_popup.dart';
import '../widgets/teacher_group_detail_screen/remove_students_popup.dart';
import '../widgets/teacher_group_detail_screen/unmark_attendance_popup.dart';

class TeacherGroupDetailScreen extends StatefulWidget {
  final int groupId;
  final VoidCallback refreshGroupList;
  const TeacherGroupDetailScreen({
    super.key,
    required this.groupId,
    required this.refreshGroupList,
  });

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
    'name_asc': 'Nom (A à Z)',
    'name_desc': 'Nom (Z à A)',
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
        widget.refreshGroupList();
      } else if (response.statusCode == 401) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      } else {
        _showError("erreur du serveur (500)");
        Navigator.pop(context);
        widget.refreshGroupList();
      }
    } catch (e) {
      if (!mounted) return;
      _showError("erreur du serveur (500)");
      Navigator.pop(context);
      widget.refreshGroupList();
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

  void clearFiltersAndSelectedStudents() {
    setState(() {
      _searchController.text = '';
      _sortBy = '';
      _selectedStudentIds.clear();
    });
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
            formatToK((group['total_paid'] ?? 0).toString()),
            'Payé',
            Colors.green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildKpiCard(
            formatToK((group['total_unpaid'] ?? 0).toString()),
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
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${students.length} Élève(s)',
                  style: TextStyle(
                    fontSize: mediumFontSize,
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
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            _buildStudentFilters(),
            const SizedBox(height: 10),
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
        _searchController.text.isNotEmpty
            ? "Aucun élève ne correspond à votre recherche."
            : 'Aucun élève dans ce groupe.',
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
      margin: EdgeInsets.symmetric(vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: isSelected
            ? const BorderSide(color: primaryColor, width: 1.5)
            : BorderSide(color: Colors.grey.shade300),
      ),
      child: InkWell(
        onTap: () {
          // TODO: Navigate to student detail screen
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
        return EditGroupForm(
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
              ({String message = 'L’élève a été créé et ajouté avec succès.'}) {
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
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return DeleteGroupPopup(groupName: _groupDetail!['name']);
      },
    );
    if (!mounted) return;

    if (confirmed == true) {
      _deleteGroup();
    }
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
                  value: 'remove',
                  child: Text(
                    'Retirer du groupe',
                    style: TextStyle(fontSize: mediumFontSize),
                  ),
                ),
                DropdownMenuItem(
                  value: 'mark_attendance',
                  child: Text(
                    'Marquer présence',
                    style: TextStyle(fontSize: mediumFontSize),
                  ),
                ),
                DropdownMenuItem(
                  value: 'unmark_attendance',
                  child: Text(
                    'Annuler présence',
                    style: TextStyle(fontSize: mediumFontSize),
                  ),
                ),
                DropdownMenuItem(
                  value: 'mark_payment',
                  child: Text(
                    'Marquer paiement',
                    style: TextStyle(fontSize: mediumFontSize),
                  ),
                ),
                DropdownMenuItem(
                  value: 'unmark_payment',
                  child: Text(
                    'Annuler paiement',
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
        return RemoveStudentsPopup(
          studentCount: _selectedStudentIds.length,
          studentIds: _selectedStudentIds,
          groupId: widget.groupId,
          onSuccess: () {
            if (!mounted) return;
            Navigator.of(context).pop();
            _showSuccess('Élèves retirés avec succès');
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
            _showSuccess('Présence marquée avec succès');
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
        );
      },
    );
  }

  void _showUnmarkAttendanceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return UnmarkAttendancePopup(
          studentCount: _selectedStudentIds.length,
          studentIds: _selectedStudentIds,
          onSuccess: () {
            _showSuccess('Présence annulée avec succès');
            clearFiltersAndSelectedStudents();
            _fetchGroupDetails(showLoading: false);
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
          onSuccess: () {
            _showSuccess('Paiement marqué avec succès');
            clearFiltersAndSelectedStudents();
            _fetchGroupDetails(showLoading: false);
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
          studentCount: _selectedStudentIds.length,
          studentIds: _selectedStudentIds,
          onSuccess: () {
            _showSuccess('Paiement annulé avec succès');
            clearFiltersAndSelectedStudents();
            _fetchGroupDetails(showLoading: false);
          },
        );
      },
    );
  }
}
