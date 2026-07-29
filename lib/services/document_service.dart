import 'dart:convert';
import 'dart:io';

import 'api_client.dart';
import 'session_service.dart';

/// Jenis dokumen onboarding yang dilacak backend.
/// Harus sama persis dengan enum `StaffDocumentJenis` di schema Prisma.
class DocumentJenis {
  static const pasFoto = 'PasFoto';
  static const ktp = 'KTP';
  static const bpjs = 'BPJS';
  static const npwp = 'NPWP';

  static const labels = <String, String>{
    pasFoto: 'Pas Foto',
    ktp: 'KTP',
    bpjs: 'BPJS',
    npwp: 'NPWP',
  };

  static const descriptions = <String, String>{
    pasFoto: 'Foto formal terbaru, wajah terlihat jelas',
    ktp: 'Kartu Tanda Penduduk yang masih berlaku',
    bpjs: 'Kartu BPJS Kesehatan / Ketenagakerjaan',
    npwp: 'Nomor Pokok Wajib Pajak',
  };
}

/// Status satu jenis dokumen dalam gerbang onboarding.
class OnboardingDocument {
  final String jenis;

  /// Wajib untuk staff INI (BPJS/NPWP hanya wajib bila BPJS-nya aktif).
  final bool required;
  final bool submitted;

  /// pending | approved | rejected | null (belum pernah diunggah)
  final String? latestStatus;
  final String? catatanAdmin;

  OnboardingDocument({
    required this.jenis,
    required this.required,
    required this.submitted,
    required this.latestStatus,
    required this.catatanAdmin,
  });

  String get label => DocumentJenis.labels[jenis] ?? jenis;
  String get description => DocumentJenis.descriptions[jenis] ?? '';
  bool get isRejected => latestStatus == 'rejected';

  factory OnboardingDocument.fromApi(Map<String, dynamic> j) => OnboardingDocument(
        jenis: (j['jenis'] ?? '').toString(),
        required: j['required'] == true,
        submitted: j['submitted'] == true,
        latestStatus: j['latestStatus']?.toString(),
        catatanAdmin: j['latestCatatanAdmin']?.toString(),
      );
}

/// Hasil gerbang onboarding.
class OnboardingStatus {
  /// true = semua dokumen WAJIB sudah pernah diunggah → app boleh dibuka.
  final bool completed;
  final List<OnboardingDocument> documents;

  OnboardingStatus({required this.completed, required this.documents});

  /// Hanya dokumen yang wajib untuk staff ini — inilah yang ditampilkan
  /// layar onboarding (jumlahnya bisa 2 atau 4, tidak di-hardcode).
  List<OnboardingDocument> get requiredDocuments =>
      documents.where((d) => d.required).toList();

  factory OnboardingStatus.fromApi(Map<String, dynamic> j) => OnboardingStatus(
        completed: j['completed'] == true,
        documents: (j['documents'] is List)
            ? (j['documents'] as List)
                .whereType<Map>()
                .map((m) => OnboardingDocument.fromApi(Map<String, dynamic>.from(m)))
                .toList()
            : const [],
      );
}

/// Upload & status dokumen onboarding (pas foto / KTP / BPJS / NPWP).
class DocumentService {
  const DocumentService._();

  static Future<String> _staffId() async {
    final id = await SessionService.getStaffId();
    if (id == null || id.isEmpty) {
      throw ApiException('Sesi tidak ditemukan. Silakan login kembali.');
    }
    return id;
  }

  /// Gerbang onboarding: apakah staff sudah boleh masuk app.
  static Future<OnboardingStatus> onboardingStatus() async {
    final id = await _staffId();
    final res = await ApiClient.instance.get('/mobile/staff/$id/onboarding-status');
    return OnboardingStatus.fromApi(res.asMap);
  }

  /// Unggah satu dokumen. File dikirim sebagai base64; backend yang
  /// menyimpannya ke Google Drive perusahaan lalu mengisi `fileUrl`.
  static Future<void> upload({
    required String jenis,
    required File file,
    String? catatanStaff,
  }) async {
    final id = await _staffId();
    final bytes = await file.readAsBytes();

    return _uploadBytes(
      staffId: id,
      jenis: jenis,
      bytes: bytes,
      filename: file.path,
      catatanStaff: catatanStaff,
    );
  }

  static Future<void> _uploadBytes({
    required String staffId,
    required String jenis,
    required List<int> bytes,
    required String filename,
    String? catatanStaff,
  }) async {
    await ApiClient.instance.post(
      '/mobile/staff/$staffId/documents',
      body: {
        'jenis': jenis,
        'fileBase64': base64Encode(bytes),
        'fileMimeType': _mimeFromPath(filename),
        if (catatanStaff != null && catatanStaff.isNotEmpty)
          'catatanStaff': catatanStaff,
      },
    );
  }

  static String _mimeFromPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    return 'image/jpeg';
  }
}
