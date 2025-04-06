import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class NoticeService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getNotices({bool? isImportant}) async {
    final query = _supabase.from('notices').select('''*, 
          author:users(name),
          attachments:notice_attachments(*),
          viewed_at:notice_views!left(viewed_at)''').order('created_at', ascending: false);

    final response = await query;
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> markAsRead(String noticeId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase.from('notice_views').upsert({
      'notice_id': noticeId,
      'user_id': userId,
    });
  }

  Future<bool> isAdmin() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;

    final response = await _supabase
        .from('users')
        .select('role')
        .eq('user_id', userId)
        .single();

    return response['role'] == 'admin';
  }

  Future<void> createNotice({
    required String title,
    required String content,
    bool isImportant = false,
    DateTime? expiresAt,
    List<String> categories = const [],
    List<Map<String, dynamic>>? attachments,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase.from('notices').insert({
      'title': title,
      'content': content,
      'author_id': userId,
      'is_important': isImportant,
      'expires_at': expiresAt?.toIso8601String(),
      'categories': categories,
    });
  }

  Future<String> uploadAttachment(String filePath) async {
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${filePath.split('/').last}';
    final fileBytes = await File(filePath).readAsBytes();

    await _supabase.storage
        .from('notice_attachments')
        .upload(fileName, fileBytes as File);

    return _supabase.storage.from('notice_attachments').getPublicUrl(fileName);
  }

  Future<void> deleteNotice(String noticeId) async {
    await _supabase.from('notices').delete().eq('id', noticeId);
  }

  Future<void> deleteAttachment(String attachmentId) async {
    await _supabase.storage.from('notice_attachments').remove([attachmentId]);
  }
}
