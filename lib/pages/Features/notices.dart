import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:presence_point_2/pages/admin_home_page.dart';
import 'package:presence_point_2/services/notices_service.dart';
import 'package:provider/provider.dart';
import 'package:presence_point_2/services/user_state.dart';

class NoticesPage extends StatefulWidget {
  const NoticesPage({super.key});

  @override
  State<NoticesPage> createState() => _NoticesPageState();
}

class _NoticesPageState extends State<NoticesPage> {
  final NoticeService noticeService = NoticeService();
  // Key to force refresh FutureBuilders
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  // Keys for both list views to refresh them
  final GlobalKey _allNoticesKey = GlobalKey();
  final GlobalKey _importantNoticesKey = GlobalKey();

  // Future instances that can be refreshed
  late Future<List<Map<String, dynamic>>> _allNoticesFuture;
  late Future<List<Map<String, dynamic>>> _importantNoticesFuture;

  @override
  void initState() {
    super.initState();
    _refreshNotices();
  }

  // Method to refresh both notice lists
  void _refreshNotices() {
    setState(() {
      _allNoticesFuture = noticeService.getNotices();
      _importantNoticesFuture = noticeService.getNotices(isImportant: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Get access to the UserState
    final userState = Provider.of<UserState>(context);

    return DefaultTabController(
      length: 2,
      child: PopScope(
        canPop: false, // Set to false to manually handle popping
        onPopInvoked: (didPop) {
          if (didPop) return;
          Navigator.of(context).pop();
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Company Notices'),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'All Notices'),
                Tab(text: 'Important'),
              ],
            ),
            actions: [
              // Only show add button if user is admin
              if (userState.isAdmin)
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _showCreateNoticeDialog(context),
                ),
            ],
          ),
          body: RefreshIndicator(
            key: _refreshIndicatorKey,
            onRefresh: () async {
              _refreshNotices();
            },
            child: TabBarView(
              children: [
                _buildNoticesList(context, _allNoticesFuture, _allNoticesKey,
                    userState.isAdmin),
                _buildNoticesList(context, _importantNoticesFuture,
                    _importantNoticesKey, userState.isAdmin,
                    isImportantTab: true),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoticesList(BuildContext context,
      Future<List<Map<String, dynamic>>> futureNotices, Key key, bool isAdmin,
      {bool isImportantTab = false}) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      key: key,
      future: futureNotices,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
              child: Text(isImportantTab
                  ? 'No important notices available'
                  : 'No notices available'));
        }

        return ListView.builder(
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final notice = snapshot.data![index];
            return _buildNoticeCard(context, notice, isAdmin);
          },
        );
      },
    );
  }

  Widget _buildNoticeCard(
      BuildContext context, Map<String, dynamic> notice, bool isAdmin) {
    final isUnread = notice['viewed_at'] == null;
    final hasAttachments =
        notice['attachments'] != null && notice['attachments'].isNotEmpty;

    return Card(
      margin: const EdgeInsets.all(8),
      child: ListTile(
        leading: notice['is_important']
            ? const Icon(Icons.warning_amber, color: Colors.orange)
            : const Icon(Icons.announcement),
        title: Text(
          notice['title'],
          style: TextStyle(
            fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notice['content'],
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  DateFormat('MMM d, y').format(
                    DateTime.parse(notice['created_at']).toLocal(),
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (hasAttachments) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.attachment, size: 16),
                ],
              ],
            ),
          ],
        ),
        trailing: isAdmin
            ? IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _showDeleteConfirmation(context, notice['id']),
              )
            : null,
        onTap: () {
          noticeService.markAsRead(notice['id']);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NoticeDetailPage(notice: notice),
            ),
          );
        },
      ),
    );
  }

  // Show delete confirmation dialog
  void _showDeleteConfirmation(BuildContext context, String noticeId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Notice'),
        content: const Text(
            'Are you sure you want to delete this notice? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                // Close the dialog
                Navigator.pop(context);

                // Show loading indicator
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Deleting notice...')));

                // Delete the notice
                await noticeService.deleteNotice(noticeId);

                // Show success message
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Notice deleted successfully')));

                // Refresh the notices list
                _refreshNotices();
              } catch (error) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting notice: $error')));
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showCreateNoticeDialog(BuildContext context) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    bool isImportant = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Create New Notice'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      hintText: 'Enter notice title',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contentController,
                    decoration: const InputDecoration(
                      labelText: 'Content',
                      hintText: 'Enter notice content',
                    ),
                    maxLines: 5,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: isImportant,
                        onChanged: (value) {
                          setState(() {
                            isImportant = value ?? false;
                          });
                        },
                      ),
                      const Text('Mark as Important'),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  if (titleController.text.isNotEmpty &&
                      contentController.text.isNotEmpty) {
                    try {
                      await noticeService.createNotice(
                        title: titleController.text,
                        content: contentController.text,
                        isImportant: isImportant,
                      );

                      Navigator.pop(context);

                      // Show success message
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Notice created successfully')));

                      // Refresh notices lists to show the new notice
                      _refreshNotices();

                      // If we created an important notice and we're not on the important tab,
                      // switch to it to show the new notice
                      if (isImportant &&
                          DefaultTabController.of(context).index == 0) {
                        DefaultTabController.of(context).animateTo(1);
                      }
                    } catch (error) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $error')));
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Please fill all fields')));
                  }
                },
                child: const Text('Create'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class NoticeDetailPage extends StatelessWidget {
  final Map<String, dynamic> notice;

  const NoticeDetailPage({super.key, required this.notice});

  void _navigateToAdminEmployeePage(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => AdminHomePage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasAttachments =
        notice['attachments'] != null && notice['attachments'].isNotEmpty;
    final userState = Provider.of<UserState>(context);
    final noticeService = NoticeService();

    return PopScope(
        canPop: false,
        onPopInvoked: (didPop) {
          if (didPop) return;

          _navigateToAdminEmployeePage(context);
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(notice['title']),
            actions: [
              if (userState.isAdmin)
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Notice'),
                        content: const Text(
                            'Are you sure you want to delete this notice? This action cannot be undone.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () async {
                              try {
                                await noticeService.deleteNotice(notice['id']);

                                // Close the dialog and navigate back
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Notice deleted successfully')));
                                _navigateToAdminEmployeePage(context);
                              } catch (error) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            'Error deleting notice: $error')));
                              }
                            },
                            child: const Text('Delete',
                                style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'From: ${notice['author']?['name'] ?? 'Admin'}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  DateFormat('MMM d, y - h:mm a').format(
                    DateTime.parse(notice['created_at']).toLocal(),
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Divider(height: 24),
                Text(notice['content']),
                if (hasAttachments) ...[
                  const Divider(height: 24),
                  const Text('Attachments:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  ...(notice['attachments'] as List).map((attachment) {
                    return ListTile(
                      leading: const Icon(Icons.attachment),
                      title: Text(attachment['file_name']),
                      onTap: () {
                        // Implement opening the attachment
                      },
                    );
                  }),
                ],
              ],
            ),
          ),
        ));
  }
}
