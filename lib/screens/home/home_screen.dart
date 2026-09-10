import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/call_history_service.dart';
import '../../services/user_service.dart';

import '../auth/login_screen.dart';
import '../contacts/contacts_screen.dart';
import '../history/history_screen.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState
    extends State<HomeScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;

  // =========================================================
  // PRESENCE
  // =========================================================

  Timer? _presenceTimer;

  bool _presenceInitialized = false;

  // =========================================================
  // INIT
  // =========================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _startPresence();
  }

  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _presenceTimer?.cancel();
    _presenceTimer = null;

    super.dispose();
  }

  // =========================================================
  // APP LIFECYCLE
  // =========================================================

  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    if (state == AppLifecycleState.resumed) {
      _startPresence();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopPresence();

      _setOffline();
    }
  }

  // =========================================================
  // START PRESENCE
  // =========================================================

  void _startPresence() {
    // Prevent multiple timers.
    _presenceTimer?.cancel();

    // Immediately mark the user online.
    _setOnline();

    // Refresh presence every 5 seconds.
    _presenceTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) {
        _setOnline();
      },
    );
  }

  // =========================================================
  // STOP PRESENCE
  // =========================================================

  void _stopPresence() {
    _presenceTimer?.cancel();
    _presenceTimer = null;
  }

  // =========================================================
  // SET USER ONLINE
  // =========================================================

  Future<void> _setOnline() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    try {
      await UserService().updateOnlineStatus(
        user.uid,
        true,
      );

      _presenceInitialized = true;

      debugPrint(
        'User is ONLINE: ${user.uid}',
      );
    } catch (e) {
      debugPrint(
        'Failed to set user online: $e',
      );
    }
  }

  // =========================================================
  // SET USER OFFLINE
  // =========================================================

  Future<void> _setOffline() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || !_presenceInitialized) {
      return;
    }

    try {
      await UserService().updateOnlineStatus(
        user.uid,
        false,
      );

      debugPrint(
        'User is OFFLINE: ${user.uid}',
      );
    } catch (e) {
      debugPrint(
        'Failed to set user offline: $e',
      );
    }
  }

  // =========================================================
  // SCREENS
  // =========================================================

  final List<Widget> _screens = const [
    HomeContent(),
    ContactsScreen(),
    HistoryScreen(),
    ProfileScreen(),
  ];

  // =========================================================
  // LOGOUT
  // =========================================================

  Future<void> _logout() async {
    // Stop heartbeat before logout.
    _stopPresence();

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        try {
          await UserService().updateOnlineStatus(
            user.uid,
            false,
          );
        } catch (e) {
          debugPrint(
            'Could not update offline status: $e',
          );
        }
      }
    } finally {
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        ),
        (route) => false,
      );
    }
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ConnectCall'),
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),

      // Current selected screen.
      body: _screens[_currentIndex],

      // Bottom navigation.
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,

        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },

        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Contacts',
          ),
          NavigationDestination(
            icon: Icon(Icons.call_outlined),
            selectedIcon: Icon(Icons.call),
            label: 'Calls',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// =============================================================
// HOME CONTENT
// =============================================================

class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    final name = user?.displayName?.isNotEmpty == true
        ? user!.displayName!
        : 'User';

    if (user == null) {
      return const Center(
        child: Text('Please login again.'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          // ===================================================
          // GREETING
          // ===================================================

          Text(
            'Hello, $name 👋',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Connect with your friends and family.',
            style: TextStyle(
              fontSize: 16,
            ),
          ),

          const SizedBox(height: 30),

          // ===================================================
          // SEARCH
          // ===================================================

          TextField(
            readOnly: true,
            onTap: () {
              ScaffoldMessenger.of(context)
                  .showSnackBar(
                const SnackBar(
                  content: Text(
                    'Go to Contacts to search for people.',
                  ),
                ),
              );
            },
            decoration: InputDecoration(
              hintText: 'Search people...',
              prefixIcon:
                  const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(16),
              ),
            ),
          ),

          const SizedBox(height: 30),

          // ===================================================
          // RECENT CALLS
          // ===================================================

          const Text(
            'Recent Calls',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          _RecentCalls(
            userId: user.uid,
          ),
        ],
      ),
    );
  }
}

// =============================================================
// RECENT CALLS
// =============================================================

class _RecentCalls extends StatelessWidget {
  final String userId;

  const _RecentCalls({
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    final callHistoryService =
        CallHistoryService();

    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream:
          callHistoryService.getCallHistory(
        userId,
      ),
      builder: (context, snapshot) {
        // =====================================================
        // LOADING
        // =====================================================

        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(30),
              child:
                  CircularProgressIndicator(),
            ),
          );
        }

        // =====================================================
        // ERROR
        // =====================================================

        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding:
                  const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 40,
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    'Unable to load recent calls.',
                    textAlign:
                        TextAlign.center,
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'Please check your internet connection.',
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      color:
                          Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // =====================================================
        // GET CALLS
        // =====================================================

        final documents =
            snapshot.data?.docs ?? [];

        if (documents.isEmpty) {
          return Card(
            child: Padding(
              padding:
                  const EdgeInsets.all(30),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons
                          .phone_disabled_outlined,
                      size: 45,
                      color:
                          Colors.grey.shade500,
                    ),

                    const SizedBox(height: 12),

                    Text(
                      'No recent calls',
                      style: TextStyle(
                        color:
                            Colors.grey.shade600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // =====================================================
        // SORT LOCALLY
        // =====================================================

        final sortedDocuments =
            List<QueryDocumentSnapshot<
                Map<String, dynamic>>>.from(
          documents,
        );

        sortedDocuments.sort((a, b) {
          final aTimestamp =
              a.data()['timestamp'];

          final bTimestamp =
              b.data()['timestamp'];

          if (aTimestamp is Timestamp &&
              bTimestamp is Timestamp) {
            return bTimestamp.compareTo(
              aTimestamp,
            );
          }

          if (aTimestamp is Timestamp) {
            return -1;
          }

          if (bTimestamp is Timestamp) {
            return 1;
          }

          return 0;
        });

        // Show only latest 3 calls.
        final recentCalls =
            sortedDocuments.take(3).toList();

        // =====================================================
        // DISPLAY
        // =====================================================

        return Column(
          children: recentCalls.map((document) {
            final data = document.data();

            return _RecentCallTile(
              userId: userId,
              data: data,
            );
          }).toList(),
        );
      },
    );
  }
}

// =============================================================
// RECENT CALL TILE
// =============================================================

class _RecentCallTile extends StatelessWidget {
  final String userId;
  final Map<String, dynamic> data;

  const _RecentCallTile({
    required this.userId,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final callerId =
        data['callerId'] as String? ?? '';

    final callerName =
        data['callerName'] as String? ??
            'User';

    final receiverName =
        data['receiverName'] as String? ??
            'User';

    final callType =
        data['callType'] as String? ??
            'audio';

    final status =
        data['status'] as String? ??
            'completed';

    final duration =
        data['duration'] as int? ?? 0;

    final timestamp =
        data['timestamp'];

    final isOutgoing =
        callerId == userId;

    final otherUserName = isOutgoing
        ? receiverName
        : callerName;

    final callIcon =
        callType == 'video'
            ? Icons.videocam
            : Icons.call;

    IconData statusIcon;

    Color statusColor;

    String statusText;

    switch (status) {
      case 'rejected':
        statusIcon = Icons.call_end;
        statusColor = Colors.red;
        statusText = 'Rejected';
        break;

      case 'missed':
        statusIcon =
            Icons.phone_missed;
        statusColor = Colors.orange;
        statusText = 'Missed Call';
        break;

      default:
        statusIcon = isOutgoing
            ? Icons.call_made
            : Icons.call_received;
        statusColor = Colors.green;
        statusText = 'Completed';
    }

    String timeText = '';

    if (timestamp is Timestamp) {
      final date =
          timestamp.toDate();

      timeText =
          '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year}';
    }

    return Card(
      margin:
          const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(callIcon),
        ),

        title: Text(
          otherUserName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),

        subtitle: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),

            Row(
              children: [
                Icon(
                  statusIcon,
                  size: 16,
                  color: statusColor,
                ),

                const SizedBox(width: 5),

                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight:
                        FontWeight.w500,
                  ),
                ),

                const SizedBox(width: 8),

                Text(
                  callType == 'video'
                      ? 'Video'
                      : 'Audio',
                ),
              ],
            ),

            const SizedBox(height: 3),

            Text(
              status == 'completed'
                  ? '$duration sec • $timeText'
                  : timeText,
              style: TextStyle(
                color:
                    Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),

        isThreeLine: true,
      ),
    );
  }
}