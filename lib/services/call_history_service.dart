import 'package:cloud_firestore/cloud_firestore.dart';

class CallHistoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> addCallHistory({
  required String callId,
  required String callerId,
  required String callerName,
  required String receiverId,
  required String receiverName,
  required String callType,
  required int duration,
  required String status,
}) async {
  await _firestore
      .collection('call_history')
      .doc(callId)
      .set({
    'callId': callId,
    'callerId': callerId,
    'callerName': callerName,
    'receiverId': receiverId,
    'receiverName': receiverName,
    'callType': callType,
    'timestamp': FieldValue.serverTimestamp(),
    'duration': duration,
    'status': status,
  });
}

  Stream<QuerySnapshot<Map<String, dynamic>>> getCallHistory(
    String userId,
  ) {
    
  return _firestore
      .collection('call_history')
      .where(
        Filter.or(
          Filter('callerId', isEqualTo: userId),
          Filter('receiverId', isEqualTo: userId),
        ),
      )
      .snapshots();
}
  }
