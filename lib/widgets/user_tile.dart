import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit/zego_uikit.dart';

import '../models/user_model.dart';
import '../services/calling_service.dart';
import '../services/permission_service.dart';

class UserTile extends StatelessWidget {
  final UserModel user;

  UserTile({
    super.key,
    required this.user,
  });

  final CallingService _callingService = CallingService();

  // =========================================================
  // GET CURRENT USER ID
  // =========================================================

  String? get _callerId {
    return FirebaseAuth.instance.currentUser?.uid;
  }

  // =========================================================
  // AUDIO CALL DATA
  // =========================================================

  String _audioCallData(String callerId) {
    return jsonEncode({
      'callerId': callerId,
      'receiverId': user.uid,
      'callType': 'audio',
    });
  }

  // =========================================================
  // VIDEO CALL DATA
  // =========================================================

  String _videoCallData(String callerId) {
    return jsonEncode({
      'callerId': callerId,
      'receiverId': user.uid,
      'callType': 'video',
    });
  }

  // =========================================================
  // CHECK PERMISSIONS
  // =========================================================

  Future<bool> _checkPermissions(
    BuildContext context, {
    required bool isVideoCall,
  }) async {
    final granted =
        await PermissionService.requestCallPermissions(
      isVideoCall: isVideoCall,
    );

    if (granted) {
      return true;
    }

    if (!context.mounted) {
      return false;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isVideoCall
              ? 'Camera and microphone permission are required for video calls.'
              : 'Microphone permission is required for audio calls.',
        ),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'SETTINGS',
          onPressed: () {
            PermissionService.openSettings();
          },
        ),
      ),
    );

    return false;
  }

  // =========================================================
  // SHOW CALL ERROR
  // =========================================================

  void _showCallError(
    BuildContext context, {
    required String callType,
    required String code,
    required String message,
    required List<String> errorInvitees,
  }) {
    if (!context.mounted) {
      return;
    }

    debugPrint('================================');
    debugPrint('CALL ERROR');
    debugPrint('Call Type: $callType');
    debugPrint('Code: $code');
    debugPrint('Message: $message');
    debugPrint('Error Invitees: $errorInvitees');
    debugPrint('================================');

    final lowerMessage = message.toLowerCase();

    String userMessage;

    if (lowerMessage.contains('network') ||
        lowerMessage.contains('internet') ||
        lowerMessage.contains('connection')) {
      userMessage =
          'Please check your internet connection and try again.';
    } else if (errorInvitees.isNotEmpty) {
      userMessage =
          'Unable to reach ${user.name}. Please try again later.';
    } else if (lowerMessage.contains('busy')) {
      userMessage =
          '${user.name} is currently busy.';
    } else if (message.trim().isNotEmpty) {
      userMessage =
          '$callType call failed. Please try again.';
    } else {
      userMessage =
          'Unable to start the $callType call. Please try again.';
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(userMessage),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'RETRY',
          onPressed: () {
            debugPrint(
              'Retry requested for $callType call.',
            );
          },
        ),
      ),
    );
  }

  // =========================================================
  // SHOW CALL STARTED MESSAGE
  // =========================================================

  void _showCallStarted(
    BuildContext context, {
    required String message,
  }) {
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final callerId = _callerId;

    // =========================================================
    // REAL ONLINE STATUS
    // =========================================================
    //
    // A user is considered online only when:
    //
    // 1. Firestore says isOnline == true
    // 2. lastSeen exists
    // 3. lastSeen was updated within the last 45 seconds
    //
    // This prevents an old "true" value from showing
    // the user as online forever.
    // =========================================================

    final isActuallyOnline =
        user.isOnline &&
        user.lastSeen != null &&
        DateTime.now()
                .difference(user.lastSeen!)
                .inSeconds <=
            45;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // =================================================
            // PROFILE PICTURE
            // =================================================

            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage:
                      user.profileImage != null &&
                              user.profileImage!.isNotEmpty
                          ? NetworkImage(
                              user.profileImage!,
                            )
                          : null,
                  child:
                      user.profileImage == null ||
                              user.profileImage!.isEmpty
                          ? Text(
                              user.name.isNotEmpty
                                  ? user.name[0]
                                      .toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            )
                          : null,
                ),

                // =================================================
                // ONLINE INDICATOR
                // =================================================

                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActuallyOnline
                          ? Colors.green
                          : Colors.grey,
                      border: Border.all(
                        color: Theme.of(context)
                            .scaffoldBackgroundColor,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(width: 14),

            // =================================================
            // USER INFORMATION
            // =================================================

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 4),

                  Text(
                    isActuallyOnline
                        ? 'Online'
                        : 'Offline',
                    style: TextStyle(
                      fontSize: 13,
                      color: isActuallyOnline
                          ? Colors.green
                          : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

            // =================================================
            // AUDIO CALL BUTTON
            // =================================================

            ZegoSendCallInvitationButton(
              invitees: [
                ZegoUIKitUser(
                  id: user.uid,
                  name: user.name,
                ),
              ],

              isVideoCall: false,

              customData: callerId != null
                  ? _audioCallData(callerId)
                  : '',

              timeoutSeconds: 60,

              buttonSize:
                  const Size(46, 46),

              iconSize:
                  const Size(24, 24),

              iconVisible: true,
              verticalLayout: false,

              text: '',
              iconTextSpacing: 0,

              // =================================================
              // CHECK MICROPHONE PERMISSION
              // =================================================

              onWillPressed: () async {
                return await _checkPermissions(
                  context,
                  isVideoCall: false,
                );
              },

              // =================================================
              // AUDIO CALL RESULT
              // =================================================

              onPressed: (
                String code,
                String message,
                List<String> errorInvitees,
              ) {
                debugPrint(
                  '========== AUDIO CALL ==========',
                );

                debugPrint('Code: $code');
                debugPrint('Message: $message');
                debugPrint(
                  'Error Invitees: $errorInvitees',
                );

                if (callerId == null) {
                  debugPrint(
                    'Audio call failed: current user not found.',
                  );

                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Please login again before making a call.',
                        ),
                      ),
                    );
                  }

                  return;
                }

                // =================================================
                // CALL FAILED
                // =================================================

                if (code.isNotEmpty) {
                  _showCallError(
                    context,
                    callType: 'Audio',
                    code: code,
                    message: message,
                    errorInvitees: errorInvitees,
                  );

                  return;
                }

                // =================================================
                // CALL SUCCESSFULLY SENT
                // =================================================

                _callingService
                    .registerOutgoingCall(
                  callerId: callerId,
                  receiverId: user.uid,
                  receiverName: user.name,
                  callType: 'audio',
                );

                _showCallStarted(
                  context,
                  message:
                      'Calling ${user.name}...',
                );
              },
            ),

            // =================================================
            // VIDEO CALL BUTTON
            // =================================================

            ZegoSendCallInvitationButton(
              invitees: [
                ZegoUIKitUser(
                  id: user.uid,
                  name: user.name,
                ),
              ],

              isVideoCall: true,

              customData: callerId != null
                  ? _videoCallData(callerId)
                  : '',

              timeoutSeconds: 60,

              buttonSize:
                  const Size(46, 46),

              iconSize:
                  const Size(24, 24),

              iconVisible: true,
              verticalLayout: false,

              text: '',
              iconTextSpacing: 0,

              // =================================================
              // CHECK MICROPHONE + CAMERA PERMISSION
              // =================================================

              onWillPressed: () async {
                return await _checkPermissions(
                  context,
                  isVideoCall: true,
                );
              },

              // =================================================
              // VIDEO CALL RESULT
              // =================================================

              onPressed: (
                String code,
                String message,
                List<String> errorInvitees,
              ) {
                debugPrint(
                  '========== VIDEO CALL ==========',
                );

                debugPrint('Code: $code');
                debugPrint('Message: $message');
                debugPrint(
                  'Error Invitees: $errorInvitees',
                );

                if (callerId == null) {
                  debugPrint(
                    'Video call failed: current user not found.',
                  );

                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Please login again before making a call.',
                        ),
                      ),
                    );
                  }

                  return;
                }

                // =================================================
                // CALL FAILED
                // =================================================

                if (code.isNotEmpty) {
                  _showCallError(
                    context,
                    callType: 'Video',
                    code: code,
                    message: message,
                    errorInvitees: errorInvitees,
                  );

                  return;
                }

                // =================================================
                // CALL SUCCESSFULLY SENT
                // =================================================

                _callingService
                    .registerOutgoingCall(
                  callerId: callerId,
                  receiverId: user.uid,
                  receiverName: user.name,
                  callType: 'video',
                );

                _showCallStarted(
                  context,
                  message:
                      'Video calling ${user.name}...',
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}