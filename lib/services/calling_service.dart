// ignore_for_file: prefer_conditional_assignment

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';

import '../core/constants/zego_config.dart';
import 'call_history_service.dart';

class CallingService {
  static final CallingService _instance =
      CallingService._internal();

  factory CallingService() {
    return _instance;
  }

  CallingService._internal();

  bool _initialized = false;

  final CallHistoryService _callHistoryService =
      CallHistoryService();

  // =========================================================
  // CURRENT USER
  // =========================================================

  String? _currentUserId;
  String? _currentUserName;

  // =========================================================
  // CALL INFORMATION
  // =========================================================

  String? _pendingCallerId;
  String? _pendingCallerName;

  String? _pendingReceiverId;
  String? _pendingReceiverName;

  String? _pendingCallType;

  String? _activeCallId;

  Stopwatch? _callStopwatch;

  // =========================================================
  // INITIALIZE
  // =========================================================

  Future<void> initialize({
    required String userId,
    required String userName,
  }) async {
    if (_initialized) {
      return;
    }

    _currentUserId = userId;
    _currentUserName = userName;

    await ZegoUIKitPrebuiltCallInvitationService().init(
      appID: ZegoConfig.appId,
      appSign: ZegoConfig.appSign,
      userID: userId,
      userName: userName,
      plugins: [
        ZegoUIKitSignalingPlugin(),
      ],

      // =====================================================
      // CALL EVENTS
      // =====================================================

      events: ZegoUIKitPrebuiltCallEvents(
        onCallEnd: (
          ZegoCallEndEvent event,
          VoidCallback defaultAction,
        ) async {
          debugPrint('================================');
          debugPrint('CALL ENDED');
          debugPrint('Call ID: ${event.callID}');
          debugPrint('Reason: ${event.reason}');
          debugPrint(
            'Kicker User ID: ${event.kickerUserID}',
          );
          debugPrint('================================');

          await _handleCallEnd(event);

          defaultAction.call();
        },
      ),

      // =====================================================
      // INVITATION EVENTS
      // =====================================================

      invitationEvents:
          ZegoUIKitPrebuiltCallInvitationEvents(

        // ---------------------------------------------------
        // INCOMING CALL RECEIVED
        // ---------------------------------------------------

        onIncomingCallReceived: (
          String callID,
          ZegoCallUser caller,
          ZegoCallInvitationType callType,
          List<ZegoCallUser> callees,
          String customData,
        ) {
          debugPrint('================================');
          debugPrint('INCOMING CALL RECEIVED');
          debugPrint('Call ID: $callID');
          debugPrint('Caller ID: ${caller.id}');
          debugPrint('Caller Name: ${caller.name}');
          debugPrint('Custom Data: $customData');
          debugPrint('================================');

          _activeCallId = callID;

          // Default information from ZEGOCLOUD.
          _pendingCallerId = caller.id;
          _pendingCallerName = caller.name;

          _pendingReceiverId = _currentUserId;
          _pendingReceiverName = _currentUserName;

          // -------------------------------------------------
          // READ CUSTOM DATA
          // -------------------------------------------------

          try {
            if (customData.isNotEmpty) {
              final decoded =
                  jsonDecode(customData)
                      as Map<String, dynamic>;

              final decodedCallerId =
                  decoded['callerId'] as String?;

              final decodedReceiverId =
                  decoded['receiverId'] as String?;

              final decodedCallType =
                  decoded['callType'] as String?;

              if (decodedCallerId != null) {
                _pendingCallerId = decodedCallerId;
              }

              if (decodedReceiverId != null) {
                _pendingReceiverId =
                    decodedReceiverId;
              }

              if (decodedCallType != null) {
                _pendingCallType = decodedCallType;
              }
            }
          } catch (e) {
            debugPrint(
              'Could not parse call custom data: $e',
            );
          }

          // -------------------------------------------------
          // FALLBACK CALL TYPE
          // -------------------------------------------------

          if (_pendingCallType == null) {
            _pendingCallType =
                callType ==
                        ZegoCallInvitationType.videoCall
                    ? 'video'
                    : 'audio';
          }

          debugPrint(
            'Incoming caller: $_pendingCallerId',
          );

          debugPrint(
            'Incoming receiver: $_pendingReceiverId',
          );

          debugPrint(
            'Incoming call type: $_pendingCallType',
          );
        },

        // ---------------------------------------------------
        // RECEIVER ACCEPTS
        // ---------------------------------------------------

        onIncomingCallAcceptButtonPressed: () {
          debugPrint('================================');
          debugPrint(
            'INCOMING CALL ACCEPT BUTTON PRESSED',
          );
          debugPrint(
            'Call ID: $_activeCallId',
          );
          debugPrint('================================');

          if (_activeCallId == null) {
            return;
          }

          _callStopwatch = Stopwatch();
          _callStopwatch!.start();

          debugPrint(
            'Incoming call timer started.',
          );
        },

        // ---------------------------------------------------
        // RECEIVER REJECTS
        // ---------------------------------------------------

        onIncomingCallDeclineButtonPressed: () async {
          debugPrint('================================');
          debugPrint(
            'INCOMING CALL DECLINED',
          );
          debugPrint(
            'Call ID: $_activeCallId',
          );
          debugPrint(
            'Caller ID: $_pendingCallerId',
          );
          debugPrint(
            'Receiver ID: $_pendingReceiverId',
          );
          debugPrint(
            'Call Type: $_pendingCallType',
          );
          debugPrint('================================');

          // -------------------------------------------------
          // SAVE REJECTED CALL
          // -------------------------------------------------

          final callID = _activeCallId;

          final callerId = _pendingCallerId;

          final callerName =
              _pendingCallerName ?? 'User';

          final receiverId = _pendingReceiverId;

          final receiverName =
              _pendingReceiverName ??
                  _currentUserName ??
                  'User';

          final callType =
              _pendingCallType ?? 'audio';

          if (callID == null) {
            debugPrint(
              'Cannot save rejected call: Call ID is missing.',
            );
            return;
          }

          if (callerId == null) {
            debugPrint(
              'Cannot save rejected call: Caller ID is missing.',
            );
            return;
          }

          if (receiverId == null) {
            debugPrint(
              'Cannot save rejected call: Receiver ID is missing.',
            );
            return;
          }

          await _saveRejectedCall(
            callID: callID,
            callerId: callerId,
            callerName: callerName,
            receiverId: receiverId,
            receiverName: receiverName,
            callType: callType,
          );

          _clearCallData();
        },

        // ---------------------------------------------------
        // CALLER CALL IS ACCEPTED
        // ---------------------------------------------------

        onOutgoingCallAccepted: (
          String callID,
          ZegoCallUser callee,
        ) {
          debugPrint('================================');
          debugPrint('OUTGOING CALL ACCEPTED');
          debugPrint('Call ID: $callID');
          debugPrint(
            'Callee ID: ${callee.id}',
          );
          debugPrint('================================');

          _activeCallId = callID;

          _callStopwatch = Stopwatch();
          _callStopwatch!.start();

          debugPrint(
            'Outgoing call timer started.',
          );
        },

        // ---------------------------------------------------
        // CALLER RECEIVES REJECTION
        // ---------------------------------------------------

        onOutgoingCallDeclined: (
          String callID,
          ZegoCallUser callee,
          String customData,
        ) async {
          debugPrint('================================');
          debugPrint('OUTGOING CALL REJECTED');
          debugPrint('Call ID: $callID');
          debugPrint(
            'Callee ID: ${callee.id}',
          );
          debugPrint(
            'Callee Name: ${callee.name}',
          );
          debugPrint(
            'Custom Data: $customData',
          );
          debugPrint('================================');

          final callerId = _pendingCallerId ??
              _currentUserId;

          final callerName =
              _pendingCallerName ??
                  _currentUserName ??
                  'User';

          final receiverId =
              _pendingReceiverId ??
                  callee.id;

          final receiverName =
              _pendingReceiverName ??
                  callee.name;

          final callType =
              _pendingCallType ?? 'audio';

          if (callerId == null) {
            debugPrint(
              'Cannot save rejected call: Caller ID is missing.',
            );
            return;
          }

          await _saveRejectedCall(
            callID: callID,
            callerId: callerId,
            callerName: callerName,
            receiverId: receiverId,
            receiverName: receiverName,
            callType: callType,
          );

          _clearCallData();
        },

        // ---------------------------------------------------
        // CALLER CANCELS BEFORE ANSWER
        // ---------------------------------------------------

        onOutgoingCallCancelButtonPressed: () async {
  debugPrint('================================');
  debugPrint(
    'OUTGOING CALL CANCELLED WHILE RINGING',
  );
  debugPrint(
    'Call ID: $_activeCallId',
  );
  debugPrint('================================');

  final callID = _activeCallId;

  final callerId =
      _pendingCallerId ?? _currentUserId;

  final callerName =
      _pendingCallerName ??
          _currentUserName ??
          'User';

  final receiverId =
      _pendingReceiverId;

  final receiverName =
      _pendingReceiverName ??
          'User';

  final callType =
      _pendingCallType ?? 'audio';

  if (callID == null) {
    debugPrint(
      'Cannot save missed call: Call ID is missing.',
    );
    return;
  }

  if (callerId == null) {
    debugPrint(
      'Cannot save missed call: Caller ID is missing.',
    );
    return;
  }

  if (receiverId == null) {
    debugPrint(
      'Cannot save missed call: Receiver ID is missing.',
    );
    return;
  }

  await _saveMissedCall(
    callID: callID,
    callerId: callerId,
    callerName: callerName,
    receiverId: receiverId,
    receiverName: receiverName,
    callType: callType,
  );

  _clearCallData();
},

        // ---------------------------------------------------
        // CALLER GETS NO ANSWER
        // ---------------------------------------------------

        onOutgoingCallTimeout: (
          String callID,
          List<ZegoCallUser> callees,
          bool isVideoCall,
        ) async {
          debugPrint('================================');
          debugPrint(
            'OUTGOING CALL TIMEOUT',
          );
          debugPrint('Call ID: $callID');
          debugPrint(
            'Video Call: $isVideoCall',
          );
          debugPrint('================================');

          final callerId =
              _currentUserId;

          if (callerId == null) {
            debugPrint(
              'Cannot save missed call: caller ID is missing.',
            );
            return;
          }

          if (callees.isEmpty) {
            debugPrint(
              'Cannot save missed call: receiver is missing.',
            );
            return;
          }

          final receiver = callees.first;

          final callType =
              isVideoCall ? 'video' : 'audio';

          await _saveMissedCall(
            callID: callID,
            callerId: callerId,
            callerName:
                _currentUserName ?? 'User',
            receiverId: receiver.id,
            receiverName: receiver.name,
            callType: callType,
          );

          _clearCallData();
        },

        // ---------------------------------------------------
        // RECEIVER DOES NOT ANSWER
        // ---------------------------------------------------

        onIncomingCallTimeout: (
          String callID,
          ZegoCallUser caller,
        ) async {
          debugPrint('================================');
          debugPrint(
            'INCOMING CALL TIMEOUT',
          );
          debugPrint('Call ID: $callID');
          debugPrint(
            'Caller ID: ${caller.id}',
          );
          debugPrint(
            'Caller Name: ${caller.name}',
          );
          debugPrint('================================');

          final receiverId =
              _currentUserId;

          if (receiverId == null) {
            debugPrint(
              'Cannot save missed call: receiver ID is missing.',
            );
            return;
          }

          // Use the metadata received with the call.
          final receiverName =
              _pendingReceiverName ??
                  _currentUserName ??
                  'User';

          final callType =
              _pendingCallType ?? 'audio';

          await _saveMissedCall(
            callID: callID,
            callerId: caller.id,
            callerName: caller.name,
            receiverId: receiverId,
            receiverName: receiverName,
            callType: callType,
          );

          _clearCallData();
        },
      ),
    );

    _initialized = true;

    debugPrint(
      'ZEGOCLOUD initialized successfully',
    );

    debugPrint(
      'User ID: $userId',
    );

    debugPrint(
      'User Name: $userName',
    );
  }

  // =========================================================
  // REGISTER OUTGOING CALL
  // =========================================================

  void registerOutgoingCall({
    required String callerId,
    required String receiverId,
    required String receiverName,
    required String callType,
  }) {
    _pendingCallerId = callerId;

    _pendingCallerName =
        _currentUserName;

    _pendingReceiverId =
        receiverId;

    _pendingReceiverName =
        receiverName;

    _pendingCallType =
        callType;

    debugPrint('================================');
    debugPrint(
      'OUTGOING CALL REGISTERED',
    );
    debugPrint(
      'Caller ID: $callerId',
    );
    debugPrint(
      'Receiver ID: $receiverId',
    );
    debugPrint(
      'Receiver Name: $receiverName',
    );
    debugPrint(
      'Call Type: $callType',
    );
    debugPrint('================================');
  }

  // =========================================================
  // SAVE REJECTED CALL
  // =========================================================

  Future<void> _saveRejectedCall({
    required String callID,
    required String callerId,
    required String callerName,
    required String receiverId,
    required String receiverName,
    required String callType,
  }) async {
    try {
      debugPrint('================================');
      debugPrint(
        'SAVING REJECTED CALL HISTORY',
      );
      debugPrint(
        'Call ID: $callID',
      );
      debugPrint(
        'Caller: $callerName ($callerId)',
      );
      debugPrint(
        'Receiver: $receiverName ($receiverId)',
      );
      debugPrint(
        'Call Type: $callType',
      );
      debugPrint('Status: rejected');
      debugPrint('================================');

      await _callHistoryService.addCallHistory(
        callId: callID,
        callerId: callerId,
        callerName: callerName,
        receiverId: receiverId,
        receiverName: receiverName,
        callType: callType,
        duration: 0,
        status: 'rejected',
      );

      debugPrint('================================');
      debugPrint(
        'REJECTED CALL HISTORY SAVED SUCCESSFULLY',
      );
      debugPrint(
        'Call ID: $callID',
      );
      debugPrint('================================');
    } catch (e) {
      debugPrint('================================');
      debugPrint(
        'FAILED TO SAVE REJECTED CALL HISTORY',
      );
      debugPrint('Error: $e');
      debugPrint('================================');
    }
  }

  // =========================================================
  // SAVE MISSED CALL
  // =========================================================

  Future<void> _saveMissedCall({
    required String callID,
    required String callerId,
    required String callerName,
    required String receiverId,
    required String receiverName,
    required String callType,
  }) async {
    try {
      debugPrint('================================');
      debugPrint(
        'SAVING MISSED CALL HISTORY',
      );
      debugPrint(
        'Call ID: $callID',
      );
      debugPrint(
        'Caller: $callerName ($callerId)',
      );
      debugPrint(
        'Receiver: $receiverName ($receiverId)',
      );
      debugPrint(
        'Call Type: $callType',
      );
      debugPrint('Duration: 0 seconds');
      debugPrint('Status: missed');
      debugPrint('================================');

      await _callHistoryService.addCallHistory(
        callId: callID,
        callerId: callerId,
        callerName: callerName,
        receiverId: receiverId,
        receiverName: receiverName,
        callType: callType,
        duration: 0,
        status: 'missed',
      );

      debugPrint('================================');
      debugPrint(
        'MISSED CALL HISTORY SAVED SUCCESSFULLY',
      );
      debugPrint(
        'Call ID: $callID',
      );
      debugPrint('================================');
    } catch (e) {
      debugPrint('================================');
      debugPrint(
        'FAILED TO SAVE MISSED CALL HISTORY',
      );
      debugPrint('Error: $e');
      debugPrint('================================');
    }
  }

  // =========================================================
  // HANDLE COMPLETED CALL
  // =========================================================

  Future<void> _handleCallEnd(
    ZegoCallEndEvent event,
  ) async {
    if (_activeCallId == null) {
      debugPrint(
        'No active call found.',
      );

      return;
    }

    if (_pendingCallerId == null ||
        _pendingReceiverId == null ||
        _pendingCallType == null) {
      debugPrint(
        'Call metadata is missing.',
      );

      _clearCallData();

      return;
    }

    _callStopwatch?.stop();

    final duration =
        _callStopwatch?.elapsed.inSeconds ?? 0;

    final callerId =
        _pendingCallerId!;

    final receiverId =
        _pendingReceiverId!;

    final callType =
        _pendingCallType!;

    final callerName =
        _pendingCallerName ?? 'User';

    final receiverName =
        _pendingReceiverName ?? 'User';

    debugPrint('================================');
    debugPrint(
      'PREPARING CALL HISTORY',
    );
    debugPrint(
      'Caller: $callerId',
    );
    debugPrint(
      'Receiver: $receiverId',
    );
    debugPrint(
      'Call Type: $callType',
    );
    debugPrint(
      'Duration: $duration seconds',
    );
    debugPrint(
      'Current User: $_currentUserId',
    );
    debugPrint('================================');

    final isParticipant =
        _currentUserId == callerId ||
            _currentUserId == receiverId;

    if (!isParticipant) {
      debugPrint(
        'Current user is not part of this call.',
      );

      _clearCallData();

      return;
    }

    try {
      await _callHistoryService.addCallHistory(
        callId: event.callID,
        callerId: callerId,
        callerName: callerName,
        receiverId: receiverId,
        receiverName: receiverName,
        callType: callType,
        duration: duration,
        status: 'completed',
      );

      debugPrint('================================');
      debugPrint(
        'CALL HISTORY SAVED',
      );
      debugPrint(
        'Call ID: ${event.callID}',
      );
      debugPrint(
        'Call Type: $callType',
      );
      debugPrint(
        'Duration: $duration seconds',
      );
      debugPrint(
        'Current User: $_currentUserId',
      );
      debugPrint(
        'Status: completed',
      );
      debugPrint('================================');
    } catch (e) {
      debugPrint(
        'Failed to save call history: $e',
      );
    }

    _clearCallData();
  }

  // =========================================================
  // CLEAR CALL DATA
  // =========================================================

  void _clearCallData() {
    _pendingCallerId = null;
    _pendingCallerName = null;

    _pendingReceiverId = null;
    _pendingReceiverName = null;

    _pendingCallType = null;

    _activeCallId = null;

    _callStopwatch?.stop();
    _callStopwatch = null;
  }

  // =========================================================
  // DISPOSE
  // =========================================================

  Future<void> dispose() async {
    if (!_initialized) {
      return;
    }

    await ZegoUIKitPrebuiltCallInvitationService()
        .uninit();

    _initialized = false;

    _clearCallData();

    debugPrint(
      'ZEGOCLOUD disposed successfully',
    );
  }
}