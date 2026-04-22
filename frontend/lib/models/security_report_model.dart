class SecurityReportModel {
  const SecurityReportModel({
    required this.id,
    required this.appId,
    required this.score,
    required this.riskLevel,
    required this.aiSummary,
    required this.dangerousPermissions,
    required this.suspiciousApis,
    required this.aiUserReport,
    required this.aiDeveloperReport,
    required this.scannedAt,
  });

  final String id;
  final String appId;
  final int score;
  final String riskLevel;
  final String aiSummary;
  final List<String> dangerousPermissions;
  final List<String> suspiciousApis;
  final Map<String, dynamic> aiUserReport;
  final Map<String, dynamic> aiDeveloperReport;
  final String scannedAt;

  factory SecurityReportModel.fromJson(Map<String, dynamic> json) {
    return SecurityReportModel(
      id: (json['id'] ?? '').toString(),
      appId: (json['app_id'] ?? '').toString(),
      score: (json['score'] as num?)?.toInt() ?? 0,
      riskLevel: (json['risk_level'] ?? '').toString(),
      aiSummary: (json['ai_summary'] ?? '').toString(),
      dangerousPermissions: (json['dangerous_permissions'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      suspiciousApis: (json['suspicious_apis'] as List? ?? const []).map((e) => e.toString()).toList(),
      aiUserReport: Map<String, dynamic>.from(json['ai_user_report'] as Map? ?? const {}),
      aiDeveloperReport: Map<String, dynamic>.from(json['ai_developer_report'] as Map? ?? const {}),
      scannedAt: (json['scanned_at'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'app_id': appId,
      'score': score,
      'risk_level': riskLevel,
      'ai_summary': aiSummary,
      'dangerous_permissions': dangerousPermissions,
      'suspicious_apis': suspiciousApis,
      'ai_user_report': aiUserReport,
      'ai_developer_report': aiDeveloperReport,
      'scanned_at': scannedAt,
    };
  }
}
