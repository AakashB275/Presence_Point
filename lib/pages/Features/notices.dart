import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:presence_point_2/services/notices_service.dart';

class NoticesPage extends StatelessWidget {
  final NoticeService noticeService = NoticeService();

  NoticesPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
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
            FutureBuilder<bool>(
              future: noticeService.isAdmin(),
              builder: (context, snapshot) {
                if (snapshot.data == true) {
                  return IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _showCreateNoticeDialog(context),
                  );
                }
                return const SizedBox();
              },
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _buildNoticesList(context),
            _buildImportantNoticesList(context),
          ],
        ),
      ),
    );
  }

  Widget _buildNoticesList(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: noticeService.getNotices(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No notices available'));
        }

        return ListView.builder(
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final notice = snapshot.data![index];
            return _buildNoticeCard(context, notice);
          },
        );
      },
    );
  }

  Widget _buildImportantNoticesList(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: noticeService.getNotices(isImportant: true),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No important notices'));
        }

        return ListView.builder(
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final notice = snapshot.data![index];
            return _buildNoticeCard(context, notice);
          },
        );
      },
    );
  }

  Widget _buildNoticeCard(BuildContext context, Map<String, dynamic> notice) {
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

  void _showCreateNoticeDialog(BuildContext context) {
    // Implement your notice creation dialog here
    // Similar to previous examples but using NoticeService
  }
}

class NoticeDetailPage extends StatelessWidget {
  final Map<String, dynamic> notice;

  const NoticeDetailPage({Key? key, required this.notice}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hasAttachments =
        notice['attachments'] != null && notice['attachments'].isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(notice['title']),
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
              }).toList(),
            ],
          ],
        ),
      ),
    );
  }
}
