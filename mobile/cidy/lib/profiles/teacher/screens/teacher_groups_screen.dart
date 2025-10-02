import 'dart:convert';
import 'package:cidy/config.dart';
import 'package:cidy/profiles/teacher/models/group_model.dart';
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
  List<Group> _groups = [];
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
    int? sectionId,
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
      if (sectionId != null) queryParams['section'] = sectionId.toString();
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
            _groups = groupList.map((json) => Group.fromJson(json)).toList();
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
          title: const Text('Create New Group'),
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
                sectionId: filters['section'],
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
    return TeacherLayout(title: 'Groups', body: _buildBody());
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
                hintText: 'Search by group name...',
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
                _fetchGroups(name: value);
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
            tooltip: 'Filter Groups',
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _showAddGroupDialog,
            tooltip: 'Add Group',
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
            "No Groups Found",
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            "You haven't created any groups yet.",
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddGroupDialog,
            icon: const Icon(Icons.add),
            label: const Text('Create Your First Group'),
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

  Widget _buildGroupsListUI(List<Group> groups) {
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
                    '${groups.length} Group(s)',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (_selectedGroupIds.isNotEmpty)
                    Text('${_selectedGroupIds.length} selected'),
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

  Widget _buildGroupCard(Group group) {
    final isSelected = _selectedGroupIds.contains(group.id);
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
          if (_selectedGroupIds.isNotEmpty) {
            setState(() {
              if (isSelected) {
                _selectedGroupIds.remove(group.id);
              } else {
                _selectedGroupIds.add(group.id);
              }
            });
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    TeacherGroupDetailScreen(groupId: group.id),
              ),
            );
          }
        },
        onLongPress: () {
          setState(() {
            if (!isSelected) {
              _selectedGroupIds.add(group.id);
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      group.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check_circle,
                      color: Theme.of(context).primaryColor,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${group.level} ${group.section != null ? ' - ${group.section}' : ''}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(group.subject, style: Theme.of(context).textTheme.bodySmall),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildInfoChip(
                    Icons.person,
                    '${group.studentCount} Students',
                    Colors.blue,
                  ),
                  _buildInfoChip(
                    Icons.calendar_today,
                    group.day,
                    Colors.purple,
                  ),
                  _buildInfoChip(
                    Icons.access_time,
                    '${group.startTime.format(context)} - ${group.endTime.format(context)}',
                    Colors.orange,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Paid',
                          style: TextStyle(color: Colors.green),
                        ),
                        Text(
                          _formatAmount(group.paid),
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
                          'Unpaid',
                          style: TextStyle(color: Colors.red),
                        ),
                        Text(
                          _formatAmount(group.unpaid),
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
              LinearProgressIndicator(
                value:
                    group.paid /
                    (group.paid + group.unpaid).clamp(1, double.infinity),
                backgroundColor: Colors.red[100],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Chip(
      avatar: Icon(icon, color: color, size: 16),
      label: Text(label),
      backgroundColor: color.withOpacity(0.1),
      padding: EdgeInsets.zero,
      labelStyle: const TextStyle(fontSize: 12),
    );
  }

  Widget _buildStickyFooter() {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedGroupIds.clear();
              });
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              _showDeleteConfirmationDialog();
            },
            icon: const Icon(Icons.delete_outline),
            label: Text('Delete (${_selectedGroupIds.length})'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text(
            'Are you sure you want to delete ${_selectedGroupIds.length} group(s)? This action cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                _deleteGroups(_selectedGroupIds.toList());
              },
            ),
          ],
        );
      },
    );
  }
}
