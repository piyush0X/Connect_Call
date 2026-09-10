import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../../services/user_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() =>
      _ProfileScreenState();
}

class _ProfileScreenState
    extends State<ProfileScreen> {
  final UserService _userService =
      UserService();

  final ImagePicker _imagePicker =
      ImagePicker();

  String? _profilePhoto;

  String _name = 'User';
  String _email = 'No email';

  bool _isLoading = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // =========================================================
  // LOAD PROFILE
  // =========================================================

  Future<void> _loadProfile() async {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final document =
          await _userService.getProfilePhoto(
        user.uid,
      );

      final userData =
          await _getUserData(user.uid);

      if (!mounted) return;

      setState(() {
        _profilePhoto = document;

        _name = userData?['name'] as String? ??
            user.displayName ??
            'User';

        _email =
            user.email ?? 'No email';

        _isLoading = false;
      });
    } catch (e) {
      debugPrint(
        'Failed to load profile: $e',
      );

      if (!mounted) return;

      setState(() {
        _name =
            user.displayName ?? 'User';
        _email =
            user.email ?? 'No email';
        _isLoading = false;
      });
    }
  }

  // =========================================================
  // GET USER DATA
  // =========================================================

  Future<Map<String, dynamic>?> _getUserData(
    String uid,
  ) async {
    try {
      final user =
          FirebaseAuth.instance.currentUser;

      if (user == null) {
        return null;
      }

      final snapshot =
          await _userService
              .getProfilePhoto(uid);

      // Photo is handled separately.
      // Return null here if no extra data is needed.
      return null;
    } catch (e) {
      debugPrint(
        'Failed to get user data: $e',
      );
      return null;
    }
  }

  // =========================================================
  // PICK PROFILE PHOTO
  // =========================================================

  Future<void> _pickProfilePhoto() async {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    try {
      final XFile? image =
          await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (image == null) {
        return;
      }

      setState(() {
        _isUploading = true;
      });

      final bytes =
          await image.readAsBytes();

      // Compress and resize image.
      final compressedBytes =
          _compressImage(bytes);

      if (compressedBytes == null) {
        throw Exception(
          'Unable to process image.',
        );
      }

      final base64Image =
          base64Encode(compressedBytes);

      await _userService.updateProfilePhoto(
        user.uid,
        base64Image,
      );

      if (!mounted) return;

      setState(() {
        _profilePhoto = base64Image;
        _isUploading = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Profile photo updated successfully.',
          ),
        ),
      );
    } catch (e) {
      debugPrint(
        'Profile photo upload failed: $e',
      );

      if (!mounted) return;

      setState(() {
        _isUploading = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Unable to update profile photo: $e',
          ),
        ),
      );
    }
  }

  // =========================================================
  // COMPRESS IMAGE
  // =========================================================

  Uint8List? _compressImage(
    Uint8List bytes,
  ) {
    final original =
        img.decodeImage(bytes);

    if (original == null) {
      return null;
    }

    final resized =
        img.copyResize(
      original,
      width: 500,
      height: 500,
    );

    return Uint8List.fromList(
      img.encodeJpg(
        resized,
        quality: 60,
      ),
    );
  }

  // =========================================================
  // REMOVE PHOTO
  // =========================================================

  Future<void> _removePhoto() async {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    try {
      await _userService.removeProfilePhoto(
        user.uid,
      );

      if (!mounted) return;

      setState(() {
        _profilePhoto = null;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Profile photo removed.',
          ),
        ),
      );
    } catch (e) {
      debugPrint(
        'Failed to remove profile photo: $e',
      );
    }
  }

  // =========================================================
  // EDIT NAME
  // =========================================================

  Future<void> _editName() async {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    final controller =
        TextEditingController(
      text: _name,
    );

    final newName =
        await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Edit Profile',
          ),
          content: TextField(
            controller: controller,
            textCapitalization:
                TextCapitalization.words,
            decoration:
                const InputDecoration(
              labelText: 'Name',
              border:
                  OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child:
                  const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name =
                    controller.text.trim();

                if (name.isNotEmpty) {
                  Navigator.pop(
                    context,
                    name,
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (newName == null ||
        newName.isEmpty) {
      return;
    }

    try {
      await user.updateDisplayName(
        newName,
      );

      await _userService.updateProfileName(
        user.uid,
        newName,
      );

      if (!mounted) return;

      setState(() {
        _name = newName;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Profile updated successfully.',
          ),
        ),
      );
    } catch (e) {
      debugPrint(
        'Failed to update profile name: $e',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to update profile.',
          ),
        ),
      );
    }
  }

  // =========================================================
  // PROFILE PHOTO MENU
  // =========================================================

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.photo_library,
                ),
                title: const Text(
                  'Choose from Gallery',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickProfilePhoto();
                },
              ),
              if (_profilePhoto != null)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline,
                  ),
                  title: const Text(
                    'Remove Photo',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _removePhoto();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    final initial = _name
        .trim()
        .isNotEmpty
        ? _name
            .trim()
            .substring(0, 1)
            .toUpperCase()
        : 'U';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),

          // =================================================
          // PROFILE PHOTO
          // =================================================

          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 65,
                backgroundImage:
                    _profilePhoto != null
                        ? MemoryImage(
                            base64Decode(
                              _profilePhoto!,
                            ),
                          )
                        : null,
                child:
                    _profilePhoto == null
                        ? Text(
                            initial,
                            style:
                                const TextStyle(
                              fontSize: 48,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          )
                        : null,
              ),

              if (_isUploading)
                const Positioned.fill(
                  child: Center(
                    child:
                        CircularProgressIndicator(),
                  ),
                ),

              Material(
                shape:
                    const CircleBorder(),
                child: InkWell(
                  onTap:
                      _isUploading
                          ? null
                          : _showPhotoOptions,
                  customBorder:
                      const CircleBorder(),
                  child:
                      const Padding(
                    padding:
                        EdgeInsets.all(10),
                    child: Icon(
                      Icons.camera_alt,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // =================================================
          // NAME
          // =================================================

          Text(
            _name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(height: 6),

          // =================================================
          // EMAIL
          // =================================================

          Text(
            _email,
            style: TextStyle(
              fontSize: 15,
              color:
                  Colors.grey.shade600,
            ),
          ),

          const SizedBox(height: 30),

          // =================================================
          // ACCOUNT INFORMATION
          // =================================================

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.person_outline,
                  ),
                  title:
                      const Text('Name'),
                  subtitle:
                      Text(_name),
                ),
                const Divider(
                  height: 1,
                ),
                ListTile(
                  leading: const Icon(
                    Icons.email_outlined,
                  ),
                  title:
                      const Text('Email'),
                  subtitle:
                      Text(_email),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // =================================================
          // EDIT PROFILE
          // =================================================

          SizedBox(
            width: double.infinity,
            child:
                OutlinedButton.icon(
              onPressed: _editName,
              icon: const Icon(
                Icons.edit_outlined,
              ),
              label: const Text(
                'Edit Profile',
              ),
            ),
          ),

          const SizedBox(height: 12),

          // =================================================
          // PHOTO BUTTON
          // =================================================

          SizedBox(
            width: double.infinity,
            child:
                OutlinedButton.icon(
              onPressed:
                  _showPhotoOptions,
              icon: const Icon(
                Icons.camera_alt_outlined,
              ),
              label: Text(
                _profilePhoto == null
                    ? 'Add Profile Photo'
                    : 'Change Profile Photo',
              ),
            ),
          ),
        ],
      ),
    );
  }
}