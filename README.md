# DaamApp

Open `DaamApp.xcodeproj` and run the **DaamApp** scheme. SwiftUI, iOS 17+, Apple system typography, no third-party app dependencies.

## Current prototype

- Branded splash, illustrated onboarding, demo sign-in, parent/teacher role selection.
- Parent dashboard, teacher search, individual teacher profiles, red saved hearts and favorites.
- Three-step booking: student details → date/time and full lesson address → review.
- Parents pay **no booking fee and nothing upfront**. The booked hourly lesson price is paid to the teacher in cash on arrival.
- Teachers set their hourly rate before entering their dashboard. Rates persist locally and appear in parent search, profiles and new bookings. Existing bookings retain their quoted price.
- Teacher requests, request details, schedule, students and acceptance-fee history.
- Teacher areas and student lesson addresses are visible on the relevant cards and details.
- First acceptance per teacher is free. Every later acceptance requires **JOD 1 via CliQ**, currently to **TestAccount**.
- Submitting a transfer reference does **not** verify payment. In Account → Transfer review — app owner, the owner confirms receipt or rejects the details. Only a verified transfer unlocks the teacher's acceptance action. Approval does not automatically accept the class.
- Arabic/English switch, explicit RTL/LTR input alignment, localized dates, reduced-motion support, persistent demo state.

## Demo boundaries

This is a local UI prototype. No authentication, banking, bank verification, notifications or API calls occur. TestAccount is a temporary recipient supplied for the prototype; do not send real money. Owner review tools are deliberately exposed in the demo and must be protected by server-side owner authorization before production. Teacher identity is selectable in Account for testing. Student names and addresses are user data and are not machine-translated when switching language. Demo teacher areas are sample data. Hourly rates currently accept whole JOD values from 1–500.

## Organization

- `App`: composition and navigation.
- `Domain`: lesson entities, booking validation, acceptance policy, persistence contract.
- `Data`: local repository and catalog fixtures.
- `Presentation`: screens and observable app state.
- `DesignSystem`: reusable cards, borders, artwork, localized UIKit text-field bridge.
- `Localization/L10n.swift`: typed enum for every UI string.
- `Resources/ar.lproj` and `en.lproj`: paired translations.

Replace local repositories with API adapters later. Payment verification, ownership, identity and the first-free allowance must be enforced by the backend rather than trusting local state.

## Verification

Xcode build succeeded during this iteration. `Tests/BookingChecks.swift` checks first-free pricing, subsequent-payment gating, owner verification, rejection and resubmission, duplicate-acceptance prevention, Arabic-number hourly rates, persistence, validation and failed-save rollback. Localization files pass plist validation. A complete interactive simulator walkthrough still needs verification; command-line simulator control is blocked by the execution sandbox.

## Manual walkthrough

1. Start → explore demo → Parent → choose a teacher → book a lesson. Confirm no upfront or booking fee.
2. Account → switch role → Teacher → set hourly rate. First acceptance is free.
3. Open another request → CliQ → submit a test reference. Acceptance must remain blocked.
4. Account → owner review → confirm receipt. Return to the request and accept.
5. Change language from Account; check dates, right/left input alignment and selected tab.

## Artwork

Only illustrated/animated-style scenes are bundled; realistic photos were discarded. SwiftUI adds subtle movement and honors Reduce Motion. See `Brand/ASSETS.md` for the image-generation prompts and asset paths.

### Registration, declarations and area matching

Both roles now complete registration before entering their dashboard. Teacher registration requires a 20–1,000 character public experience summary, one or more teaching areas, a private PDF/JPEG/PNG document up to 10 MB, and explicit acceptance of the eligibility declaration. Parent registration requires an area and explicit confirmation of age 18+, parent/guardian authority, account control and necessary lesson-data sharing. Acceptance time, wording version and UI language are persisted. Existing snapshots migrate with registration incomplete; consent is never inferred.

Parent recommendations and teacher pending-request filters match stable area IDs. The list covers all Jordanian governorates plus three Amman neighborhoods; choosing all Amman matches those neighborhoods. This is area matching, not GPS proximity. Teachers see only requests addressed to them, not a public directory of children. Existing lessons without a structured area remain visible when the area filter is switched off. Account → Complete your profile edits the profile and area preferences.

Documents remain in the app's private Application Support directory with complete file protection and exclusion from device backup. Only the opaque filename is stored in the snapshot. Public teacher views use the bio and service areas, never document metadata or contents. The prototype stores files locally; it does not upload them, verify their authenticity, or certify legal eligibility. Real authentication, private server storage, owner-only document access, retention/deletion controls and verification must be implemented in the API phase before real registration data is collected.

The bilingual declaration is draft product wording, not a legal determination. It assigns responsibility for eligibility and false statements while preserving liabilities that cannot lawfully be excluded. Have Jordanian counsel approve the terms and privacy notice before release, including applicable tutoring permissions and work permits. Reference sources: Jordan Ministry of Labour https://mol.gov.jo/EN/Pages/NonJordanian_workers and Ministry of Digital Economy personal-data law https://www.modee.gov.jo/EN/List/The_law_regulations_and_instructions .

Validation: native Xcode build passed. BookingChecks also covers rejected parent consent, saved declaration metadata, legacy decoding, missing teacher document rejection and area matching, alongside payment/rate/persistence regression checks. Both localization files pass plist validation. File-picker/device-protection behavior still needs a device walkthrough.
