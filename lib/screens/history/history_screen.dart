import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/call_history_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final CallHistoryService _callHistoryService =
      CallHistoryService();

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final Map<String, String> _userNames = {};

  // =========================================================
  // FORMAT DURATION
  // =========================================================

  String _formatDuration(int seconds) {
    if (seconds < 60) {
      return '${seconds}s';
    }

    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;

    if (remainingSeconds == 0) {
      return '${minutes}m';
    }

    return '${minutes}m ${remainingSeconds}s';
  }

  // =========================================================
  // FORMAT DATE
  // =========================================================

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) {
      return 'Just now';
    }

    final date = timestamp.toDate();

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    final hour = date.hour > 12
        ? date.hour - 12
        : date.hour == 0
            ? 12
            : date.hour;

    final minute = date.minute.toString().padLeft(2, '0');

    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '$day/$month/$year • $hour:$minute $period';
  }

  // =========================================================
  // GET USER NAME
  // =========================================================

  Future<String> _getUserName(String userId) async {
    // Check cache first.
    if (_userNames.containsKey(userId)) {
      return _userNames[userId]!;
    }

    try {
      final document = await _firestore
          .collection('users')
          .doc(userId)
          .get();

      if (document.exists) {
        final data = document.data();

        final name = data?['name'] as String?;

        if (name != null && name.trim().isNotEmpty) {
          _userNames[userId] = name;
          return name;
        }
      }
    } catch (e) {
      debugPrint(
        'Failed to get user name: $e',
      );
    }

    return 'Unknown user';
  }

  // =========================================================
  // STATUS TEXT
  // =========================================================

  String _getStatusText(String status) {
    switch (status) {
      case 'completed':
        return 'Completed';

      case 'rejected':
        return 'Rejected';

      case 'missed':
        return 'Missed Call';

      default:
        return status.isNotEmpty
            ? status[0].toUpperCase() + status.substring(1)
            : 'Unknown';
    }
  }

  // =========================================================
  // STATUS ICON
  // =========================================================

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'completed':
        return Icons.check_circle;

      case 'rejected':
        return Icons.call_end;

      case 'missed':
        return Icons.phone_missed;

      default:
        return Icons.info_outline;
    }
  }

  // =========================================================
  // STATUS COLOR
  // =========================================================

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;

      case 'rejected':
        return Colors.red;

      case 'missed':
        return Colors.orange;

      default:
        return Colors.grey;
    }
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final currentUser =
        FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Center(
        child: Text(
          'Please login to view call history.',
        ),
      );
    }

    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: _callHistoryService.getCallHistory(
        currentUser.uid,
      ),
      builder: (context, snapshot) {
        // =====================================================
        // LOADING
        // =====================================================

        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        // =====================================================
        // ERROR
        // =====================================================

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 60,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Unable to load call history.',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        // =====================================================
        // GET DOCUMENTS
        // =====================================================

        final documents =
            List<QueryDocumentSnapshot<
                Map<String, dynamic>>>.from(
          snapshot.data?.docs ?? [],
        );

        // =====================================================
        // SORT NEWEST FIRST
        // =====================================================

        documents.sort((a, b) {
          final timestampA =
              a.data()['timestamp'] as Timestamp?;

          final timestampB =
              b.data()['timestamp'] as Timestamp?;

          if (timestampA == null &&
              timestampB == null) {
            return 0;
          }

          if (timestampA == null) {
            return 1;
          }

          if (timestampB == null) {
            return -1;
          }

          return timestampB.compareTo(timestampA);
        });

        // =====================================================
        // EMPTY HISTORY
        // =====================================================

        if (documents.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history,
                  size: 70,
                ),
                SizedBox(height: 16),
                Text(
                  'No call history',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Your calls will appear here.',
                ),
              ],
            ),
          );
        }

        // =====================================================
        // HISTORY LIST
        // =====================================================

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: documents.length,
          separatorBuilder: (context, index) {
            return const SizedBox(height: 8);
          },
          itemBuilder: (context, index) {
            final data = documents[index].data();

            final callerId =
                data['callerId'] as String? ?? '';

            final receiverId =
                data['receiverId'] as String? ?? '';

            final callType =
                data['callType'] as String? ?? 'audio';

            final status =
                data['status'] as String? ?? 'completed';

            final duration =
                (data['duration'] as num?)?.toInt() ?? 0;

            final timestamp =
                data['timestamp'] as Timestamp?;

            // -------------------------------------------------
            // CALL DIRECTION
            // -------------------------------------------------

            final isOutgoing =
                callerId == currentUser.uid;

            final otherUserId = isOutgoing
                ? receiverId
                : callerId;

            final isVideoCall =
                callType == 'video';

            // -------------------------------------------------
            // STATUS INFORMATION
            // -------------------------------------------------

            final statusText =
                _getStatusText(status);

            final statusIcon =
                _getStatusIcon(status);

            final statusColor =
                _getStatusColor(status);

            return FutureBuilder<String>(
              future: _getUserName(otherUserId),
              builder: (
                context,
                nameSnapshot,
              ) {
                final userName =
                    nameSnapshot.data ??
                        'Loading...';

                return Card(
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),

                    // =================================================
                    // CALL ICON
                    // =================================================

                    leading: CircleAvatar(
                      radius: 27,
                      child: Icon(
                        isVideoCall
                            ? Icons.videocam
                            : Icons.phone,
                      ),
                    ),

                    // =================================================
                    // USER NAME
                    // =================================================

                    title: Text(
                      userName,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight:
                            FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),

                    // =================================================
                    // CALL DETAILS
                    // =================================================

                    subtitle: Padding(
                      padding:
                          const EdgeInsets.only(
                        top: 6,
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          // -------------------------------------------------
                          // DIRECTION + CALL TYPE
                          // -------------------------------------------------

                          Row(
                            children: [
                              Icon(
                                isOutgoing
                                    ? Icons.call_made
                                    : Icons.call_received,
                                size: 16,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                isOutgoing
                                    ? 'Outgoing'
                                    : 'Incoming',
                              ),
                              const SizedBox(width: 10),
                              Text(
                                isVideoCall
                                    ? 'Video'
                                    : 'Audio',
                              ),
                            ],
                          ),

                          const SizedBox(height: 4),

                          // -------------------------------------------------
                          // DURATION
                          // -------------------------------------------------

                          Text(
                            'Duration: '
                            '${_formatDuration(duration)}',
                          ),

                          const SizedBox(height: 4),

                          // -------------------------------------------------
                          // DATE
                          // -------------------------------------------------

                          Text(
                            _formatDate(timestamp),
                          ),
                        ],
                      ),
                    ),

                    // =================================================
                    // STATUS
                    // =================================================

                    trailing: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Icon(
                          statusIcon,
                          size: 20,
                          color: statusColor,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}