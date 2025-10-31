import 'dart:convert';
import 'dart:async';
import 'package:cidy/app_styles.dart';
import 'package:cidy/config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:cidy/authentication/login.dart';

class AddExistingStudentPopup extends StatefulWidget {
  final int groupId;
  final Function onStudentsAdded;
  final Function onServerError;
  final VoidCallback? onBack;

  const AddExistingStudentPopup({
    super.key,
    required this.groupId,
    required this.onStudentsAdded,
    required this.onServerError,
    this.onBack,
  });

  @override
  State<AddExistingStudentPopup> createState() =>
      _AddExistingStudentPopupState();
}

class _AddExistingStudentPopupState extends State<AddExistingStudentPopup> {
  List _availableStudents = [];
  int _availableStudentsCount = 0;
  int _page = 1;
  final Set<int> _selectedStudentIds = {};
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _isLoadingMore = false;

  // Debounce for the search field to avoid spamming the API
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _fetchAvailableStudents();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchAvailableStudents() async {
    setState(() {
      if (_page == 1) {
        _isLoading = true;
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

      final queryParams = {
        'fullname': _searchController.text,
        'page': _page.toString(),
      };

      final url = Uri.parse(
        '${Config.backendUrl}/api/teacher/groups/${widget.groupId}/possible_students/',
      ).replace(queryParameters: queryParams);

      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _availableStudentsCount = data['total_students'];
          _page = data['page'];
          if (_page > 1) {
            _availableStudents.addAll(data['students']);
          } else {
            _availableStudents = data['students'];
          }
        });
      } else if (response.statusCode == 401) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      } else {
        widget.onServerError();
      }
    } catch (e) {
      if (!mounted) return;
      widget.onServerError();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _addStudentsToGroup() async {
    if (_selectedStudentIds.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Veuillez sélectionner au moins un élève.',
            style: TextStyle(fontSize: mediumFontSize),
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _isSubmitting = true;
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

      final url = Uri.parse(
        '${Config.backendUrl}/api/teacher/groups/${widget.groupId}/students/add/',
      );

      final response = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'student_ids': _selectedStudentIds.toList()}),
      );
      if (!mounted) return;

      if (response.statusCode == 200) {
        final studentCount = _selectedStudentIds.length;
        final message = studentCount == 1
            ? 'L’élève a été ajouté avec succès.'
            : '$studentCount élèves ont été ajoutés avec succès.';
        widget.onStudentsAdded(message: message);
      } else if (response.statusCode == 401) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      } else {
        widget.onServerError();
      }
    } catch (e) {
      if (!mounted) return;
      widget.onServerError();
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _toggleStudentSelection(int studentId) {
    if (!mounted) return;
    setState(() {
      if (_selectedStudentIds.contains(studentId)) {
        _selectedStudentIds.remove(studentId);
      } else {
        _selectedStudentIds.add(studentId);
      }
    });
  }

  Future<void> _loadNextPage() async {
    if (_isLoading || _isLoadingMore) return;

    // Check if there are more students to load
    if (_availableStudents.length >= _availableStudentsCount) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tous les élèves ont été chargés.',
            style: TextStyle(fontSize: mediumFontSize),
          ),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _page++;
    });
    await _fetchAvailableStudents();
  }

  void _onScroll() {
    // Prevent starting pagination while an initial or ongoing load is in progress
    if (_isLoading || _isLoadingMore) return;

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_availableStudents.length < _availableStudentsCount) {
        _loadNextPage();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: popupHorizontalMargin,
        vertical: 0,
      ),

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Container(
          padding: const EdgeInsets.all(popupPadding),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(popupBorderRadius),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              const Divider(height: 16),
              _buildSearchField(),
              const SizedBox(height: 8),
              if (_availableStudentsCount > 0) _buildStudentsHeader(),
              const SizedBox(height: 8),
              Flexible(
                fit: FlexFit.loose,
                child: Scrollbar(
                  controller: _scrollController,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: _buildStudentsList(),
                  ),
                ),
              ),
              const Divider(height: 30),
              _buildActionButtons(),
            ],
          ),
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
            fontSize: headerFontSize,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
        IconButton(
          icon: Icon(
            Icons.close,
            weight: 2.0,
            size: headerIconSize,
            color: primaryColor,
          ),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }

  Widget _buildStudentsHeader() {
    return Text(
      '$_availableStudentsCount Élèves',
      style: TextStyle(
        fontSize: mediumFontSize,
        fontWeight: FontWeight.w600,
        color: primaryColor,
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      cursorColor: primaryColor,
      style: const TextStyle(fontSize: mediumFontSize),
      decoration: InputDecoration(
        hintText: 'Rechercher un élève...',
        hintStyle: const TextStyle(fontSize: mediumFontSize),
        prefixIcon: const Icon(Icons.search),
        contentPadding: inputContentPadding,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputBorderRadius),
          borderSide: BorderSide(color: primaryColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputBorderRadius),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
      ),
      onChanged: (value) {
        // Debounce the search to avoid firing too many requests
        _searchDebounce?.cancel();
        _searchDebounce = Timer(const Duration(milliseconds: 350), () {
          if (!mounted) return;
          setState(() {
            _page = 1; // Reset to first page when searching
            _selectedStudentIds.clear();
          });
          _fetchAvailableStudents();
        });
      },
    );
  }

  Widget _buildStudentsList() {
    if (_isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: CircularProgressIndicator(color: primaryColor),
        ),
      );
    }

    if (_availableStudents.isEmpty && _searchController.text.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(15.0),
        child: Center(
          child: Text(
            'Aucun élève du même niveau que le groupe n’est disponible à ajouter.',
            style: TextStyle(fontSize: mediumFontSize),
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else if (_availableStudents.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(15.0),
        child: Center(
          child: Text(
            'Aucun élève trouvé pour votre recherche.',

            style: TextStyle(fontSize: mediumFontSize),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return Column(
      children: [
        ..._availableStudents.map((student) {
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
            child: InkWell(
              onLongPress: () => _toggleStudentSelection(studentId),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    // Profile image rounded
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: student['image'] != null
                          ? NetworkImage(
                              '${Config.backendUrl}${student['image']}',
                            )
                          : null,
                      child: student['image'] == null
                          ? Text(
                              student['fullname'].toString()[0].toUpperCase(),
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: mediumFontSize,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    // Full name
                    Expanded(
                      child: Text(
                        student['fullname'].toString(),
                        style: const TextStyle(
                          fontSize: mediumFontSize,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    // Selection indicator
                    if (isSelected)
                      Icon(
                        Icons.check_circle,
                        color: Theme.of(context).primaryColor,
                        size: 24,
                      ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
        if (_isLoadingMore)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(15.0),
              child: CircularProgressIndicator(color: primaryColor),
            ),
          ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: TextButton(
            style: secondaryButtonStyle,
            onPressed: _isSubmitting
                ? null
                : () {
                    if (widget.onBack != null) {
                      widget.onBack!();
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
            child: const Text(
              'Retour',
              style: TextStyle(fontSize: mediumFontSize),
            ),
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: ElevatedButton(
            style: primaryButtonStyle,
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
                : const Text(
                    'Ajouter',
                    style: TextStyle(fontSize: mediumFontSize),
                  ),
          ),
        ),
      ],
    );
  }
}
