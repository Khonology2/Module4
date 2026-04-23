// ignore_for_file: use_build_context_synchronously, no_leading_underscores_for_local_identifiers

import '../widgets/app_modal.dart';

import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/user_role.dart';
import '../services/backend_api_service.dart';
import '../services/error_handler.dart';
import '../services/realtime_service.dart';
import '../services/user_data_service.dart';

class RoleManagementScreen extends StatefulWidget {
  const RoleManagementScreen({super.key});

  @override
  State<RoleManagementScreen> createState() => _RoleManagementScreenState();
}

class _RoleManagementScreenState extends State<RoleManagementScreen> {
  final BackendApiService _apiService = BackendApiService();
  final ErrorHandler _errorHandler = ErrorHandler();

  List<User> _users = [];
  bool _isLoading = true;
  String _searchQuery = '';
  UserRole? _filterRole;
  final UserDataService _userDataService = UserDataService();
  late final RealtimeService realtimeService;

  @override
  void initState() {
    super.initState();
    realtimeService = RealtimeService();
    _loadUsers();
    _setupRealtimeListeners();
  }

  @override
  void dispose() {
    realtimeService.off('user_role_changed', _handleRoleChanged);
    super.dispose();
  }

  void _setupRealtimeListeners() {
    realtimeService.on('user_role_changed', _handleRoleChanged);
  }

  void _handleRoleChanged(dynamic data) {
    // Reload users when a role change is detected from another session
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch real users from backend API with search and filter support
      final users = await _userDataService.getUsers(
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
        filterRole: _filterRole,
      );

      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      _errorHandler.showErrorSnackBar(context, 'Error loading users: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Role Management'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildUsersList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddUserDialog(),
        icon: const Icon(Icons.person_add),
        label: const Text('Add User'),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Search users...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', null),
                const SizedBox(width: 8),
                ...UserRole.values
                    .map((role) => _buildFilterChip(role.displayName, role)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, UserRole? role) {
    final isSelected = _filterRole == role;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterRole = selected ? role : null;
        });
      },
      selectedColor:
          Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
      checkmarkColor: Theme.of(context).colorScheme.primary,
    );
  }

  Widget _buildUsersList() {
    final filteredUsers = _getFilteredUsers();

    if (filteredUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No users found',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or filter',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[500],
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredUsers.length,
      itemBuilder: (context, index) {
        final user = filteredUsers[index];
        return _buildUserCard(user);
      },
    );
  }

  List<User> _getFilteredUsers() {
    final filtered = _users.where((user) {
      final matchesSearch = _searchQuery.isEmpty ||
          user.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          user.email.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesRole = _filterRole == null || user.role == _filterRole;

      return matchesSearch && matchesRole;
    }).toList();

    // Sort by name
    filtered.sort((a, b) => a.name.compareTo(b.name));

    return filtered;
  }

  Widget _buildUserCard(User user) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: user.roleColor,
              child: Icon(
                user.roleIcon,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: user.roleColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              user.roleIcon,
                              size: 16,
                              color: user.roleColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              user.roleDisplayName,
                              style: TextStyle(
                                color: user.roleColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: user.isActive
                              ? Colors.green.withValues(alpha: 0.1)
                              : Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          user.isActive ? 'Active' : 'Inactive',
                          style: TextStyle(
                            color: user.isActive ? Colors.green : Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    _showEditUserDialog(user);
                    break;
                  case 'change_role':
                    _showChangeRoleDialog(user);
                    break;
                  case 'toggle_status':
                    _toggleUserStatus(user);
                    break;
                  case 'delete':
                    _showDeleteUserDialog(user);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit),
                      SizedBox(width: 8),
                      Text('Edit User'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'change_role',
                  child: Row(
                    children: [
                      Icon(Icons.swap_horiz),
                      SizedBox(width: 8),
                      Text('Change Role'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'toggle_status',
                  child: Row(
                    children: [
                      Icon(user.isActive ? Icons.block : Icons.check_circle),
                      const SizedBox(width: 8),
                      Text(user.isActive ? 'Deactivate' : 'Activate'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete User', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              child: const Icon(Icons.more_vert),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddUserDialog() {
    final formKey = GlobalKey<FormState>();
    final emailController = TextEditingController();
    final _nameController = TextEditingController();
    final _passwordController = TextEditingController();
    String _selectedRole = 'user';

    showAppDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add New User'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter email';
                      }
                      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+\$')
                          .hasMatch(value)) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Full Name'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter full name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value: _selectedRole,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: ['user', 'admin', 'systemAdmin']
                        .map(
                          (role) => DropdownMenuItem(
                            value: role,
                            child: Text(role),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      _selectedRole = value!;
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Please select a role';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Add'),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  try {
                    final userRole = _convertStringToUserRole(_selectedRole);
                    final response = await _apiService.signUp(
                      emailController.text,
                      _passwordController.text,
                      _nameController.text,
                      userRole,
                    );

                    if (response.isSuccess) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('User created successfully')),
                      );
                      _loadUsers(); // Refresh the user list
                      Navigator.of(context).pop();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Error: \${response.error}')),
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Error creating user: \$e')),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showEditUserDialog(User user) {
    final nameController = TextEditingController(text: user.name);
    final emailController = TextEditingController(text: user.email);
    UserRole selectedRole = user.role;

    showAppDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${user.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<UserRole>(
                // ignore: deprecated_member_use
                value: selectedRole,
                decoration: const InputDecoration(labelText: 'Role'),
                items: UserRole.values
                    .map(
                      (role) => DropdownMenuItem(
                        value: role,
                        child: Text(role.displayName),
                      ),
                    )
                    .toList(),
                onChanged: (role) {
                  if (role != null) selectedRole = role;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final nameParts = nameController.text.trim().split(' ');
              final firstName = nameParts.isNotEmpty ? nameParts.first : '';
              final lastName =
                  nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
              _errorHandler.showLoadingDialog(context,
                  message: 'Saving changes...');
              try {
                await _userDataService.updateUser(
                  userId: user.id,
                  firstName: firstName,
                  lastName: lastName,
                  email: emailController.text.trim(),
                  role: selectedRole.name,
                );
                _errorHandler.hideLoadingDialog(context);
                await _loadUsers();
                _errorHandler.showSuccessSnackBar(
                    context, 'User updated successfully');
                Navigator.of(context).pop();
              } catch (e) {
                _errorHandler.hideLoadingDialog(context);
                _errorHandler.showErrorSnackBar(
                    context, 'Failed to update user: $e');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showChangeRoleDialog(User user) {
    showAppDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Change Role for ${user.name}'),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: UserRole.values.map((role) {
                return ListTile(
                  leading: Icon(role.icon, color: role.color),
                  title: Text(role.displayName),
                  subtitle: Text(role.description),
                  trailing: user.role == role ? const Icon(Icons.check) : null,
                  onTap: () {
                    Navigator.of(context).pop();
                    _changeUserRole(user, role);
                  },
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _changeUserRole(User user, UserRole newRole) {
    _errorHandler.showLoadingDialog(context, message: 'Changing role...');
    _userDataService.updateUserRole(user.id, newRole).then((success) async {
      _errorHandler.hideLoadingDialog(context);
      if (success) {
        await _loadUsers();
        _errorHandler.showSuccessSnackBar(
            context, '${user.name}\'s role changed to ${newRole.displayName}');
      } else {
        _errorHandler.showErrorSnackBar(context, 'Failed to change role');
      }
    }).catchError((e) {
      _errorHandler.hideLoadingDialog(context);
      _errorHandler.showErrorSnackBar(context, 'Error: $e');
    });
  }

  void _toggleUserStatus(User user) {
    final newStatus = !user.isActive;
    _errorHandler.showLoadingDialog(context,
        message: newStatus ? 'Activating user...' : 'Deactivating user...');
    _userDataService
        .updateUser(
      userId: user.id,
      isActive: newStatus,
    )
        .then((_) async {
      _errorHandler.hideLoadingDialog(context);
      await _loadUsers();
      _errorHandler.showSuccessSnackBar(
          context, '${user.name} ${newStatus ? 'activated' : 'deactivated'}');
    }).catchError((e) {
      _errorHandler.hideLoadingDialog(context);
      _errorHandler.showErrorSnackBar(context, 'Failed to update status: $e');
    });
  }

  void _showDeleteUserDialog(User user) {
    showAppDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete User'),
          content: Text(
              'Are you sure you want to delete ${user.name}? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                _errorHandler.showLoadingDialog(context,
                    message: 'Deleting user...');
                final result = await _userDataService.deleteUser(user.id);
                _errorHandler.hideLoadingDialog(context);
                if (result['success'] == true) {
                  _errorHandler.showSuccessSnackBar(
                      context, 'User deleted successfully');
                  await _loadUsers();
                } else {
                  _errorHandler.showErrorSnackBar(context,
                      result['error']?.toString() ?? 'Failed to delete user');
                }
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  UserRole _convertStringToUserRole(String roleString) {
    switch (roleString.toLowerCase()) {
      case 'systemadmin':
      case 'system_admin':
      case 'system admin':
        return UserRole.systemAdmin;
      case 'deliverylead':
      case 'delivery_lead':
      case 'delivery lead':
        return UserRole.deliveryLead;
      case 'clientreviewer':
      case 'client_reviewer':
      case 'client reviewer':
        return UserRole.clientReviewer;
      case 'teammember':
      case 'team_member':
      case 'team member':
      case 'user':
      default:
        return UserRole.teamMember;
    }
  }
}
