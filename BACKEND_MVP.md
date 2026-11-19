# Shared backend integration

Active app entry: splash → backend login/registration → parent/teacher profile setup → live tabs. ADMIN users get owner certificate/payment/support review. Old local demonstration views remain in source but are not used by the live entry flow.

Set `DaamApp/Resources/BackendConfig.plist` → `BaseURL`. Default: `http://localhost:8080` for Debug iOS Simulator only. A physical iPhone or Release build requires HTTPS. Invalid configuration shows an explicit setup message instead of entering the demo. The app does not start the backend automatically.

The new backend database is separate from Supabase; old accounts have not been migrated. Backend details and run commands: `/Users/waedsaraireh/Documents/DaamBackend/MVP_API.md`.

New live UI uses typed L10n keys, Arabic/English resources, existing page borders/artwork/system fonts, and red saved hearts. Teacher area matching uses the Jordan area catalog; certificates are private. Parents pay cash; teacher acceptance fee is read from the server and requires owner verification after the first free lesson.

Contract checks (macOS command line):

```sh
swiftc -parse-as-library -module-cache-path /tmp/daam-swift-cache \
  DaamApp/Data/AuthenticationService.swift DaamApp/Data/TutoringAPI.swift \
  DaamApp/Localization/L10n.swift Tests/BackendContractChecks.swift \
  -o /tmp/daam-contract-checks
/tmp/daam-contract-checks
```

These use an in-memory session store and stub transport, not real users or email. They check login decoding, bearer headers/query URLs, fractional/nonfractional timestamps, server error codes, logout clearing and auth deep-link validation. Native Xcode build is used because this sandbox blocks SwiftUI macro plugin execution in command-line xcodebuild.
