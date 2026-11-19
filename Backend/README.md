# Daam shared backend — Supabase

One Supabase project serves both iOS and Android. Auth provides signup, email confirmation, password login, refresh and logout; PostgreSQL provides the account profile. The mobile apps use the same HTTPS contract. No custom server deployment is needed for this first phase.

## First setup

1. Create a Supabase project named **DaamApp** in your own account at https://supabase.com/dashboard . Keep the database password private.
2. Run `supabase/migrations/202610010001_identity.sql` once in its SQL Editor. For subsequent migrations, use the Supabase CLI migration workflow. Use a new development project for this initial migration.
3. Under Authentication, enable email/password signup and **Confirm email**. Set the minimum password length to 12. Keep rate limits enabled.
4. In the **Confirm signup** email template, use `supabase/templates/confirmation.html`, which includes `{{ .Token }}`. The app verifies the code directly; no mobile redirect or deep link is required for this flow. The hosted dashboard currently requires custom SMTP or Pro to customize templates; the local template is not deployed merely by running database migrations.
5. Configure SMTP before inviting real users. Supabase's default email service is restricted; use project-team addresses for initial development testing.
6. Copy only the Project URL and **publishable key** into `DaamApp/Resources/SupabaseConfig.plist` in Xcode. Never put a secret/service-role key or database password in either mobile app.
7. Build. The app opens the API-backed authentication flow when configured. With blank configuration it retains the existing UI demo. The authenticated account screen is intentionally separate from demo bookings until those APIs are implemented.

## Shared API contract

Base URL: your project's HTTPS URL. Every request sends `apikey: <publishable key>` and `Content-Type: application/json`. Authenticated requests also send `Authorization: Bearer <access_token>`.

| Operation | Method and path | JSON body |
| --- | --- | --- |
| Sign up | POST `/auth/v1/signup` | `{"email":"...","password":"...","data":{"display_name":"...","role":"parent"}}` (or `teacher`) |
| Confirm signup code | POST `/auth/v1/verify` | `{"email":"...","token":"...","type":"signup"}` |
| Resend signup code | POST `/auth/v1/resend` | `{"email":"...","type":"signup"}` |
| Log in | POST `/auth/v1/token?grant_type=password` | `{"email":"...","password":"..."}` |
| Refresh session | POST `/auth/v1/token?grant_type=refresh_token` | `{"refresh_token":"..."}` |
| Read current profile | GET `/rest/v1/profiles?select=id,role,display_name` | None; row-level security restricts results to the current user |
| Log out this session | POST `/auth/v1/logout?scope=local` | `{}` |

Login/verification/refresh return `access_token`, `refresh_token`, `expires_in`, and `user`. Signup with confirmation enabled may return a user without a session; this is not a logged-in state. Signup responses may deliberately hide whether an account already exists. Display neutral verification instructions. Treat HTTP 429 as throttling, 5xx/network errors as retryable, and 401 as an authentication failure. Never log passwords or tokens.

iOS stores sessions in device-only Keychain; Android should use Android Keystore-backed storage. Passwords stay only in form memory. The database role is authoritative, and an authenticated mobile user cannot change it or elevate to owner. Public teacher biographies will use a separate table; this private profile table is not a public teacher directory.

## Scope and next phases

This starter implements identity only. The existing booking, certificate-picker and payment screens remain a local UI demo. The private storage bucket is prepared but mobile certificate upload is not yet wired. Next: authenticated profile completion, server-stamped/versioned declarations, teacher certificate upload and owner review, teacher search by area, bookings, then CliQ receipt verification. Password recovery and account deletion must be added before public launch.

## Verification before enabling real users

Use two test users (parent and teacher): confirm both emails, log in/out, reopen the app, verify session refresh, and test a wrong password and expired confirmation code. Check that each user can only read their own profile, cannot patch `role`, and cannot read another user's certificate. Try an `owner` signup and confirm it is rejected. Certificate names must be `<user UUID>/<random UUID>.pdf` (or jpg/png). No private bucket should be changed to public.

Live integration and SQL policy tests require your Supabase project. This repository does not claim that a backend has already been deployed.

Official references: https://supabase.com/docs/guides/auth/passwords and https://supabase.com/docs/guides/database/postgres/row-level-security .
