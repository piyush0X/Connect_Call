import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';

class UserService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final String _collection = 'users';

  // =========================================================
  // CREATE OR UPDATE USER
  // =========================================================

  Future<void> createUser(UserModel user) async {
    await _firestore
        .collection(_collection)
        .doc(user.uid)
        .set(
          user.toMap(),
          SetOptions(merge: true),
        );
  }

  // =========================================================
  // GET ALL USERS
  // =========================================================

  Stream<List<UserModel>> getUsers() {
    return _firestore
        .collection(_collection)
        .snapshots()
        .map(
          (snapshot) {
            return snapshot.docs
                .map(
                  (doc) => UserModel.fromMap(
                    doc.data(),
                  ),
                )
                .toList();
          },
        );
  }

  // =========================================================
  // GET ONE USER
  // =========================================================

  Future<UserModel?> getUser(String uid) async {
    final document = await _firestore
        .collection(_collection)
        .doc(uid)
        .get();

    if (!document.exists) {
      return null;
    }

    return UserModel.fromMap(
      document.data()!,
    );
  }

  // =========================================================
  // UPDATE ONLINE STATUS
  // =========================================================

  Future<void> updateOnlineStatus(
    String uid,
    bool isOnline,
  ) async {
    await _firestore
        .collection(_collection)
        .doc(uid)
        .set(
          {
            'isOnline': isOnline,
            'lastSeen': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
  }

  // =========================================================
  // UPDATE PRESENCE
  // =========================================================

  Future<void> updatePresence(
    String uid, {
    required bool isOnline,
  }) async {
    await _firestore
        .collection(_collection)
        .doc(uid)
        .set(
          {
            'isOnline': isOnline,
            'lastSeen': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
  }

  // =========================================================
  // SAVE PROFILE PHOTO
  // =========================================================

  Future<void> updateProfilePhoto(
    String uid,
    String photoBase64,
  ) async {
    await _firestore
        .collection(_collection)
        .doc(uid)
        .set(
          {
            'profileImage': photoBase64,
          },
          SetOptions(merge: true),
        );
  }

  // =========================================================
  // GET PROFILE PHOTO
  // =========================================================

  Future<String?> getProfilePhoto(
    String uid,
  ) async {
    final document = await _firestore
        .collection(_collection)
        .doc(uid)
        .get();

    if (!document.exists) {
      return null;
    }

    final data = document.data();

    if (data == null) {
      return null;
    }

    return data['profileImage'] as String?;
  }

  // =========================================================
  // REMOVE PROFILE PHOTO
  // =========================================================

  Future<void> removeProfilePhoto(
    String uid,
  ) async {
    await _firestore
        .collection(_collection)
        .doc(uid)
        .set(
          {
            'profileImage':
                FieldValue.delete(),
          },
          SetOptions(merge: true),
        );
  }

  // =========================================================
  // UPDATE PROFILE NAME
  // =========================================================

  Future<void> updateProfileName(
    String uid,
    String name,
  ) async {
    await _firestore
        .collection(_collection)
        .doc(uid)
        .set(
          {
            'name': name,
          },
          SetOptions(merge: true),
        );
  }
}