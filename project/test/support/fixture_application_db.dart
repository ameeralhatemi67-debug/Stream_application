import 'package:streamer_app/core/services/admin_database_service.dart';
import 'package:streamer_app/features/admin/models/broadcaster_application_model.dart';
import 'package:streamer_app/features/organization/models/org_affiliation_request_model.dart';

/// In-memory stand-in for the application review tables. The real service
/// refuses offline submissions (no cached-success fallback), so tests that
/// exercise the review pipeline need an explicit backend, not the demo cache.
class FixtureApplicationDb extends AdminDatabaseService {
  FixtureApplicationDb() : super(null);

  final List<BroadcasterApplicationModel> applications = [];
  final List<Map<String, dynamic>> reviewEvents = [];
  final List<OrgAffiliationRequestModel> affiliations = [];

  @override
  Future<List<OrgAffiliationRequestModel>> loadAffiliationRequests(
          {String? orgId, String? streamerId}) async =>
      List.unmodifiable(affiliations.where((r) =>
          (orgId == null || r.orgId == orgId) &&
          (streamerId == null || r.streamerId == streamerId)));

  @override
  Future<void> submitAffiliationRequest(
      OrgAffiliationRequestModel request) async {
    if (request.direction != AffiliationDirection.streamerToOrg) {
      throw StateError('Use the organization invitation flow');
    }
    affiliations.insert(0, request);
  }

  @override
  Future<OrgAffiliationRequestModel?> updateAffiliationRequestStatus(
      String id, AffiliationStatus newStatus) async {
    final index = affiliations.indexWhere((r) => r.id == id);
    if (index == -1 || !affiliations[index].isPending) return null;
    return affiliations[index] = affiliations[index]
        .copyWith(status: newStatus, resolvedAt: DateTime.now());
  }

  @override
  Future<List<BroadcasterApplicationModel>> loadApplications() async =>
      List.unmodifiable(applications);

  @override
  Future<void> submitApplication(
      BroadcasterApplicationModel application) async {
    final index = applications.indexWhere((a) => a.id == application.id);
    if (index == -1) {
      applications.insert(0, application);
    } else {
      applications[index] = application;
    }
  }

  @override
  Future<BroadcasterApplicationModel?> updateApplicationStatus(
    String id,
    ApplicationStatus newStatus, {
    required ApplicationStatus expectedStatus,
    String? reviewNotes,
    String? reviewedBy,
  }) async {
    final index = applications.indexWhere((a) => a.id == id);
    if (index == -1 || applications[index].status != expectedStatus) {
      return null;
    }
    final updated = applications[index].copyWith(
      status: newStatus,
      adminReviewNotes: reviewNotes,
      reviewedBy: reviewedBy ?? 'Admin',
      reviewedAt: DateTime.now(),
    );
    applications[index] = updated;
    _record(updated, newStatus.name, reviewNotes);
    return updated;
  }

  @override
  Future<bool> deleteApplication(String id) async {
    final index = applications.indexWhere((a) => a.id == id);
    if (index == -1) return false;
    _record(applications.removeAt(index), 'removed', null);
    return true;
  }

  @override
  Future<List<Map<String, dynamic>>> loadApplicationReviewEvents() async =>
      List.unmodifiable(reviewEvents);

  void _record(BroadcasterApplicationModel app, String action, String? reason) {
    reviewEvents.insert(0, {
      'id': 'fixture-${reviewEvents.length}',
      'application_id': app.id,
      'applicant_name_en': app.applicantNameEn,
      'applicant_name_ar': app.applicantNameAr,
      'actor_name': 'Fixture admin',
      'action': action,
      'reason': reason,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
