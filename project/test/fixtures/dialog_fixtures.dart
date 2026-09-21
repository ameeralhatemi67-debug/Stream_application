// Test-only data for the populated dialog and sheet layouts in the sweep.
//
// An empty dialog proves very little: the layouts that break are the ones
// holding a long Arabic name, a roster, a reason list or a branch list at 320
// px and text scale 2.0. These fixtures are deliberately verbose for that
// reason, and carry both languages so the RTL pass is meaningful.
import 'package:streamer_app/core/models/device_session_model.dart';
import 'package:streamer_app/features/organization/models/org_speaker_model.dart';
import 'package:streamer_app/features/organization/models/org_venue_branch_model.dart';
import 'package:streamer_app/features/profile/models/vod_models.dart';

import 'vod_fixtures.dart';

final DeviceSessionModel currentDeviceFixture = DeviceSessionModel(
  deviceId: 'device_current_01',
  deviceName: 'Galaxy S24 Ultra (This device)',
  platform: 'Android 15',
  lastActiveAt: DateTime.utc(2026, 9, 21, 18, 30),
  isPrimaryBroadcaster: false,
  ipAddress: '192.168.1.42',
);

final DeviceSessionModel existingDeviceFixture = DeviceSessionModel(
  deviceId: 'device_existing_02',
  deviceName: 'MacBook Pro 16 - Lecture Hall Desk',
  platform: 'macOS 15.2',
  lastActiveAt: DateTime.utc(2026, 9, 21, 18, 12),
  isPrimaryBroadcaster: true,
  ipAddress: '192.168.1.17',
);

const List<OrgSpeakerModel> orgSpeakersFixture = [
  OrgSpeakerModel(
    speakerId: 'speaker_fixture_01',
    nameEn: 'Dr. Abdulrahman Al-Ghamdi',
    nameAr: 'الدكتور عبدالرحمن الغامدي',
    roleOrTitleEn: 'Professor of Distributed Systems, KFUPM',
    roleOrTitleAr: 'أستاذ الأنظمة الموزعة، جامعة الملك فهد للبترول والمعادن',
    avatarUrl: '',
    bioEn:
        'Leads the distributed systems research group and lectures weekly on '
        'service architecture, consensus protocols and edge networking.',
    bioAr:
        'يقود مجموعة أبحاث الأنظمة الموزعة ويحاضر أسبوعياً في معمارية الخدمات '
        'وبروتوكولات الإجماع والشبكات الطرفية.',
  ),
  OrgSpeakerModel(
    speakerId: 'speaker_fixture_02',
    nameEn: 'Dr. Nora Al-Otaibi',
    nameAr: 'الدكتورة نورة العتيبي',
    roleOrTitleEn: 'Consultant in Medical Imaging Diagnostics',
    roleOrTitleAr: 'استشارية تشخيص الصور الطبية',
    avatarUrl: '',
    bioEn: 'Researches applied machine learning for radiology workflows.',
    bioAr: 'تبحث في تطبيقات تعلم الآلة في مسارات عمل الأشعة.',
    isPermanentStaff: false,
  ),
];

const List<OrgVenueBranchModel> orgBranchesFixture = [
  OrgVenueBranchModel(
    venueId: 'branch_fixture_01',
    nameEn: 'Main Auditorium, Building 24',
    nameAr: 'القاعة الرئيسية، مبنى 24',
    cityEn: 'Dhahran',
    cityAr: 'الظهران',
    latitude: 26.3040,
    longitude: 50.1500,
    seatingCapacity: 480,
    isMainHeadquarters: true,
    roomNumberOrHall: 'Hall A',
    availableFacilities: ['Wi-Fi', 'Recording booth', 'Accessible seating'],
    addressEn: 'KFUPM campus, Building 24, Dhahran 31261',
    addressAr: 'حرم جامعة الملك فهد، مبنى 24، الظهران 31261',
  ),
  OrgVenueBranchModel(
    venueId: 'branch_fixture_02',
    nameEn: 'Al Khobar Community Hall',
    nameAr: 'قاعة الخبر المجتمعية',
    cityEn: 'Al Khobar',
    cityAr: 'الخبر',
    latitude: 26.2871,
    longitude: 50.2125,
    seatingCapacity: 120,
  ),
];

/// The sample VODs still name thumbnail assets that P2 removed with the rest
/// of the mock pool, so every fixture here blanks them: an absent thumbnail is
/// also the case the sheets have to lay out, and the one the neutral
/// placeholder was written for.
List<VodModel> _withoutThumbnails(Iterable<VodModel> vods) =>
    vods.map((v) => v.copyWith(thumbnailUrl: '')).toList();

/// A playlist with several entries, so the playlist sheet lays out a list
/// rather than a single row.
PlaylistModel playlistFixture() {
  final videos = _withoutThumbnails(MockVodArchivePool.sampleVods.take(4));
  return PlaylistModel(
    playlistId: 'playlist_fixture_01',
    streamerId: 'prof_alghamdi_01',
    titleEn: 'Distributed Systems: the full autumn series',
    titleAr: 'الأنظمة الموزعة: سلسلة الخريف كاملة',
    descriptionEn:
        'Every recorded session from the autumn term, in the order they were '
        'delivered, including the two guest lectures.',
    descriptionAr:
        'جميع الجلسات المسجلة من الفصل الخريفي بالترتيب الذي قُدمت به، بما في '
        'ذلك محاضرتي الضيوف.',
    youtubePlaylistUrl: 'https://www.youtube.com/playlist?list=PLfixture',
    thumbnailUrl: '',
    videoCount: videos.length,
    videos: videos,
  );
}

/// VODs attributed to the speaker shown in the inspection sheet.
List<VodModel> speakerVodsFixture() =>
    _withoutThumbnails(MockVodArchivePool.sampleVods.take(3));

/// A single recording for the VOD player sheet.
VodModel vodFixture() =>
    MockVodArchivePool.sampleVods.first.copyWith(thumbnailUrl: '');
