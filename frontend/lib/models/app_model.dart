class AppModel {
  const AppModel({
    required this.id,
    required this.name,
    required this.shortDescription,
    required this.description,
    required this.category,
    required this.iconUrl,
    required this.screenshots,
    required this.supportedPlatforms,
    required this.totalInstalls,
    required this.securityScore,
    required this.status,
    required this.riskBadge,
    required this.androidFileUrl,
    required this.iosPwaUrl,
    required this.windowsFileUrl,
    required this.macFileUrl,
    required this.linuxDebUrl,
    required this.linuxAppimageUrl,
    required this.linuxRpmUrl,
    required this.installUrls,
  });

  final String id;
  final String name;
  final String shortDescription;
  final String description;
  final String category;
  final String iconUrl;
  final List<String> screenshots;
  final List<String> supportedPlatforms;
  final int totalInstalls;
  final int? securityScore;
  final String status;
  final String? riskBadge;
  final String? androidFileUrl;
  final String? iosPwaUrl;
  final String? windowsFileUrl;
  final String? macFileUrl;
  final String? linuxDebUrl;
  final String? linuxAppimageUrl;
  final String? linuxRpmUrl;
  final Map<String, String> installUrls;

  factory AppModel.fromJson(Map<String, dynamic> json) {
    final installMap = (json['install_urls'] is Map)
        ? Map<String, dynamic>.from(json['install_urls'] as Map)
        : <String, dynamic>{};

    return AppModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      shortDescription: (json['short_description'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      iconUrl: (json['icon_url'] ?? '').toString(),
      screenshots: (json['screenshots'] as List? ?? const []).map((e) => e.toString()).toList(),
      supportedPlatforms: (json['supported_platforms'] ?? json['platforms'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      totalInstalls: (json['total_installs'] as num?)?.toInt() ?? 0,
      securityScore: (json['security_score'] as num?)?.toInt(),
      status: (json['status'] ?? '').toString(),
      riskBadge: json['risk_badge']?.toString(),
      androidFileUrl: json['android_file_url']?.toString(),
      iosPwaUrl: json['ios_pwa_url']?.toString(),
      windowsFileUrl: json['windows_file_url']?.toString(),
      macFileUrl: json['mac_file_url']?.toString(),
      linuxDebUrl: json['linux_deb_url']?.toString(),
      linuxAppimageUrl: json['linux_appimage_url']?.toString(),
      linuxRpmUrl: json['linux_rpm_url']?.toString(),
      installUrls: installMap.map((key, value) => MapEntry(key.toString(), value.toString())),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'short_description': shortDescription,
      'description': description,
      'category': category,
      'icon_url': iconUrl,
      'screenshots': screenshots,
      'supported_platforms': supportedPlatforms,
      'total_installs': totalInstalls,
      'security_score': securityScore,
      'status': status,
      'risk_badge': riskBadge,
      'android_file_url': androidFileUrl,
      'ios_pwa_url': iosPwaUrl,
      'windows_file_url': windowsFileUrl,
      'mac_file_url': macFileUrl,
      'linux_deb_url': linuxDebUrl,
      'linux_appimage_url': linuxAppimageUrl,
      'linux_rpm_url': linuxRpmUrl,
      'install_urls': installUrls,
    };
  }

  AppModel copyWith({
    String? id,
    String? name,
    String? shortDescription,
    String? description,
    String? category,
    String? iconUrl,
    List<String>? screenshots,
    List<String>? supportedPlatforms,
    int? totalInstalls,
    int? securityScore,
    String? status,
    String? riskBadge,
    String? androidFileUrl,
    String? iosPwaUrl,
    String? windowsFileUrl,
    String? macFileUrl,
    String? linuxDebUrl,
    String? linuxAppimageUrl,
    String? linuxRpmUrl,
    Map<String, String>? installUrls,
  }) {
    return AppModel(
      id: id ?? this.id,
      name: name ?? this.name,
      shortDescription: shortDescription ?? this.shortDescription,
      description: description ?? this.description,
      category: category ?? this.category,
      iconUrl: iconUrl ?? this.iconUrl,
      screenshots: screenshots ?? this.screenshots,
      supportedPlatforms: supportedPlatforms ?? this.supportedPlatforms,
      totalInstalls: totalInstalls ?? this.totalInstalls,
      securityScore: securityScore ?? this.securityScore,
      status: status ?? this.status,
      riskBadge: riskBadge ?? this.riskBadge,
      androidFileUrl: androidFileUrl ?? this.androidFileUrl,
      iosPwaUrl: iosPwaUrl ?? this.iosPwaUrl,
      windowsFileUrl: windowsFileUrl ?? this.windowsFileUrl,
      macFileUrl: macFileUrl ?? this.macFileUrl,
      linuxDebUrl: linuxDebUrl ?? this.linuxDebUrl,
      linuxAppimageUrl: linuxAppimageUrl ?? this.linuxAppimageUrl,
      linuxRpmUrl: linuxRpmUrl ?? this.linuxRpmUrl,
      installUrls: installUrls ?? this.installUrls,
    );
  }
}
