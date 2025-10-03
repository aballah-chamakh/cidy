import 'dart:convert';
import 'package:cidy/config.dart';

import 'package:cidy/profiles/teacher/screens/teacher_group_detail_screen.dart';
import 'package:cidy/profiles/teacher/widgets/add_group_form.dart';
import 'package:cidy/profiles/teacher/widgets/group_filter_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../widgets/teacher_layout.dart';

class TeacherGroupsScreen extends StatefulWidget {
  const TeacherGroupsScreen({super.key});

  @override
  State<TeacherGroupsScreen> createState() => _TeacherGroupsScreenState();
}

class _TeacherGroupsScreenState extends State<TeacherGroupsScreen> {
  final Set<int> _selectedGroupIds = {};
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  List<dynamic> _groups = [];
  String? _errorMessage;
  Map<String, dynamic> _currentFilters = {};

  @override
  void initState() {
    super.initState();
    _fetchGroups();
  }

  Future<void> _fetchGroups({
    String? name,
    int? levelId,
    int? subjectId,
    String? day,
    String? timeRange,
    String? sortBy,
  }) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      if (token == null) {
        throw Exception('Authentication token not found.');
      }

      var url = Uri.parse('${Config.backendUrl}/api/teacher/groups/');
      final Map<String, String> queryParams = {};
      if (name != null && name.isNotEmpty) queryParams['name'] = name;
      if (levelId != null) queryParams['level'] = levelId.toString();
      if (subjectId != null) queryParams['subject'] = subjectId.toString();
      if (day != null) queryParams['day'] = day;
      if (timeRange != null) queryParams['time_range'] = timeRange;
      if (sortBy != null) queryParams['sort_by'] = sortBy;

      if (queryParams.isNotEmpty) {
        url = url.replace(queryParameters: queryParams);
      }

      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> groupList = data['groups'];
        if (mounted) {
          setState(() {
            _groups = groupList;
          });
        }
      } else {
        throw Exception('Failed to load groups: ${response.reasonPhrase}');
      }
    } catch (e, stackTrace) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString() + '\n' + stackTrace.toString();
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

  Future<void> _deleteGroups(List<int> groupIds) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      if (token == null) {
        throw Exception('Authentication token not found.');
      }

      final url = Uri.parse(
        '${Config.backendUrl}/api/teacher/groups/delete_groups/',
      );
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'group_ids': groupIds}),
      );

      if (response.statusCode == 204) {
        if (mounted) {
          setState(() {
            _selectedGroupIds.clear();
          });
          await _fetchGroups(); // Refresh the list
        }
      } else {
        throw Exception('Failed to delete groups: ${response.reasonPhrase}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatAmount(num amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toString();
  }

  void _showAddGroupDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Créer un nouveau groupe'),
          content: AddGroupForm(
            onGroupCreated: () {
              _fetchGroups(); // Refresh list after creation
            },
          ),
          // Make it scrollable and constrained
          scrollable: true,
          contentPadding: const EdgeInsets.fromLTRB(12.0, 20.0, 12.0, 24.0),
        );
      },
    );
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows the sheet to be taller
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.75, // Take up 75% of the screen height
          child: GroupFilterForm(
            currentFilters: _currentFilters,
            onApplyFilter: (filters) {
              setState(() {
                _currentFilters = filters;
              });
              _fetchGroups(
                name: _searchController.text,
                levelId: filters['level'],
                subjectId: filters['subject'],
                day: filters['day'],
                timeRange: filters['time_range'],
                sortBy: filters['sort_by'],
              );
              Navigator.pop(context); // Close the modal
            },
            onResetFilter: () {
              setState(() {
                _currentFilters = {};
                _searchController.clear();
              });
              _fetchGroups();
              Navigator.pop(context); // Close the modal
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return TeacherLayout(title: 'Groupes', body: _buildBody());
  }

  Widget _buildBody() {
    if (_isLoading && _groups.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Error: $_errorMessage', textAlign: TextAlign.center),
        ),
      );
    }

    return Column(
      children: [
        _buildToolbar(),
        if (_groups.isEmpty)
          Expanded(child: _buildNoGroupsUI())
        else
          Expanded(child: _buildGroupsListUI(_groups)),
      ],
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher par nom de groupe...',
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
                _fetchGroups(
                  name: value,
                  levelId: _currentFilters['level'],
                  subjectId: _currentFilters['subject'],
                  day: _currentFilters['day'],
                  timeRange: _currentFilters['time_range'],
                  sortBy: _currentFilters['sort_by'],
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              Icons.filter_list,
              color: _currentFilters.isNotEmpty
                  ? Theme.of(context).primaryColor
                  : null,
            ),
            onPressed: _showFilterModal,
            tooltip: 'Filtrer les groupes',
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _showAddGroupDialog,
            tooltip: 'Ajouter un groupe',
          ),
        ],
      ),
    );
  }

  Widget _buildNoGroupsUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/login_teacher_illustration.png', // Replace with a more suitable illustration
            height: 200,
          ),
          const SizedBox(height: 24),
          Text(
            "Aucun groupe trouvé",
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            "Vous n'avez encore créé aucun groupe.",
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddGroupDialog,
            icon: const Icon(Icons.add),
            label: const Text('Créez votre premier groupe'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30.0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupsListUI(List<dynamic> groups) {
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
                    '${groups.length} Groupe(s)',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (_selectedGroupIds.isNotEmpty)
                    Text('${_selectedGroupIds.length} sélectionné(s)'),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: groups.length,
                itemBuilder: (context, index) {
                  final group = groups[index];
                  return _buildGroupCard(group);
                },
              ),
            ),
            if (_selectedGroupIds.isNotEmpty)
              const SizedBox(height: 60), // Space for the sticky footer
          ],
        ),
        if (_isLoading && _groups.isNotEmpty)
          const Center(child: CircularProgressIndicator()),
        if (_selectedGroupIds.isNotEmpty)
          Positioned(bottom: 0, left: 0, right: 0, child: _buildStickyFooter()),
      ],
    );
  }

  Widget _buildGroupCard(dynamic group) {
    final isSelected = _selectedGroupIds.contains(group['id']);
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
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  TeacherGroupDetailScreen(groupId: group['id']),
            ),
          );
        },
        onLongPress: () {
          setState(() {
            if (isSelected) {
              _selectedGroupIds.remove(group['id']);
            } else {
              _selectedGroupIds.add(group['id']);
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      group['name'] ?? 'Groupe sans nom',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(group['level'], style: TextStyle(fontSize: 15)),
              const SizedBox(height: 4),
              Text(group['subject'], style: TextStyle(fontSize: 15)),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Payé',
                          style: TextStyle(color: Colors.green),
                        ),
                        Text(
                          _formatAmount(
                            double.tryParse(
                                  group['total_paid']?.toString() ?? '0',
                                ) ??
                                0,
                          ),
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Non payé',
                          style: TextStyle(color: Colors.red),
                        ),
                        Text(
                          _formatAmount(
                            double.tryParse(
                                  group['total_unpaid']?.toString() ?? '0',
                                ) ??
                                0,
                          ),
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              () {
                final double paid =
                    double.tryParse(group['total_paid']?.toString() ?? '0') ??
                    0;
                final double unpaid =
                    double.tryParse(group['total_unpaid']?.toString() ?? '0') ??
                    0;
                final double total = paid + unpaid;
                final double progress = total == 0 ? 0.0 : paid / total;

                return LinearProgressIndicator(
                  value: progress,
                  backgroundColor: total == 0
                      ? Theme.of(context).primaryColor
                      : Colors.red,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                );
              }(),
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
          topLeft: Radius.circular(15.0),
          topRight: Radius.circular(15.0),
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
              icon: const Icon(Icons.delete_outline),
              label: Text(
                'Supprimer (${_selectedGroupIds.length})',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 5),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                setState(() {
                  _selectedGroupIds.clear();
                });
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).primaryColor,
                backgroundColor: Theme.of(context).cardColor,
                minimumSize: const Size(double.infinity, 50),
                side: BorderSide(
                  color: Theme.of(context).primaryColor,
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
              child: const Text('Annuler', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteConfirmationDialog() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmer la suppression'),
          content: Text(
            'Êtes-vous sûr de vouloir supprimer ${_selectedGroupIds.length} groupe(s) ? Cette action est irréversible.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Annuler'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Supprimer'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _deleteGroups(_selectedGroupIds.toList());
    }
  }
}
