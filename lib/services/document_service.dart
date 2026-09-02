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

  /// URL berkas unggahan TERAKHIR untuk jenis ini, "" bila belum ada.
  ///
  /// URL privat, bukan tautan publik: bentuk Drive-nya hanya bisa dibuka
  /// lewat proxy terautentikasi `GET /api/mobile/files/:fileId` — lihat
  /// `widgets/uploaded_file_image.dart` yang menanganinya.
  final String fileUrl;

  OnboardingDocument({
    required this.jenis,
    required this.required,
    required this.submitted,
    required this.latestStatus,
    required this.catatanAdmin,
    required this.fileUrl,
  });

  String get label => DocumentJenis.labels[jenis] ?? jenis;
  String get description => DocumentJenis.descriptions[jenis] ?? '';
  bool get isRejected => latestStatus == 'rejected';

  /// Ada berkas yang bisa ditampilkan sebagai pratinjau.
  bool get hasPreview => fileUrl.isNotEmpty;

  factory OnboardingDocument.fromApi(Map<String, dynamic> j) => OnboardingDocument(
        jenis: (j['jenis'] ?? '').toString(),
        required: j['required'] == true,
        submitted: j['submitted'] == true,
        latestStatus: j['latestStatus']?.toString(),
        catatanAdmin: j['latestCatatanAdmin']?.toString(),
        fileUrl: (j['latestFileUrl'] ?? '').toString(),
      );
}

/// Hasil gerbang onboarding.
class OnboardingStatus {
  /// true = semua dokumen WAJIB sudah pernah diunggah → app boleh dibuka.
  final bool completed;
  final List<OnboardingDocument> documents;

  /// Non-null = gerbang dokumen DIBUKA ULANG pada waktu itu, bukan onboarding
  /// pertama kali. Terjadi setelah staff mengganti nomor HP-nya sendiri:
  /// identitas login berpindah, jadi dokumen identitas dibuktikan ulang.
  /// Layar onboarding memakainya untuk menjelaskan kenapa dokumennya diminta
  /// lagi, dan untuk menawarkan "pakai dokumen sebelumnya".
  final DateTime? documentsResetAt;

  OnboardingStatus({
    required this.completed,
    required this.documents,
    this.documentsResetAt,
  });

  bool get isResubmission => documentsResetAt != null;

  /// Hanya dokumen yang WAJIB untuk staff ini (2 atau 4, ditentukan server:
  /// BPJS & NPWP wajib hanya bila BPJS staff aktif). Inilah yang menentukan
  /// boleh/tidaknya masuk app.
  List<OnboardingDocument> get requiredDocuments =>
      documents.where((d) => d.required).toList();

  /// Dokumen yang boleh diunggah tapi TIDAK memblokir masuk app (mis. BPJS &
  /// NPWP untuk staff magang/freelance yang BPJS-nya tidak aktif).
  List<OnboardingDocument> get optionalDocuments =>
      documents.where((d) => !d.required).toList();

  /// Semua dokumen yang dilacak backend (PasFoto, KTP, BPJS, NPWP) —
  /// layar onboarding menampilkan SEMUANYA, bukan hanya yang wajib, supaya
  /// staff tetap bisa mengunggah BPJS & NPWP walau server tidak mewajibkannya.
  /// Yang wajib ditaruh di atas agar jelas mana yang menggerbangi akses.
  List<OnboardingDocument> get allDocuments =>
      [...requiredDocuments, ...optionalDocuments];

  /// True bila TIDAK ada lagi dokumen yang bisa diunggah (wajib maupun
  /// opsional). Dipakai layar onboarding untuk memutuskan boleh langsung
  /// lompat ke app tanpa menampilkan daftar.
  bool get allSubmitted =>
      documents.isNotEmpty && documents.every((d) => d.submitted);

  factory OnboardingStatus.fromApi(Map<String, dynamic> j) => OnboardingStatus(
        completed: j['completed'] == true,
        documentsResetAt: j['documentsResetAt'] == null
            ? null
            : DateTime.tryParse(j['documentsResetAt'].toString())?.toLocal(),
        documents: (j['documents'] is List)
            ? (j['documents'] as List)
                .whereType<Map>()
                .map((m) => OnboardingDocument.fromApi(Map<String, dynamic>.from(m)))
                .toList()
            : const [],
      );
}


/// Dokumen yang PERNAH DISETUJUI sebelum gerbang dibuka ulang, dan karena itu
/// boleh diajukan ulang tanpa memotret apa pun.
class ReusableDocument {
  final String jenis;
  final String fileUrl;

  /// `approved` | `pending`. Ditampilkan apa adanya supaya staff tahu berkas
  /// mana yang sudah lolos review dan mana yang belum sempat ditinjau —
  /// bukan disamakan begitu saja.
  final String status;
  final DateTime? submittedAt;

  ReusableDocument({
    required this.jenis,
    required this.fileUrl,
    required this.status,
    required this.submittedAt,
  });

  String get label => DocumentJenis.labels[jenis] ?? jenis;

  bool get isApproved => status == 'approved';

  String get statusLabel => isApproved ? 'Sudah disetujui' : 'Menunggu review';

  factory ReusableDocument.fromApi(Map<String, dynamic> j) => ReusableDocument(
        jenis: (j['jenis'] ?? '').toString(),
        fileUrl: (j['fileUrl'] ?? '').toString(),
        status: (j['status'] ?? 'pending').toString(),
        submittedAt: j['submittedAt'] == null
            ? null
            : DateTime.tryParse(j['submittedAt'].toString())?.toLocal(),
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

  /// Dokumen lama yang sudah disetujui dan bisa diajukan ulang apa adanya.
  /// Kosong bila staff belum pernah punya dokumen yang disetujui.
  static Future<List<ReusableDocument>> previousDocuments() async {
    final id = await _staffId();
    final res =
        await ApiClient.instance.get('/mobile/staff/$id/documents/previous');
    return res.asList
        .map((m) => ReusableDocument.fromApi(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  /// Ajukan ulang dokumen lama yang sudah disetujui, tanpa mengunggah berkas.
  /// Server membuat pengajuan BARU yang menunjuk berkas yang sama.
  static Future<void> reusePrevious(String jenis) async {
    final id = await _staffId();
    await ApiClient.instance
        .post('/mobile/staff/$id/documents/reuse', body: {'jenis': jenis});
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
