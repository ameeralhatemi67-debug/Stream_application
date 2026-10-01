import 'package:flutter_test/flutter_test.dart';
import 'package:streamer_app/features/organization/models/org_membership.dart';

void main() {
  Map<String, dynamic> row(String role, {String status = 'active'}) => {
    'organization_id': 'org', 'profile_id': 'person',
    'role': role, 'status': status, 'permissions': <String, dynamic>{},
  };

  test('membership permissions fail closed and staff scopes stay separate', () {
    final manager = OrgMembership.fromRow(row('manager'));
    expect(manager.canManageMembers, isTrue);
    expect(manager.canManageChannel, isFalse);
    expect(manager.canModerate, isFalse);
    expect(manager.permissions.canGoLiveVideo, isFalse);
    expect(manager.permissions.canGoAudioOnly, isFalse);
    final moderator = OrgMembership.fromRow(row('moderator'));
    expect(moderator.canModerate, isTrue);
    expect(moderator.canManageMembers, isFalse);
    final revoked = OrgMembership.fromRow(row('owner', status: 'revoked'));
    expect(revoked.canManageMembers, isFalse);
    expect(revoked.canManageChannel, isFalse);
    expect(() => OrgMembership.fromRow(row('master_admin')), throwsFormatException);
  });
}
