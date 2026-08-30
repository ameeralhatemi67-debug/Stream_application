import 'package:flutter_test/flutter_test.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/features/discovery/models/academic_category_model.dart';
import 'package:streamer_app/features/admin/models/tag_moderation_model.dart';
import 'package:streamer_app/features/admin/models/banned_user_model.dart';
import 'package:streamer_app/features/admin/models/stream_moderator_model.dart';
import 'package:streamer_app/features/live_stream/models/chat_message_model.dart';
import 'package:streamer_app/features/profile/models/streamer_models.dart';

void main() {
  group('Cluster 3 Task 10/11: Academic Categories', () {
    test('AcademicCategoryModel.defaultPool has 8 bilingual entries matching '
        'the seeded migration rows', () {
      expect(AcademicCategoryModel.defaultPool.length, equals(8));
      final cs = AcademicCategoryModel.defaultPool
          .firstWhere((c) => c.id == 'computer_science');
      expect(cs.getLocalizedName('en'), equals('Computer Science'));
      expect(cs.getLocalizedName('ar'), equals('علوم الحاسب'));
      expect(cs.isActive, isTrue);
    });

    test('AcademicCategoryModel round-trips through fromJson/toJson (the '
        'shape AdminDatabaseService upserts to academic_categories)', () {
      const category = AcademicCategoryModel(
        id: 'robotics',
        nameEn: 'Robotics',
        nameAr: 'الروبوتات',
        iconName: 'precision_manufacturing',
        sortOrder: 9,
        isActive: false,
      );
      final json = category.toJson();
      expect(json['id'], equals('robotics'));
      expect(json['is_active'], isFalse);

      final restored = AcademicCategoryModel.fromJson(json);
      expect(restored.id, equals('robotics'));
      expect(restored.nameAr, equals('الروبوتات'));
      expect(restored.isActive, isFalse);
    });

    test('copyWith only overrides the given fields, id stays immutable', () {
      const category = AcademicCategoryModel(
          id: 'engineering', nameEn: 'Engineering', nameAr: 'الهندسة');
      final renamed = category.copyWith(nameEn: 'Engineering & Innovation');
      expect(renamed.id, equals('engineering'));
      expect(renamed.nameEn, equals('Engineering & Innovation'));
      expect(renamed.nameAr, equals('الهندسة'));
    });

    test(
        'AppProvider.academicCategories falls back to defaultPool when the '
        'backend list is empty (offline / not loaded yet)', () {
      final provider = AppProvider();
      // No Supabase in the test environment -> _academicCategories stays
      // empty -> the getter must degrade to the seeded default pool rather
      // than leaving Discovery/Map with zero category chips.
      expect(provider.academicCategories, isNotEmpty);
      expect(provider.academicCategories, equals(AcademicCategoryModel.defaultPool));
    });

    test(
        'Task 10: selecting a category via setCategoryFilter is reflected in '
        'both filteredStreamers (shared by Discovery Feed and Spatial Map) '
        'and the selectedCategoryId getter', () {
      final provider = AppProvider();
      expect(provider.selectedCategoryId, isNull); // 'all' -> null

      provider.setCategoryFilter('islamic_studies');
      expect(provider.selectedCategoryId, equals('islamic_studies'));
      final filtered = provider.filteredStreamers;
      expect(filtered, isNotEmpty);
      expect(
        filtered.every(
            (s) => s.categoryId == 'islamic_studies' || s.categoryId == 'sharia'),
        isTrue,
      );

      provider.setCategoryFilter('all');
      expect(provider.selectedCategoryId, isNull);
    });
  });

  group('Cluster 3 Task 12: Tag Moderation', () {
    test('TagModerationModel.fromRow parses a tags table row', () {
      final row = {
        'name': '#Robotics',
        'status': 'pending',
        'created_at': '2026-08-30T12:00:00.000Z',
      };
      final tag = TagModerationModel.fromRow(row);
      expect(tag.name, equals('#Robotics'));
      expect(tag.status, equals(TagStatus.pending));
    });

    test('TagStatusInfo.fromDbValue degrades an unknown status to pending '
        'instead of throwing', () {
      expect(TagStatusInfo.fromDbValue('not_a_real_status'),
          equals(TagStatus.pending));
      expect(TagStatusInfo.fromDbValue('approved'), equals(TagStatus.approved));
      expect(TagStatusInfo.fromDbValue('blacklisted'),
          equals(TagStatus.blacklisted));
    });

    test(
        'AppProvider.approvedTags/allTagsForModeration start empty offline -- '
        'the tags filter sheet degrades to just the "all" chip rather than '
        'crashing when there is no backend to read from', () {
      final provider = AppProvider();
      expect(provider.approvedTags, isEmpty);
      expect(provider.allTagsForModeration, isEmpty);
    });
  });

  group('Cluster 4 Task 13/15: Chat Message Actions & Moderator Badges', () {
    test('ChatSenderBadge.moderator carries the shield+MOD label', () {
      expect(ChatSenderBadge.moderator.emoji, equals('🛡️ MOD'));
    });

    test('ChatMessageModel.isStreamModerator reflects the moderator badge',
        () {
      final message = ChatMessageModel(
        id: 'm1',
        streamId: 's1',
        senderId: 'u1',
        senderName: 'Test User',
        body: 'hello',
        createdAt: DateTime.now(),
        badges: const {ChatSenderBadge.moderator},
      );
      expect(message.isStreamModerator, isTrue);
      expect(message.isEdited, isFalse);
    });

    test(
        'Task 13: editing a message updates body and editedAt via copyWith, '
        'and isEdited flips true (drives the "(edited)" chat indicator)', () {
      final original = ChatMessageModel(
        id: 'm2',
        streamId: 's1',
        senderId: 'u1',
        senderName: 'Test User',
        body: 'origianl typo',
        createdAt: DateTime.now(),
        isCurrentUser: true,
      );
      expect(original.isEdited, isFalse);

      final editedAt = DateTime.now();
      final edited = original.copyWith(body: 'original fixed', editedAt: editedAt);
      expect(edited.body, equals('original fixed'));
      expect(edited.isEdited, isTrue);
      expect(edited.editedAt, equals(editedAt));
      // Identity fields are untouched by an edit.
      expect(edited.id, equals(original.id));
      expect(edited.senderId, equals(original.senderId));
      expect(edited.isCurrentUser, isTrue);
    });
  });

  group('Cluster 4 Task 15: Stream Moderator Delegation', () {
    test('ModeratorScopeInfo.fromDbValue round-trips every scope value', () {
      expect(ModeratorScopeInfo.fromDbValue('stream'),
          equals(ModeratorScope.stream));
      expect(ModeratorScopeInfo.fromDbValue('organization'),
          equals(ModeratorScope.organization));
      expect(ModeratorScopeInfo.fromDbValue('global'),
          equals(ModeratorScope.global));
    });

    test('StreamModeratorModel.scopeLabel is human-readable per scope', () {
      final streamScoped = StreamModeratorModel(
        id: '1',
        profileId: 'p1',
        assignedBy: 'p2',
        scope: ModeratorScope.stream,
        streamId: 'stream_live_992',
        grantedAt: DateTime.now(),
        moderatorDisplayName: 'Mod One',
        assignedByDisplayName: 'Owner One',
      );
      expect(streamScoped.scopeLabel, contains('stream_live_992'));

      final globalScoped = StreamModeratorModel(
        id: '2',
        profileId: 'p1',
        assignedBy: 'p2',
        scope: ModeratorScope.global,
        grantedAt: DateTime.now(),
        moderatorDisplayName: 'Mod One',
        assignedByDisplayName: 'Admin',
      );
      expect(globalScoped.scopeLabel, contains('Global'));
    });
  });

  group('Cluster 4 Task 16: Platform Account Ban', () {
    test('BannedUserModel.isPermanent is true only when expiresAt is null',
        () {
      final permanent = BannedUserModel(
        id: '1',
        profileId: 'p1',
        email: 'banned@example.com',
        reason: 'Spam',
        bannedAt: DateTime.now(),
      );
      expect(permanent.isPermanent, isTrue);
      expect(permanent.isExpired, isFalse);

      final expired = BannedUserModel(
        id: '2',
        profileId: 'p2',
        email: 'temp@example.com',
        reason: 'Harassment',
        bannedAt: DateTime.now().subtract(const Duration(days: 2)),
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(expired.isPermanent, isFalse);
      expect(expired.isExpired, isTrue);
    });

    test(
        'AppProvider.isCurrentUserBanned defaults to false with no reason -- '
        'this is the state AppRouter\'s redirect guard reads to decide '
        'whether to send a signed-in user to /account-banned', () {
      final provider = AppProvider();
      expect(provider.isCurrentUserBanned, isFalse);
      expect(provider.currentUserBanReason, isNull);
    });
  });

  group('Cluster 4 Task 18: Temporary Map Visibility', () {
    test('StreamerModel.isTemporarilyHiddenFromMap defaults to false and is '
        'toggled via copyWith without disturbing other fields', () {
      final streamer = mockStreamers.first;
      expect(streamer.isTemporarilyHiddenFromMap, isFalse);

      final hidden = streamer.copyWith(isTemporarilyHiddenFromMap: true);
      expect(hidden.isTemporarilyHiddenFromMap, isTrue);
      expect(hidden.streamerId, equals(streamer.streamerId));
      expect(hidden.fullNameEn, equals(streamer.fullNameEn));
    });

    test(
        'AppProvider.filteredStreamers excludes a streamer once '
        'isTemporarilyHiddenFromMap is set, but the full streamers list still '
        'has them (profile stays reachable by direct link)', () {
      final provider = AppProvider();
      const targetId = 'prof_alghamdi_01';
      final target = provider.streamers.firstWhere((s) => s.streamerId == targetId);

      expect(
        provider.filteredStreamers.any((s) => s.streamerId == targetId),
        isTrue,
      );

      provider.updateStreamer(target.copyWith(isTemporarilyHiddenFromMap: true));

      expect(
        provider.filteredStreamers.any((s) => s.streamerId == targetId),
        isFalse,
        reason: 'a temporarily-hidden streamer must not appear on the map or '
            'discovery feed',
      );
      expect(
        provider.streamers.any((s) => s.streamerId == targetId),
        isTrue,
        reason: 'the streamer record itself is not deleted, only filtered '
            'from map/feed -- BroadcasterProfileScreen stays reachable',
      );
    });
  });
}
