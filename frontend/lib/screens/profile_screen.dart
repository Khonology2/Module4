// ignore_for_file: use_build_context_synchronously, prefer_const_constructors

import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../services/profile_service.dart';
import '../services/auth_service.dart';
import '../config/environment.dart';
import 'package:http/http.dart' as http;
import '../widgets/app_scaffold.dart';
import '../widgets/app_modal.dart';
import 'package:go_router/go_router.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final String? mode;

  const ProfileScreen({super.key, this.mode});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  File? _profileImage;
  Uint8List? _profileImageBytes;
  String? _profileImageUrl;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _isEditMode = (widget.mode ?? 'view') == 'edit';
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      final profile = await ProfileService.getUserProfile();
      setState(() async {
        _firstNameController.text = profile['first_name'] ?? '';
        _lastNameController.text = profile['last_name'] ?? '';
        _emailController.text = profile['email'] ?? '';
        _phoneController.text = profile['phone_number'] ?? '';
        _titleController.text = profile['job_title'] ?? '';
        _departmentController.text = profile['company'] ?? '';
        _bioController.text = profile['bio'] ?? '';
        final rawUrl = (profile['profile_picture'] ??
                profile['profileImageUrl'] ??
                profile['profile_image_url'])
            ?.toString();
        final uid = (profile['user_id'] ?? profile['userId'])?.toString();
        if (rawUrl != null &&
            rawUrl.isNotEmpty &&
            uid != null &&
            uid.isNotEmpty) {
          final base = Uri.parse(Environment.apiBaseUrl);
          final apiPic =
              '${base.scheme}://${base.host}:${base.port.toString()}/api/v1/profile/$uid/picture';
          _profileImageUrl = apiPic;
          await _fetchProfileImageBytes(uid);
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load profile: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchProfileImageBytes(String userId) async {
    try {
      final base = Uri.parse(Environment.apiBaseUrl);
      final url =
          '${base.scheme}://${base.host}:${base.port.toString()}/api/v1/profile/$userId/picture?t=${DateTime.now().millisecondsSinceEpoch}';
      final token = AuthService().accessToken;
      final headers = <String, String>{
        'Accept': 'image/*',
        if (token != null) 'Authorization': 'Bearer $token',
      };
      final resp = await http.get(Uri.parse(url), headers: headers);
      if (resp.statusCode == 200) {
        setState(() {
          _profileImageBytes = resp.bodyBytes;
        });
      }
    } catch (_) {}
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await ImagePicker().pickImage(source: source);
      if (pickedFile != null) {
        final imageBytes = await pickedFile.readAsBytes();
        setState(() {
          _profileImageBytes = imageBytes;
          if (!kIsWeb) {
            _profileImage = File(pickedFile.path);
          }
        });
        // Upload image to backend
        final result = await ProfileService.uploadProfilePicture(
            imageBytes,
            (pickedFile.name.isNotEmpty
                ? pickedFile.name
                : 'profile_picture.jpg'));
        final rawUrl = result['url']?.toString();
        if (rawUrl != null && rawUrl.isNotEmpty) {
          final base = Uri.parse(Environment.apiBaseUrl);
          try {
            final user = await AuthService().getCurrentUser();
            final uid = user?.id;
            if (uid != null && uid.isNotEmpty) {
              final apiPic =
                  '${base.scheme}://${base.host}:${base.port.toString()}/api/v1/profile/$uid/picture?t=${DateTime.now().millisecondsSinceEpoch}';
              setState(() {
                _profileImageUrl = apiPic;
              });
            } else {
              final full = rawUrl.startsWith('http')
                  ? rawUrl
                  : '${base.scheme}://${base.host}:${base.port.toString()}$rawUrl';
              setState(() {
                _profileImageUrl = full;
              });
            }
          } catch (_) {}
          await ProfileService.saveUserProfile({'profile_picture': rawUrl});
          try {
            await AuthService().refreshCurrentUser();
          } catch (_) {}
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final profileData = {
        'first_name': _firstNameController.text,
        'last_name': _lastNameController.text,
        'email': _emailController.text,
        'phone_number': _phoneController.text,
        'job_title': _titleController.text,
        'company': _departmentController.text,
        'bio': _bioController.text,
      };

      await ProfileService.saveUserProfile(profileData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved successfully')),
      );
      try {
        await AuthService().refreshCurrentUser();
      } catch (_) {}
      setState(() {
        _isEditMode = false;
      });
      await _loadProfileData();
      if (!context.mounted) return;
      context.go('/profile?mode=view');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save profile: $e')),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _titleController.dispose();
    _departmentController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AppScaffold(
        useBackgroundImage: true,
        centered: false,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return AppScaffold(
      useBackgroundImage: true,
      centered: false,
      scrollable: false,
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (!_isEditMode)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              onPressed: () {
                context.go('/profile?mode=edit');
                setState(() {
                  _isEditMode = true;
                });
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Profile Picture Section
                Stack(
                  children: [
                    Builder(builder: (context) {
                      ImageProvider<Object>? avatarImage;
                      if (_profileImageBytes != null) {
                        avatarImage = MemoryImage(_profileImageBytes!)
                            as ImageProvider<Object>;
                      } else if (_profileImageUrl != null) {
                        // Only use NetworkImage if URL looks like an image and not an API endpoint
                        if ((_profileImageUrl!.toLowerCase().contains('.jpg') ||
                                _profileImageUrl!
                                    .toLowerCase()
                                    .contains('.jpeg') ||
                                _profileImageUrl!
                                    .toLowerCase()
                                    .contains('.png') ||
                                _profileImageUrl!
                                    .toLowerCase()
                                    .contains('.gif') ||
                                _profileImageUrl!
                                    .toLowerCase()
                                    .contains('.webp')) &&
                            !_profileImageUrl!.contains('/api/v1/profile/')) {
                          avatarImage = NetworkImage(_profileImageUrl!)
                              as ImageProvider<Object>;
                        } else {
                          avatarImage =
                              null; // Don't try to load non-image URLs or API endpoints
                        }
                      } else if (_profileImage != null) {
                        avatarImage =
                            FileImage(_profileImage!) as ImageProvider<Object>;
                      } else {
                        avatarImage = null;
                      }
                      return CircleAvatar(
                        radius: 50,
                        backgroundImage: avatarImage,
                        child: avatarImage == null
                            ? const Icon(
                                Icons.person_outline,
                                size: 52,
                                color: Colors.white70,
                              )
                            : null,
                      );
                    }),
                    if (_isEditMode)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.camera_alt,
                                size: 20, color: Colors.white),
                            onPressed: () {
                              showAppModalBottomSheet(
                                context: context,
                                builder: (context) => Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.photo_library),
                                      title: const Text('Choose from Gallery'),
                                      onTap: () {
                                        Navigator.pop(context);
                                        _pickImage(ImageSource.gallery);
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.camera_alt),
                                      title: const Text('Take Photo'),
                                      onTap: () {
                                        Navigator.pop(context);
                                        _pickImage(ImageSource.camera);
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),

                // Personal Information Section
                const Text(
                  'Personal Information',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstNameController,
                        readOnly: !_isEditMode,
                        decoration: const InputDecoration(
                          labelText: 'First Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your first name';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lastNameController,
                        readOnly: !_isEditMode,
                        decoration: const InputDecoration(
                          labelText: 'Last Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your last name';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _emailController,
                  readOnly: !_isEditMode,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _phoneController,
                  readOnly: !_isEditMode,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 24),

                // Professional Information Section
                const Text(
                  'Professional Information',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _titleController,
                  readOnly: !_isEditMode,
                  decoration: const InputDecoration(
                    labelText: 'Job Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _departmentController,
                  readOnly: !_isEditMode,
                  decoration: const InputDecoration(
                    labelText: 'Department',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _bioController,
                  readOnly: !_isEditMode,
                  decoration: const InputDecoration(
                    labelText: 'Bio',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 4,
                  maxLength: 500,
                ),
                const SizedBox(height: 32),

                // Save Button
                if (_isEditMode)
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save Profile'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
