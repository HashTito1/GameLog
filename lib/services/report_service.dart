import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'firebase_auth_service.dart';

/// What a report points at. Stored as the `type` field.
class ReportType {
  static const rating = 'rating';
  static const comment = 'comment';
  static const forumPost = 'forum_post';
  static const bug = 'bug';
}

/// User reports (abusive content, bugs) for admins to review.
/// Anyone signed in can file one; only admins can read or resolve them
/// (see the `reports` match in firestore.rules).
class ReportService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _reportsCollection = 'reports';

  static const List<String> contentReasons = [
    'Spam or advertising',
    'Harassment or hate speech',
    'Spoilers without warning',
    'Inappropriate content',
    'Other',
  ];

  /// File a report. [targetPreview] is a short snippet of the reported text so
  /// admins can judge it even if the original is edited or deleted.
  static Future<void> submitReport({
    required String type,
    required String reason,
    String? targetId,
    String? targetOwnerId,
    String? targetPreview,
    String? details,
  }) async {
    final user = FirebaseAuthService().currentUser;
    if (user == null) throw Exception('You need to be signed in to send a report');

    await _firestore.collection(_reportsCollection).add({
      'type': type,
      'reason': reason,
      'targetId': targetId,
      'targetOwnerId': targetOwnerId,
      'targetPreview': _truncate(targetPreview, 300),
      'details': _truncate(details, 2000),
      'reporterId': user.uid,
      'reporterName': user.displayName,
      'status': 'open',
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Open reports, newest first. Admin only.
  static Future<List<Map<String, dynamic>>> getOpenReports({String? type}) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection(_reportsCollection)
        .where('status', isEqualTo: 'open');
    if (type != null) query = query.where('type', isEqualTo: type);

    final snapshot = await query.get();
    final reports = snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
    // Sorted here so the query doesn't need a composite index.
    reports.sort((a, b) => (b['createdAt'] ?? 0).compareTo(a['createdAt'] ?? 0));
    return reports;
  }

  /// IDs of content of [type] that has at least one open report. Admin only.
  static Future<Set<String>> getReportedTargetIds(String type) async {
    try {
      final reports = await getOpenReports(type: type);
      return reports.map((r) => r['targetId']).whereType<String>().toSet();
    } catch (e) {
      debugPrint('Error loading reported ids: $e');
      return {};
    }
  }

  /// Close a report. [status] is 'resolved' (action taken) or 'dismissed'.
  static Future<void> closeReport(String reportId, String status) async {
    await _firestore.collection(_reportsCollection).doc(reportId).update({
      'status': status,
      'closedAt': DateTime.now().millisecondsSinceEpoch,
      'closedBy': FirebaseAuthService().currentUser?.uid,
    });
  }

  /// Close every open report about [targetId], e.g. after deleting it.
  static Future<void> closeReportsForTarget(String targetId) async {
    final snapshot = await _firestore
        .collection(_reportsCollection)
        .where('targetId', isEqualTo: targetId)
        .where('status', isEqualTo: 'open')
        .get();
    for (final doc in snapshot.docs) {
      await closeReport(doc.id, 'resolved');
    }
  }

  static String? _truncate(String? text, int max) {
    if (text == null) return null;
    final trimmed = text.trim();
    return trimmed.length <= max ? trimmed : '${trimmed.substring(0, max)}…';
  }
}
