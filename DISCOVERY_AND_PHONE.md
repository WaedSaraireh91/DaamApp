# Teacher discovery and local phone authentication

The first screen is now the public teacher directory, with area and subject filters and a Register / Login action. Only approved active teachers are returned. Public responses contain professional biography, subjects, teaching areas and hourly rate; contact information and uploaded certificates are excluded. An empty state is shown when no approved teachers match.

Email authentication remains available. The phone option uses development-only codes displayed in the app; no SMS is sent and this does not prove real phone ownership. Backend endpoints are POST /api/v1/auth/phone/code and /api/v1/auth/phone/verify, enabled only in the dev profile without prod and with daam.phone.local-enabled=true. Codes expire after five minutes, allow five incorrect attempts, can be used once, and have a sixty-second resend cooldown. Production SMS delivery and verification remain future work.

Migration V6 allows phone-only accounts with null email and stores phone login identities separately from profile contact numbers. Existing email accounts are not automatically linked by contact number. Phone-only account management requiring a password needs a separate verified-phone flow before production release.

All new user-facing copy is available in the typed L10n enum and Arabic/English strings. Artwork is static. The new 1024px opaque app icon is Assets.xcassets/AppIcon.appiconset/DaamIcon.png; DaamMark is its in-app counterpart.

Icon generated with built-in image generation: emerald background, ivory open book shaped as supportive pages, and a small gold spark; no people or text.

Validation: native Xcode build succeeded with no issues; backend package built and local Docker service is healthy. Live HTTP checks passed for public directory, phone signup, incorrect-code rejection, replay rejection and resend cooldown. Temporary test records were removed. Simulator accessibility confirmed the Arabic phone-registration screen; visual screenshot capture timed out, so full visual QA remains outstanding. Full integration suite was not rerun.
