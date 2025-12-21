// lib/models/andon_issue_model.dart
import 'package:flutter/material.dart';

class AndonIssue {
  final String id;
  final String createdById;
  final String? createdByName;
  final String? createdByDept;
  final String? block;
  final String? lineNo;
  final String? section;
  final String? machineNo;
  final String? category;
  final String title;
  final String description;
  final String? imageUrl;
  final String? responsibleDept;
  final String? assignedToId;
  final String? assignedToName;
  final String status;
  final String priority;
  final DateTime createdAt;
  final DateTime? noticedAt;
  final DateTime? inProgressAt;
  final DateTime? solvedAt;
  final DateTime? closedAt;
  final String? noticedById;
  final String? inProgressById;
  final String? solvedById;
  final String? closedById;
  final int? slaTargetMinutes;
  final bool isActive;
  final String? sales_document;
  final String? buyer_name;
  final String? style_name;

  AndonIssue({
    required this.id,
    required this.createdById,
    this.createdByName,
    this.createdByDept,
    this.block,
    this.lineNo,
    this.section,
    this.machineNo,
    this.category,
    required this.title,
    required this.description,
    this.imageUrl,
    this.responsibleDept,
    this.assignedToId,
    this.assignedToName,
    required this.status,
    required this.priority,
    required this.createdAt,
    this.noticedAt,
    this.inProgressAt,
    this.solvedAt,
    this.closedAt,
    this.noticedById,
    this.inProgressById,
    this.solvedById,
    this.closedById,
    this.slaTargetMinutes,
    required this.isActive,
    this.sales_document,
    this.buyer_name,
    this.style_name,
  });

  factory AndonIssue.fromMap(Map<String, dynamic> map) {
    DateTime? parseDt(dynamic v) =>
        v == null ? null : DateTime.parse(v as String).toLocal();

    return AndonIssue(
      id: map['id'] as String,
      createdById: map['created_by_id'] ?? '',
      createdByName: map['created_by_name'],
      createdByDept: map['created_by_dept'],
      block: map['block'],
      lineNo: map['line_no'],
      section: map['section'],
      machineNo: map['machine_no'],
      category: map['category'],
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['image_url'],
      responsibleDept: map['responsible_dept'],
      assignedToId: map['assigned_to_id'],
      assignedToName: map['assigned_to_name'],
      status: map['status'] ?? 'OPEN',
      priority: map['priority'] ?? 'MEDIUM',

      // 👇 IMPORTANT: convert from UTC → local
      createdAt: DateTime.parse(map['created_at']).toLocal(),
      noticedAt: parseDt(map['noticed_at']),
      inProgressAt: parseDt(map['in_progress_at']),
      solvedAt: parseDt(map['solved_at']),
      closedAt: parseDt(map['closed_at']),

      noticedById: map['noticed_by_id'],
      inProgressById: map['in_progress_by_id'],
      solvedById: map['solved_by_id'],
      closedById: map['closed_by_id'],
      slaTargetMinutes: map['sla_target_minutes'],
      isActive: map['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'created_by_id': createdById,
      'created_by_name': createdByName,
      'created_by_dept': createdByDept,
      'block': block,
      'line_no': lineNo,
      'section': section,
      'machine_no': machineNo,
      'category': category,
      'title': title,
      'description': description,
      'image_url': imageUrl,
      'responsible_dept': responsibleDept,
      'assigned_to_id': assignedToId,
      'assigned_to_name': assignedToName,
      'priority': priority,
      'sales_document': sales_document,
      'buyer_name': buyer_name,
      'style_name': style_name,
      // status, timestamps, etc. will be defaulted by DB
    };
  }

  /// Time to solve, if solved. Otherwise null.
  Duration? get timeToSolve {
    if (solvedAt == null) return null;
    return solvedAt!.difference(createdAt);
  }

  /// How long it's been open till now.
  Duration get timeOpen {
    final ref = solvedAt ?? DateTime.now();
    return ref.difference(createdAt);
  }
}

class AndonComment {
  final String id;
  final String issueId;
  final String userId;
  final String? userName;
  final String commentText;
  final DateTime createdAt;

  AndonComment({
    required this.id,
    required this.issueId,
    required this.userId,
    this.userName,
    required this.commentText,
    required this.createdAt,
  });

  factory AndonComment.fromMap(Map<String, dynamic> map) {
    return AndonComment(
      id: map['id'] as String,
      issueId: map['issue_id'] as String,
      userId: map['user_id'] ?? '',
      userName: map['user_name'],
      commentText: map['comment_text'] ?? '',
      createdAt: DateTime.parse(map['created_at']).toLocal(),
    );
  }
}
