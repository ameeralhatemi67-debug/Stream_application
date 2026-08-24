-- v0.9 Checkpoint 3, Phase 1: Onboarding Consent Step
--
-- Saudi PDPL gap from doc/Audit/03_Saudi_Legal_And_Store_Compliance_Audit.md
-- Phase 3: no explicit, recorded consent to data collection/privacy terms
-- exists anywhere before personal data is gathered. Records which privacy
-- policy version (TermsAndConditionsModel.version, e.g. 'v1.0') a signed-in
-- user explicitly accepted, and when -- written by the client via the
-- profiles_update_own RLS policy (20260821203100_row_level_security.sql)
-- right after ConsentDialog is accepted, or flushed there on first sign-in
-- if consent was accepted before the auth session existed (see
-- AppProvider.recordConsent / _flushPendingConsentIfAny).
alter table public.profiles
  add column if not exists consent_version text,
  add column if not exists consent_accepted_at timestamptz;

comment on column public.profiles.consent_version is
  'The version of the privacy policy (TermsAndConditionsModel.version) the user explicitly accepted, e.g. v1.0.';
comment on column public.profiles.consent_accepted_at is
  'The timestamp when the user explicitly gave consent, recorded client-side at acceptance.';
