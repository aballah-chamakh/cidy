import 'dart:convert';
import 'package:cidy/config.dart';
import 'package:cidy/app_styles.dart';
import 'package:cidy/app_tools.dart';
import 'package:cidy/profiles/teacher/widgets/teacher_students_screen/students_filter_form_popup.dart';
import 'package:cidy/profiles/teacher/widgets/teacher_students_screen/delete_multiple_students_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:cidy/authentication/login.dart';
import '../widgets/teacher_layout.dart';

class TeacherStudentsScreen extends StatefulWidget {
  const TeacherStudentsScreen({super.key});

  @override
  State<TeacherStudentsScreen> createState() => _TeacherStudentsScreenState();
}

class _TeacherStudentsScreenState extends State<TeacherStudentsScreen> {
  final Set<int> _selectedStudentIds = {};
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = true;
  bool _isLoadingMore = false;
  List<dynamic> _students = [];
  int _studentsTotalCount = 0;
  int _page = 1;
  Map<String, dynamic> _currentFilters = {};
  Map<String, dynamic> _filterOptions = {};

  int _countActiveFilters() {
    int count = 0;
    if (_currentFilters['level'] != null) count++;
    if (_currentFilters['section'] != null) count++;
    if (_currentFilters['sort_by'] != null) count++;
    return count;
  }

  @override
  void initState() {
    super.initState();
    _fetchStudents();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _fetchStudents({
    String? fullname,
    String? level,
    String? section,
    String? sortBy,
    int page = 1,
    String source = "",
  }) async {
    //if (_isLoading || _isLoadingMore) return;
    if (!mounted) return;
    if (source == "filter") {
      Navigator.of(context).pop();
    }
    setState(() {
      if (page == 1) {
        _isLoading = true;
        _students = [];
        _page = 1;
      } else {
        _isLoadingMore = true;
      }
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

      var url = Uri.parse('${Config.backendUrl}/api/teacher/students/');
      final Map<String, String> queryParams = {'page': page.toString()};
      if (fullname != null && fullname.isNotEmpty)
        queryParams['fullname'] = fullname;
      if (level != null) queryParams['level'] = level;
      if (section != null) queryParams['section'] = section;
      if (sortBy != null) {
        const Map<String, String> sortKeyMap = {
          'paid_amount_desc': 'paid_amount_desc',
          'paid_amount_asc': 'paid_amount_asc',
          'unpaid_amount_desc': 'unpaid_amount_desc',
          'unpaid_amount_asc': 'unpaid_amount_asc',
        };
        queryParams['sort_by'] = sortKeyMap[sortBy] ?? sortBy;
      }

      url = url.replace(queryParameters: queryParams);

      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          if (page == 1 || data['page'] == 1) {
            _students = data['students'] as List<dynamic>;
          } else {
            _students.addAll(data['students'] as List<dynamic>);
          }
          _studentsTotalCount = data['total_students'];
          _filterOptions =
              data['teacher_levels_sections_subjects_hierarchy']
                  as Map<String, dynamic>;
        });
      } else if (response.statusCode == 401) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      } else {
        _showError("Erreur du serveur (500)");
      }
    } catch (e, stacktrace) {
      if (!mounted) return;
      print("Error: $e");
      print("StackTrace: $stacktrace");
      _showError("Erreur du serveur (500)");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _deleteStudents(List<int> studentIds) async {
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

      final url = Uri.parse(
        '${Config.backendUrl}/api/teacher/students/delete/',
      );
      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'student_ids': studentIds}),
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
          setState(() {
            _selectedStudentIds.clear();
          });
          await _fetchStudents(
            fullname: _searchController.text,
            level: _currentFilters['level']?.toString(),
            section: _currentFilters['section']?.toString(),
            sortBy: _currentFilters['sort_by'],
          ); // Refresh the list
        }
      } else {
        _showError("Erreur du serveur (500)");
      }
    } catch (e, stackTrace) {
      if (mounted) {
        print("Error: $e");
        print("StackTrace: $stackTrace");
        _showError("Erreur du serveur (500)");
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadNextPage() async {
    if (_isLoading || _isLoadingMore) return;

    if (_students.length >= _studentsTotalCount) {
      return;
    }

    if (!mounted) return;
    setState(() {
      _page += 1;
    });
    await _fetchStudents(
      fullname: _searchController.text,
      level: _currentFilters['level']?.toString(),
      section: _currentFilters['section']?.toString(),
      sortBy: _currentFilters['sort_by'],
      page: _page,
    );
  }

  void _onScroll() {
    if (_isLoading || _isLoadingMore) return;

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_students.length < _studentsTotalCount) {
        _loadNextPage();
      }
    }
  }

  void _showInfoModal(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(10.0),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16.0),
            ),
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
                      icon: Icon(
                        Icons.close,
                        size: 30,
                        color: Theme.of(context).primaryColor,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(height: 10, thickness: 1),
                const SizedBox(height: 20),
                Icon(
                  Icons.info_outline,
                  size: 100,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 20),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    child: const Text(
                      'OK',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showDeleteConfirmationDialog() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return DeleteMultipleStudentsPopup(
          studentCount: _selectedStudentIds.length,
        );
      },
    );

    if (confirmed == true) {
      await _deleteStudents(_selectedStudentIds.toList());
    }
  }

  void _showAddStudentDialog() {
    // TODO: Implement AddStudentForm
    print("Show add student dialog");
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows the sheet to be taller
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            child: StudentsFilterPopup(
              currentFilters: _currentFilters,
              filterOptions: _filterOptions,
              onApplyFilter: (filters) {
                setState(() {
                  _currentFilters = filters;
                });
                _fetchStudents(
                  fullname: _searchController.text,
                  level: _currentFilters['level'],
                  section: _currentFilters['section'],
                  sortBy: _currentFilters['sort_by'],
                  source: "filter",
                );
              },
              onResetFilter: () {
                setState(() {
                  _currentFilters = {};
                });
                _fetchStudents(
                  fullname: _searchController.text,
                  source: "filter",
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return TeacherLayout(title: 'Students', body: _buildBody());
  }

  Widget _buildBody() {
    return Column(
      children: [
        _buildToolbar(),
        if (_isLoading && _students.isEmpty)
          Expanded(
            child: RefreshIndicator(
              color: Theme.of(context).primaryColor,
              onRefresh: () async {
                if (_isLoading) return;
                await _fetchStudents(
                  fullname: _searchController.text,
                  level: _currentFilters['level']?.toString(),
                  section: _currentFilters['section']?.toString(),
                  sortBy: _currentFilters['sort_by'],
                );
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: Center(
                    child: CircularProgressIndicator(color: primaryColor),
                  ),
                ),
              ),
            ),
          )
        else if (_students.isEmpty)
          Expanded(child: _buildNoStudentsUI())
        else
          Expanded(child: _buildStudentsListUI()),
      ],
    );
  }

  Widget _buildToolbar() {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(4.0),
          topRight: Radius.circular(4.0),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Expanded(
              child: TextField(
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
                onChanged: (value) {
                  _fetchStudents(
                    fullname: value,
                    level: _currentFilters['level'],
                    section: _currentFilters['section'],
                    sortBy: _currentFilters['sort_by'],
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.filter_list_outlined),
                  onPressed: _showFilterModal,
                  tooltip: 'Filtrer les étudiants',
                ),
                if (_countActiveFilters() > 0)
                  Positioned(
                    right: 3,
                    top: 3,
                    child: IgnorePointer(
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            _countActiveFilters().toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () {
                if (_filterOptions.isEmpty) {
                  _showInfoModal(
                    'Vous devez ajouter au moins un niveau pour pouvoir créer un groupe.',
                  );
                } else {
                  _showAddStudentDialog();
                }
              },
              tooltip: 'Ajouter un étudiant',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoStudentsUI() {
    return RefreshIndicator(
      color: Theme.of(context).primaryColor,
      onRefresh: () async {
        if (_isLoading) return;
        await _fetchStudents(
          fullname: _searchController.text,
          level: _currentFilters['level']?.toString(),
          section: _currentFilters['section']?.toString(),
          sortBy: _currentFilters['sort_by'],
        );
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 100,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 20),
                const Text(
                  "you don't have any student yet",
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    if (_filterOptions.isEmpty) {
                      _showInfoModal(
                        'Vous devez ajouter au moins un niveau pour pouvoir créer un groupe.',
                      );
                    } else {
                      _showAddStudentDialog();
                    }
                  },
                  child: const Text('Create a student'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudentsListUI() {
    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$_studentsTotalCount étudiants',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: Theme.of(context).primaryColor,
                onRefresh: () async {
                  if (_isLoading) return;
                  await _fetchStudents(
                    fullname: _searchController.text,
                    level: _currentFilters['level']?.toString(),
                    section: _currentFilters['section']?.toString(),
                    sortBy: _currentFilters['sort_by'],
                  );
                },
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _students.length + (_isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _students.length) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      );
                    }
                    final student = _students[index];
                    return _buildStudentCard(student);
                  },
                ),
              ),
            ),
            if (_selectedStudentIds.isNotEmpty)
              const SizedBox(height: 110), // Space for the sticky footer
          ],
        ),
        if (_isLoading && _students.isNotEmpty)
          const Center(child: CircularProgressIndicator()),
        if (_selectedStudentIds.isNotEmpty)
          Positioned(bottom: 0, left: 0, right: 0, child: _buildStickyFooter()),
      ],
    );
  }

  Widget _buildStudentCard(dynamic student) {
    final isSelected = _selectedStudentIds.contains(student['id']);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: Theme.of(context).primaryColor, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // TODO: Navigate to student detail screen
        },
        onLongPress: () {
          setState(() {
            if (isSelected) {
              _selectedStudentIds.remove(student['id']);
            } else {
              _selectedStudentIds.add(student['id']);
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundImage: NetworkImage(
                  "${Config.backendUrl}${student['image']}",
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student['fullname'] ?? 'N/A',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: mediumFontSize,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(student['level'], style: TextStyle(fontSize: 15)),
                    if (student['section'] != null)
                      Text(student['section'], style: TextStyle(fontSize: 15)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "${formatToK(student['paid_amount'].toString())} DT",
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${formatToK(student['unpaid_amount'].toString())} DT",
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
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

  Widget _buildStickyFooter() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(10),
          topRight: Radius.circular(10),
        ),
        boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 1.0)],
      ),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
              onPressed: () {
                _showDeleteConfirmationDialog();
              },
              icon: const Icon(Icons.delete_outline, size: 25),
              label: Text(
                'Supprimer (${_selectedStudentIds.length})',
                style: TextStyle(fontSize: mediumFontSize),
              ),
            ),
          ),
          const SizedBox(height: 5),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                setState(() {
                  _selectedStudentIds.clear();
                });
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryColor,
                backgroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                side: BorderSide(color: primaryColor, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
              child: const Text(
                'Annuler',
                style: TextStyle(fontSize: mediumFontSize),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
