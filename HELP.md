# Expense Tracker Development Handbook

Compact, forward-looking rules for maintaining the Flutter Expense Tracker application. Treat **financial correctness, data integrity, security, privacy, accessibility, and lifecycle safety** as higher priority than visual polish or preserving an accidental implementation detail.

## 1. Environment

- Package: `expense_tracker`; application version: `1.6.5+26`.
- The Dart constraint in `pubspec.yaml` is `^3.8.0-278.1.beta`.
- Toolchain verified on 2026-11-12: Flutter `3.44.6` stable, Dart `3.12.2`, and DevTools `2.57.0`.
- Android is the primary integrated target. It uses application ID `com.jegatheesh.expenseTracker`, compile/target SDK 36, NDK `27.0.12077973`, and Java/Kotlin 21.
- Other platform scaffolds exist, but do not claim a feature works on iOS, Linux, macOS, or web without building and exercising that target. Several current features depend on `dart:io`, `sqflite`, mobile permissions, local notifications, sharing, audio, or native Android integration.
- Never commit API keys, signing keys, `key.properties`, keystores, tokens, private backup files, production user data, or machine-specific secrets. Keep local signing files ignored even if a new tool generates them.

Use PowerShell from the repository root:

```powershell
flutter pub get
flutter devices
flutter run
```

For verification, format only files intentionally touched, then inspect the diff before continuing:

```powershell
dart format <touched-dart-files>
flutter analyze
flutter test
```

Use `flutter build apk --debug` when changing dependencies, Android configuration, permissions, native channels, packaging, or release-sensitive code. Do not run `flutter clean` routinely; it discards build caches and is a troubleshooting step, not a correctness check.

## 2. Source and Project Map

The application source is available in the `lib/` folder. Start there for product behavior.

- `lib/main.dart`: application startup, Material themes, five-tab shell, profile refresh coordination, notification initialization, shared-text handling, app links, and the Android method channel.
- `lib/db/entity.dart`: `Expense`, `BilledItem`, `Category`, `Tag`, and `Subscription` domain/persistence models.
- `lib/db/database_helper.dart`: SQLite creation, migrations, queries, and writes. The database file is `expenses.db` in the application documents directory.
- `lib/db/persistence_context.dart`: the UI-facing persistence facade. Prefer this boundary from screens unless a database-only operation has a documented reason to use `DatabaseHelper` directly.
- `lib/screens/`: feature screens grouped by `ai`, `categories`, `dashboard`, `expenses`, `media`, `reports`, `settings`, `subscriptions`, and `transfers`.
- `lib/services/`: AI and OCR clients, backup/restore, and notification scheduling.
- `lib/utils/`: preference keys, secure credential storage, currency mapping, and subscription date calculations.
- `lib/widgets/`: reusable expense, month, subscription, search, and common widgets.
- `test/`: unit and widget regression tests.
- `assets/icon/`: app icon source assets.
- `android/`: Android manifest, Gradle configuration, app actions, launcher resources, and `MainActivity` channel/link integration.
- `ios/`, `linux/`, `macos/`, `web/`: generated or platform-specific runners; verify plugin support before modifying or advertising these targets.

Keep feature code in the closest existing module. Extract reusable behavior to `widgets`, `services`, or `utils` only when it has a clear boundary; do not turn `main.dart` or a general-purpose helper into a dumping ground.

## 3. Non-Negotiable Workflow

**Strict completion gate:** A change is not complete until affected behavior is traced end-to-end, focused tests pass, the full `flutter test` suite passes, analyzer output is reviewed, and the relevant UI flow is exercised on a supported target when behavior or rendering changed. If a gate is blocked, report the exact blocker and do not imply it passed.

1. Read `AGENTS.md`, this handbook, `pubspec.yaml`, and the relevant source under `lib/`.
2. Trace the complete flow: widget/screen input, active profile, preferences, database calls, filesystem data, service/network behavior, notifications, refresh callbacks, backup representation, and native configuration.
3. Identify compatibility constraints before editing: existing SQLite rows, saved preferences, backup files, attachment paths, scheduled notification IDs, deep links, and public model serialization.
4. Implement the smallest complete change. Keep UI rendering separate from persistence, network, date, and filesystem rules.
5. Add or update focused regression tests. Use deterministic dates and temporary data; never rely on a live network, real credentials, a developer's app data, or test order.
6. Format touched Dart files, run focused tests, run `flutter analyze`, then run the full `flutter test` suite. Build the affected platform when native or packaging behavior changed.
7. Manually verify the affected flow in light and dark themes, with the relevant profile and empty/error states. Also verify restart persistence when state is stored.
8. Report commands run, their outcomes, the device/target used for manual verification, and any remaining analyzer baseline or blocker.
9. Update `HELP.md` with durable findings during the same task.

Do not silently broaden a feature, upgrade unrelated dependencies, rewrite large files for style alone, or delete user data to make a test pass.

## 4. Dart and Flutter Standards

- Follow `flutter_lints` and keep null safety intact. Do not add new analyzer diagnostics.
- Use package imports (`package:expense_tracker/...`) consistently for application code.
- Keep widgets focused. Extract repeated or independently testable presentation, but avoid abstractions that hide simple UI behavior.
- Keep database, network, filesystem, date calculation, and notification rules out of `build` methods.
- After every `await`, confirm the owning `State` or `BuildContext` is still mounted before navigation, dialogs, snack bars, or `setState`.
- Dispose every `TextEditingController`, focus node, animation controller, stream subscription, recorder/player, language identifier, and other lifecycle-owned resource.
- Cancel or replace in-flight asynchronous work when stale results could overwrite the active profile, date, screen, or query.
- Use typed models and explicit return types. Avoid dynamic maps outside serialization, SQLite row mapping, or plugin boundaries.
- Use `const` constructors and widgets where practical, but never at the cost of incorrect dynamic state.
- Centralize preference names in `PrefKeys`, currency display in `CurrencySymbol`, and subscription calendar math in `SubscriptionDateUtils`; do not duplicate string keys or date algorithms in screens.
- Prefer `debugPrint` for useful development diagnostics. Never use `print`, expose secrets, or log complete financial records, prompts, backup contents, image bytes, or API responses containing user data.
- Comments should explain constraints and decisions, not narrate obvious syntax. Remove stale comments when behavior changes.
- Do not suppress a lint globally to avoid fixing local code. A narrow suppression needs a documented technical reason.

## 5. Application State, Profiles, and Money

- The app currently supports two local profiles and stores the active ID under `PrefKeys.profileId`, defaulting to `0`.
- Expense and subscription queries must be scoped to the active `profileId` unless the feature explicitly performs a global search. Confirm the intended scope before reusing a query.
- Profile-specific preference keys use the `<baseKey>-<profileId>` pattern. This applies to selected currency, wallet, cash, and bank balances and should be used for any equivalent per-profile preference.
- Global preferences such as theme, developer mode, status-bar visibility, backup reminders, and notification configuration must not accidentally receive a profile suffix.
- Settings highlights the persisted active profile ID and currency together so profiles using the same currency remain distinguishable. Switching profile must refresh currency, wallet/account balances, dashboard, expenses, reports, subscriptions, and any other profile-derived state. The root uses an `IndexedStack`, so off-screen tab state remains alive and must be explicitly refreshed.
- Initialize the active profile and currency before mounting Reports. Refresh its monthly and trend queries when the profile or expense data changes, while preserving the selected month and report type.
- Store money as the project's current `double` representation consistently and round only for display unless a business rule explicitly requires a stored rounding step. Never compare monetary doubles by formatted text.
- Any add, edit, delete, subscription log, restore, or transfer operation that changes an expense or account balance must keep all related values consistent. Treat multi-step financial mutations as one logical operation and avoid partial success.
- Preserve `paymentMethod` semantics (`cash`, `bank`, or absent/none) across edits, deletion reversals, backup/restore, reporting, and wallet/account updates.
- Parse user-entered amounts defensively, reject non-finite and invalid values, and present a useful validation message. Never coerce malformed input silently to a real transaction.

## 6. SQLite, Models, and Migrations

- The SQLite database is `expenses.db` in the application documents directory and is currently schema version `8`.
- Current tables are `expenses`, `categories`, `tags`, `expense_tags`, `billed_items`, and `subscriptions`.
- `expenses` stores profile, category, amount, remarks, expense/entry dates, and payment method. Tags and billed items are related records, not embedded database fields.
- Dates are serialized as ISO-8601 strings. Parse them consistently and test month-end, leap-year, timezone, and date-only behavior where relevant.
- SQLite numeric values may arrive as `int` or `double`; convert through `num` before calling `toDouble()` in resilient row mapping.
- Use bound `whereArgs`; never concatenate user-controlled values into SQL. Escape wildcard behavior deliberately for search terms when `%` and `_` should be literal.
- Use transactions for mutations spanning an expense plus tags, billed items, balances, or other dependent state. A failure must not leave orphaned or partially updated records.
- Define delete behavior explicitly. When an expense is deleted, related `expense_tags`, `billed_items`, and attachment directories must not become unmanaged remnants.
- Do not return mutable database row maps to widgets when an existing or new typed model can express the contract.
- Keep `PersistenceContext` aligned with `DatabaseHelper`; a new database capability intended for UI use needs a corresponding facade method.

For every schema change:

1. Increment the database version.
2. Add an `oldVersion < N` migration that upgrades every supported previous version in order.
3. Update fresh creation so a new install reaches the identical final schema.
4. Preserve existing rows and sensible defaults; never drop a table or column without an explicit data migration and user-approved reason.
5. Update models, queries, inserts, updates, backup export, restore import, and tests together.
6. Verify both a fresh database and an upgraded pre-change database.

## 7. Preferences and Secure Storage

- All non-secret preference names belong in `lib/utils/pref_keys.dart`. Reuse constants rather than string literals.
- `SharedPreferences` is for non-secret configuration and lightweight state, not authoritative relational data.
- Gemini and OpenAI-compatible API keys must be read and written only through `SecureStorageHelper`. It migrates legacy plaintext values out of `SharedPreferences`; preserve that cleanup behavior.
- Treat access tokens, passwords, API keys, custom authenticated endpoints, and cached sensitive AI output as secrets even if a preference key does not yet name them explicitly.
- Deleting a credential must remove both secure storage and any legacy plaintext copy.
- Never include credentials, developer-only switches, cached AI insights, or sensitive endpoint configuration in backup exports.
- When adding a preference, decide explicitly whether it is global or profile-specific, whether it is safe to export, its default, and how older installs migrate.

## 8. Backup, Restore, and Attachments

- Backup/restore is a compatibility boundary. Current exports support a text data stream and ZIP archives; ZIP archives use `backup_data.txt` and may contain `attachments/<expenseId>/<fileName>`.
- Attachments live under the application documents directory at `attachments/<expenseId>/`.
- Keep imports backward-compatible with supported legacy Base64 text backups. Do not change record delimiters, field order, or encoding casually.
- Restore preferences through an explicit allowlist. Sensitive or unknown keys must remain rejected by default.
- Validate every imported row before inserting it. Collect useful row-level errors without exposing secrets, and do not report full success when records were skipped.
- Archive entries and legacy image names are untrusted input. Reject absolute paths, `..`, separators in filenames, symlink-like escapes, and any canonical destination outside the intended temporary or attachment root.
- Bound archive entry count, expanded size, per-file size, and compression ratio before extraction to prevent resource exhaustion.
- Use unique temporary directories, close encoders/streams in `finally`, and remove temporary files after success or failure when the platform permits it.
- Never overwrite an existing attachment silently because an imported filename collides. Choose and test a deterministic collision policy.
- A backup feature change must round-trip expenses, categories, tags, billed items, subscriptions, allowed preferences, and optional attachments. It must also resynchronize notifications after restore.
- User-selected backup files may contain private financial data. Do not log their contents or upload them.

## 9. AI, OCR, Network, and Privacy

- AI behavior is implemented in `AIService`; receipt extraction is implemented in `OCRService`. Keep provider-specific request building in services, not widgets.
- Supported configuration includes Gemini and OpenAI-compatible providers. API keys come from secure storage, while non-secret model/provider selections come from preferences.
- Remote custom endpoints must use HTTPS. Plain HTTP is allowed only for explicitly recognized local development hosts such as `localhost`, `127.0.0.1`, and the Android emulator host `10.0.2.2`; do not weaken this check for arbitrary hosts.
- Normalize and validate base URLs before appending paths. Do not allow malformed URLs, embedded credentials, unexpected schemes, or user-controlled path tricks.
- Set finite connection/request timeouts and handle non-success status codes, invalid JSON, empty responses, quota errors, and offline conditions without crashing or exposing raw provider output.
- Expense remarks, categories, billed-item names, shared text, and OCR content are untrusted prompt data. Preserve prompt-boundary sanitization and never treat model output as an instruction to perform an unconfirmed financial mutation.
- Explain before transmitting expense details, receipt images, audio, or other personal data to a configured provider. Send only the minimum data required for the selected feature.
- Never log authorization headers, API keys, full prompts, receipt content, raw expense histories, or synthesized audio payloads.
- Automated tests must mock provider behavior and must never use real network calls or developer credentials.
- The in-app chatbot uses one function catalog for Gemini and OpenAI-compatible requests. `ChatbotTools` executes local queries for the profile captured by the keyed chat screen and rechecks the active preference before sending results or committing a confirmed expense. A profile switch replaces the chat and its provider history. Each new chat explains data sharing before its first request. Send bounded, task-specific tool results and leave sensitive tool arguments out of logs.
- Send OpenAI-compatible speech requests only to the configured provider. The Gemini chat disclosure names Google Cloud Text-to-Speech for unmuted replies. For an unfinished OpenAI chat turn, replace the history on reset so a pending request can only write to the list it originally captured.
- The chatbot exposes subscription listing and normalized monthly cost, wallet balance, budget status, date-range spending breakdowns, expense details, and subscription action preparation. Renewal filters use stored next billing dates and preserve per-charge currencies. Monthly cost uses the existing conversion service and reports partial totals when rates are unavailable. Wallet totals use cash plus bank when either breakdown key exists and use the stored total for legacy profiles. Budget tools read existing global limits and scope actual spending to the active profile. Tag groups omit untagged expenses and can overlap.
- Subscription preparation adds a chat review button for an owning-profile subscription. It rechecks the target and status before opening existing edit, pause/resume, skip, delete, or payment controls. A confirmed change resynchronizes reminders and refreshes Dashboard, Expenses, and Reports. Expense creation requires a local confirmation of the amount, currency, date, and existing category. Chat tool calls alone do not modify subscriptions.
- Subscription payment logging compares parsed renewal dates inside the SQLite transaction. Legacy dates with omitted fractional seconds represent the same renewal. Check owner and current payment-relevant details before advancing the renewal and inserting the expense and its tags. These tool changes use existing tables, preferences, backup formats, provider configuration, and notification IDs.

## 10. Subscriptions and Notifications

- Subscription cycles are `Weekly`, `Monthly`, and `Yearly`. Persisted values and UI choices must remain compatible with those strings unless a versioned migration is added.
- Preserve the original billing anchor day. For example, a monthly subscription starting on the 31st may clamp in February but must return to the 31st when the later month supports it.
- `SubscriptionDateUtils` is the single source for month/year clamping, catch-up, skip, and log-next-payment calculations. Do not reproduce this logic in screens or notification code.
- Logging or skipping a due subscription advances it by at least one cycle and catches overdue dates up to a future renewal date. Use a deterministic target date in tests.
- Guard bounded catch-up loops and test leap days, shorter months, due today, long-overdue dates, and year boundaries.
- `NotificationService` owns timezone initialization, permission requests, daily reminders, subscription reminders, and notification IDs.
- Reserved notification IDs are `1001` for the daily reminder, `1002` for test notifications, and `20000 + subscriptionId` for subscription reminders. Do not introduce collisions.
- Schedule in the device's resolved timezone and handle timezone lookup failure safely. Re-evaluate schedules when timezone-sensitive settings change.
- Inactive, deleted, past-due-without-a-valid-future-schedule, or disabled subscriptions must not retain active notifications.
- Resynchronize notifications after subscription changes, preference changes, restore, startup, and any date recalculation that affects a due date.
- Chat review, manual subscription logging, and Dashboard bulk logging use the same payment write. Cash maps to the owner's cash account. Bank Transfer, Debit Card, and UPI map to the owner's bank account. Credit Card, Other, and unassigned methods create an expense without changing the wallet. Preserve the original subscription label in subscription data and backups. Store `cash` or `bank` on new expenses that debited those accounts so ordinary expense edits and reversals use the same account. Expense deletion only refunds canonical account methods, so older subscription rows with raw labels do not receive an erroneous credit. Existing expenses and balances are kept as stored.
- A tracked payment charges the actual expense amount in the owner's profile currency and recomputes the wallet total from cash plus bank. Insufficient funds leave the expense, renewal, and preferences unchanged. Keep the SQLite stale-renewal check before writing wallet preferences. A local recovery record holds the original balances keyed to the expense. A total-only legacy wallet represents cash for both debits and refunds, including the payment options dialog. Startup treats a debit as committed when the inserted row exists and a refund as committed when the deleted row is absent. Preference writes finish before the SQLite commit, so recovery restores original balances only after a rollback. If removing a resolved record fails, replace it with a durable marker that retries cleanup without applying any balances. Recover before mounting the home tabs and exclude the pending record from backups. No schema or backup format changes are required.
- On insufficient funds, the shared subscription payment dialog shows the other account's balance and enables it when that account can cover the expense. None explicitly logs the expense without a debit, and Cancel leaves the renewal due. The choice applies to the individual expense. Preserve the subscription's configured payment label, recheck the owner currency and active profile before retrying, and use the same SQLite stale-renewal check and wallet recovery path. The selected `cash`, `bank`, or `none` value uses the existing expense backup representation.
- Expense deletion from day, month, detail, category, and tag views uses one profile-scoped persistence method. It deletes the expense, tags, and billed items in one SQLite transaction. Receipt cleanup runs after commit so a rollback preserves the files. ZIP backup includes receipts only for expenses in the exported records, which also excludes historical orphans and files left by a failed cleanup. The deletion shares the wallet queue and recovery record used by subscription logging. A duplicate delete finds no row and issues no second refund. Manual subscription logging from Dashboard, Settings, or a reminder and report drilldown changes invalidate Reports futures through the home refresh callback.
- Android permissions and receivers in `AndroidManifest.xml` are part of this feature. Verify runtime denial, Android exact-alarm behavior, reboot rescheduling, notification taps, and disabled permissions on a real device or emulator when this area changes.

## 11. Sharing, Links, and Native Integration

- Shared text is received through `receive_sharing_intent` and may prefill the add-expense flow. Treat shared content as untrusted and require user review before saving.
- The App Actions link host is lowercase and case-sensitive: `app://com.jegatheesh.expensetracker`. The confirmed voice-expense draft route is `/add-expense?expenseName=<remarks>&categoryName=<category>&amount=<positiveNumber>`. Keep Dart URI validation, Android intent filters, and `shortcuts.xml` synchronized.
- `app_links` is the single Android App Actions delivery path. Keep Flutter's default deep-link handler disabled through the activity's `flutter_deeplinking_enabled=false` metadata, subscribe to `uriLinkStream` once for cold and warm delivery, and do not add a competing `MainActivity` method-channel handler.
- Wallet balance queries use the `custom.actions.intent.GET_WALLET_BALANCE` App Actions widget fulfillment instead of a deep link. `WalletBalanceWidgetProvider` reads the active profile from `FlutterSharedPreferences`, decodes `shared_preferences` double strings, computes the total from cash plus bank when that breakdown exists, and supplies matching widget text and Assistant TTS. Keep the native preference keys and currency mapping synchronized with Flutter. Hide all financial values and return an unlock prompt when the device is locked.
- Assistant wallet queries are read-only: they must not open the Flutter activity or mutate SQLite, preferences, backups, notifications, or profile state. Developer-provided response speech is sent through Google Assistant, so changes to spoken financial content require a privacy review.
- Keep `launchMode="singleTask"` behavior in mind: both cold-start and already-running link paths must work without duplicate navigation.
- Always cancel the shared-intent and app-link stream subscriptions in `dispose`.
- Add only permissions required by a shipped feature. Verify the user-denied path and avoid requesting permissions before the user invokes or enables the related capability when practical.
- Native changes require an Android build plus manual verification; a passing Dart unit test is not sufficient.

## 12. UI, Theme, Accessibility, and Lifecycle

- Use Material 3 and preserve both the teal light theme and blue-grey dark theme unless a deliberate design change is requested.
- Use `Theme.of(context).colorScheme` rather than hardcoded surface/text colors so light and dark modes remain legible.
- Support narrow screens, large text, keyboard/focus navigation where applicable, and 200% text scaling without clipped financial values or inaccessible actions.
- Every icon-only action needs a tooltip or semantic label. Form fields need visible labels, validation, appropriate keyboard types, and clear error recovery.
- Confirm destructive actions such as deleting expenses, subscriptions, categories, attachments, all data, or imported-state replacement. State what will be removed.
- Use progress state for database, file, OCR, AI, backup, and restore work. Prevent duplicate submissions while a mutation is in flight.
- Preserve navigation results and refresh callbacks. Add/edit/delete screens return state to callers, and all visible cached tabs must reflect the committed result.
- Do not call `setState` after disposal or use a stale dialog context after asynchronous work. Close dialogs through the context that created them.
- Keep user-facing wording concise and consistent. If localization is introduced, move strings to a centralized localization system instead of adding more hardcoded copies.
- Respect reduced motion and avoid animation that obscures balances, due dates, errors, or progress.

## 13. Testing Standards

- Every bug fix should include a regression test where practical. Test the rule at the lowest useful level and add a widget/integration test when navigation, lifecycle, or rendering caused the defect.
- Existing coverage includes currency mapping, subscription model serialization/monthly normalization, subscription calendar rules, backup/restore serialization, security hardening, archive integrity, and notification calculations/configuration.
- Use `flutter test test/<file>.dart` for focused iteration, followed by the full `flutter test` suite.
- Tests must not depend on execution order, the current clock, a real database left on the machine, the network, real API keys, platform notification state, or shared mutable preferences.
- Inject or pass a target clock/date for date-dependent logic. Cover leap years, month ends, midnight boundaries, timezones, and overdue renewal catch-up.
- For SQLite changes, test fresh creation, migration from the prior version, typed row mapping, profile isolation, dependent record writes/deletes, and transaction rollback.
- For backup changes, test round trips, malformed/truncated rows, unknown preference keys, sensitive-key exclusion, path traversal, oversized archives, attachment collisions, and legacy input.
- For async widgets, cover loading, empty, success, error, retry, unmount-during-work, and repeated-tap behavior where relevant.
- For notifications and plugins, keep pure scheduling/calculation code testable without a platform channel; mock the platform boundary.
- Do not weaken assertions or skip tests to get a green run. Fix nondeterminism at its source.

## 14. Dependencies, Android Builds, and Releases

- Pin deliberate dependency changes in `pubspec.yaml` and commit the corresponding `pubspec.lock` update. Do not run a broad major-version upgrade as part of an unrelated feature.
- Review changelogs, platform requirements, permissions, privacy impact, licenses, and migration steps before adding or upgrading a package.
- `flutter pub get` reporting newer versions is informational; compatibility and regression verification take precedence over freshness.
- The current Android release build is configured to use the debug signing configuration. Do not describe it as production-signed. Production release work must use a protected release keystore and must never commit its credentials.
- Keep `version:` in `pubspec.yaml` synchronized with intended release name/code. Do not increment it for ordinary unshipped work unless requested.
- Before a release, run the full tests, review analyzer output, build the intended artifact, install it as an upgrade over the prior release, verify data migration, exercise backup/restore, and smoke-test profiles, expenses, attachments, AI settings, subscriptions, reminders, sharing, and app links.
- Verify a clean install separately from an upgrade. A clean install cannot prove schema migration safety.

## 15. Verified Project Baseline (2026-11-12)

- The repository was clean before these handbook files were added.
- `flutter pub get` resolves successfully with the locked dependency set.
- `flutter test` passes all 43 tests in the six current test files.
- `dart format --output=none --set-exit-if-changed lib test` reports 40 existing source/test files that are not in canonical formatter output. Do not mass-format them during an unrelated change; format touched files and keep reviewable diffs.
- `flutter analyze` completes with 126 existing diagnostics on Flutter 3.44.6. They include two warnings in `chatbot_screen.dart` plus existing infos for deprecated Flutter APIs, async `BuildContext` usage, private state return types, `print`, and style guidance. New work must not add diagnostics, and touched code should reduce relevant baseline issues when safe.
- The database schema is version 8 and includes subscriptions, billed items, tags, and profile-aware expenses.
- Backup import uses an explicit safe preference allowlist and excludes API keys, the OpenAI-compatible base URL, developer mode, and cached AI insight values.
- API key access is centralized in `SecureStorageHelper`, including removal of legacy plaintext `SharedPreferences` values.
- Subscription date regression tests encode anchor-day preservation and leap/month-end behavior; preserve these contracts when changing renewal logic.
- Subscription ownership is immutable during UI edits because the edit form carries forward the stored subscription `profileId` instead of substituting the currently active profile. Database upserts continue using the complete `Subscription.toMap()` representation so backup restore can apply the imported `profileId` when an existing subscription ID collides. Verified by `flutter test test/subscription_model_test.dart` on 2026-11-12.
- The Expenses screen category filter is transient screen state keyed by stable `categoryId`. It filters the active profile's selected day and month views, their displayed totals, and the day-over-day comparison without changing stored expenses, preferences, backups, notifications, or native integration. The stacked category/search actions require bottom list padding so the final rows remain reachable. Verified on 2026-11-12 by `flutter test test/expense_category_filter_test.dart`, the full 46-test `flutter test` suite, and a clean focused analyzer run; project-wide `flutter analyze` remains at 118 pre-existing diagnostics outside the touched files.
- The Expenses tab owns a transient `ExpenseActionMenu`: search and category filter start hidden, a small upward chevron above Add indicates the available gesture, an upward swipe on Add animates both actions into view, a downward swipe hides them, and selecting either secondary action collapses the menu. The chevron is hidden while the menu is open. Tapping Add retains the existing add-expense navigation and refresh callbacks, while accessible semantics announce the swipe hint. This presentation state does not affect SQLite, preferences, profiles, backups, notifications, or native integration. Verified on 2026-11-13 by `flutter test test/expense_action_menu_test.dart`, the full 49-test `flutter test` suite, `flutter analyze` (118 unchanged pre-existing diagnostics), a debug Android build/install through `flutter run -d emulator-5554 --debug`, and manual Android 16 checks of the Add, search, and category-filter routes in light and dark themes.
- Google Assistant/App Actions use `res/xml/shortcuts.xml`, `android.app.shortcuts` launcher metadata, the lowercase `app://com.jegatheesh.expensetracker` host, and a single `app_links` stream for cold and warm expense delivery. The en-US `custom.actions.intent.ADD_EXPENSE` action accepts two text parameters (`expenseName` and `categoryName`) plus a positive numeric `amount`, validates and bounds untrusted link input, matches categories case-insensitively, and opens a prefilled Add Expense form that the user must review and explicitly save. Unknown categories remain unselected with a visible warning, malformed/non-positive amounts do not open the form, and App Action URIs are excluded from shared-text handling. No database, preference, backup, notification, or balance mutation occurs until the existing Add Expense save path runs. Verified on 2026-11-13 with five focused parser tests, the full 54-test `flutter test` suite, `flutter analyze` (118 unchanged pre-existing diagnostics), `:app:lintDebug` on JDK 21, `flutter build apk --debug`, upgrade installation on Android 16, and cold/warm ADB/UI checks for valid expense and unknown-category flows.
- Wallet balance App Actions use `custom.actions.intent.GET_WALLET_BALANCE` with `WalletBalanceWidgetProvider` and the App Actions widgets extension so Assistant can show and speak `You have <total> <currency>: <cash> in cash and <bank> in your bank account.` without launching the Flutter activity. The provider reads only the active profile's existing Flutter preferences, supports the current INR/AED/USD/EUR/GBP mappings, computes a consistent cash-plus-bank total, and falls back to the stored wallet total for legacy profiles without breakdown keys. It hides the financial values behind the lock screen and does not alter SQLite, preferences, backup/restore data, notifications, or profile state. Verified on 2026-11-13 with three focused native unit tests, the full 54-test `flutter test` suite, `:app:lintDebug` on JDK 21, `flutter build apk --debug`, upgrade installation on Android 16, registered-provider inspection, and a live launcher-widget check showing the active profile's `548 AED`, `48 cash`, and `500 bank`; end-to-end Assistant speech still requires an en-US App Actions Test Tool preview signed into the matching Google account.
- Android release builds with R8 minification require `-dontwarn` rules for `com.google.assistant.appactions:widgets:0.0.1` transitive references (`com.google.common.flogger.**`, `dalvik.system.VMStack`, `com.google.android.gms.internal.appactions_widgets.**`) via `android/app/proguard-rules.pro` wired to `buildTypes.release` in `android/app/build.gradle`. Verified on 2026-11-13 with `flutter build apk --release` producing `build/app/outputs/flutter-apk/app-release.apk`.
- Subscription estimates use Frankfurter v2 reference rates. Compare normalized currency codes so a saved name and its ISO code count as the same currency. Dashboard and Subscriptions request only distinct foreign pairs needed for active subscriptions in the selected profile. Paused subscriptions and subscriptions owned by another profile show their original amount. The add/edit sheet requests a rate only for a valid positive foreign amount, reuses that rate as the amount changes, and discards responses from earlier selections. Explicit pull-to-refresh bypasses the freshness window for required pairs. Requests send only currency codes over HTTPS. The service shares overlapping requests per pair, uses a 10-second timeout and a 12-hour cache freshness window, validates response pairs and finite positive rates, and can fall back to a previously cached reference rate. The exchange-rate cache is global and stays outside the backup preference allowlist.
- Both recurring totals sum same-currency amounts directly and mark the estimate partial when a subscription cannot be valued in profile currency. Keep the original amount and currency in subscription rows, reminder content, and backups. An expense has no currency field, so cross-currency payment logging requires the actual amount paid in the subscription owner's profile currency, even when a reference estimate is available. Dashboard bulk logging handles matching currencies only. Logging inserts the expense and its tags and advances the renewal in one SQLite transaction. The update checks the original subscription ID, owner, renewal date, amount, and currency to prevent stale attempts and duplicate payments for the same renewal. No schema migration is required.
- Expense and balance records use the profile's configured currency for display. Changing that preference relabels existing amounts and does not revalue historical expenses or balances. Subscription currency remains explicit on each row.
- Subscription conversion verified on 2026-11-21 with the full 65-test `flutter test --no-pub` suite, `flutter analyze --no-pub` (114 existing diagnostics, four deprecated-field diagnostics removed), and `flutter build apk --debug --no-pub` on JDK 21. On a fresh Android 16 emulator, verified same-currency and foreign previews, dashboard and subscription totals, light and dark themes, profile isolation, partial totals with an unavailable rate, and use of a cached rate after an offline restart. The emulator SQLite query confirmed that logging a 10 AED subscription with 255 INR actually paid inserted one 255 INR expense with both tags, retained the original 10 AED subscription, and advanced its renewal.

- Chatbot tools verified on 2026-11-21 with nine focused dispatch and provider catalog tests, the full 74-test suite, and an Android 16 debug build. Analyzer reported 105 infos. A loopback OpenAI-compatible test provider and isolated emulator user exercised real SQLite expense details, tag/payment-method breakdown, subscription listing and totals, wallet and budget reads, cross-profile rejection, cancellation, and explicit confirmation in light mode. A dark-mode chat exercised an empty subscription result and an unset daily limit. A renewal stored without fractional seconds advanced exactly once, inserted one expense, and resynchronized its reminder. Both saved expenses and the renewal persisted after an app restart.

- Staged chatbot review on 2026-11-21 passed the nine focused tests, all 74 Flutter tests, and the Android debug build. On an isolated Android 16 user with a loopback OpenAI-compatible provider, confirming a chat subscription payment inserted one expense in the owning profile and advanced a legacy renewal date by one cycle. Both persisted after restart, and a dark-mode chat completed an empty subscription and unset daily budget query. The Reports tab retained the other profile's cached total after startup and after the payment. Its spending futures need to refresh on profile initialization, profile changes, and chat expense mutations. `flutter analyze --no-pub` reported 105 infos, including three new missing-braces diagnostics on the subscription review path.
- The staged chatbot review fixes passed 12 focused tests, all 77 Flutter tests, and the Android debug build. Regression tests cover profile changes during a pending Reports query, Reports invalidation after a mutation, failed OpenAI-compatible speech confined to its configured endpoint, and a late OpenAI reply completing after a history reset. The analyzer reported 101 existing infos after the three missing-braces diagnostics and Reports' private return type were fixed. The isolated Android 16 user showed the correct AED 55 opening total. Android System UI stopped responding during the post-fix payment smoke test, including after an emulator reboot. The post-payment and dark-mode manual checks remained incomplete.

- The Expenses tab day and month views use `getExpensesByDate`, which has sorted by `expenseDate DESC` since commit `65f5123` (2025-12-12). Category filtering preserves query order. Equal expense timestamps have no explicit tie-breaker. Add Expense defaults the expense timestamp to when the form opens and stores the selected date and time separately from the save timestamp. Expense search uses `expenseDate DESC` as well. Backup export uses the unfiltered `getExpenses` query, which orders by `entryDate DESC`. A backdated SQLite fixture confirmed the day and month views use the expense date even when the row was saved later. Chat-created expenses use a date-only expense timestamp at midnight and a separate save timestamp, which can place a newly saved row below earlier same-day entries with a time. Verified by inspecting Git history and reproducing the sort with synthetic SQLite rows on 2026-11-22.

- The 2026-11-22 staged review traced a wallet discrepancy in subscription payment logging. The chat review calls the existing subscription payment path, which stores cash or bank on the expense without debiting the matching preference. Deleting the resulting expense from the Expenses tab adds its amount to that balance. Verify the log and deletion together when changing this flow, and account for older subscription expenses when fixing balance reversals. All 77 Flutter tests and the Android debug build passed. Analyzer reported 101 infos. An Android 16 System UI ANR blocked the isolated-user payment and dark-mode smoke checks.

- Subscription wallet debits verified on 2026-11-22 with six focused tests, all 83 Flutter tests, and the Android debug build. `flutter analyze --no-pub` reported the same 101 infos. On an isolated Android 16 emulator, a light-theme chat payment of AED 20 by Bank Transfer lowered the owner's bank balance from AED 75 to AED 55 and the total from AED 100 to AED 80. The expense and advanced renewal persisted after restart, a reminder was scheduled, and deleting the expense from the Expenses tab restored the bank balance and wallet total. In dark theme, a cash payment exceeding the available balance showed the insufficient-funds message and left SQLite and preferences unchanged. Dashboard bulk logging of an AED 10 cash payment lowered cash from AED 25 to AED 15 and preserved the other profile's records. Category and tag report drilldowns still call the database deletion API directly and do not run the Expenses tab wallet reversal.

- Subscription payment alternatives verified on 2026-11-22 with three focused widget tests, all 86 Flutter tests, and the Android debug build. Analyzer reported the same 101 infos. On an isolated Android 16 emulator, a dark-theme chat payment switched from Cash to bank for one AED 30 renewal and debited only the bank account. A light-theme Dashboard payment left the renewal due when canceled, then saved one expense with `none` and advanced the renewal when confirmed. The subscription's Cash label remained set for future renewals in both cases.

- The 2026-11-22 staged review confirmed by tracing the save and delete paths that deleting a new cash or bank subscription expense from the category or tag report leaves the wallet debited. The same expense deleted from the Expenses tab takes the wallet reversal path. Test every deletion entry point against the balance of the expense's owning profile and preserve historic rows whose payments never debited that balance. The review also found that manual logging from the Subscriptions screen opened by Dashboard refreshes the wallet and Dashboard without invalidating the Reports futures. The 21 focused tests, all 86 Flutter tests, `git diff --cached --check`, and `flutter build apk --debug --no-pub` on JDK 21 passed. `flutter analyze --no-pub` reported 101 infos. This review used source tracing for the two findings and did not rerun emulator flows.

- The Reports fixes on 2026-11-22 route category and tag deletion through the same profile-scoped wallet refund as other expense views. A refund preserves the cash represented by a legacy wallet-only total and leaves old raw subscription payment labels untracked. Manual subscription logging from Dashboard, Settings, and reminder navigation now invalidates Reports through the home refresh callback. Widget tests exercised the category long-press and tag swipe, verified the owning profile passed to persistence, and checked the refreshed totals. Wallet tests covered committed and rolled-back refunds, legacy totals, and raw labels. All 92 tests and the Android debug build passed. Analysis reported 95 existing infos and no new diagnostics. Android 16 System UI stopped responding on the existing emulator after reboot and on a fresh AVD, blocking the light and dark on-device smoke tests.

- The 2026-11-22 staged review reproduced two wallet failures with temporary Flutter tests and synthetic preferences. When removal of the recovery record fails, cleanup can return successfully with the old snapshot still present. Startup recovery then restored an AED 80 snapshot over a later AED 70 balance. Verify recovery after a failed cleanup and a subsequent wallet write. A profile holding only a legacy AED 100 wallet total rejected a cash subscription debit of AED 20 because the legacy cash fallback applies only to refunds. Test both debit and refund against total-only profiles, including the cash balance shown as an alternative for a bank payment.
- Centralized expense deletion removes the row, tags, and billed items but retains the existing attachment directory. ZIP backup export scans all attachment directories, so a later backup with images can still contain receipts for deleted expenses. This was traced through SQLite deletion and the ZIP file scan during the 2026-11-22 staged review.
- The same staged review passed all 92 Flutter tests, `git diff --cached --check`, and the Android debug build on JDK 21. Analysis reported 95 infos and no warnings or errors. The Android 16 emulator was blocked by a System UI ANR, so the light and dark on-device flows could not be reverified.

- Wallet recovery and Settings fixes on 2026-11-22 passed 19 focused tests, all 98 Flutter tests, and the Android debug build on JDK 21. Analysis reported the same 95 informational diagnostics. Fault injection covered failed cleanup after both commit and rollback and verified that a later balance remained intact after reopening preferences. Filesystem tests verified that deleting one expense removes only its receipt directory and that receipt export skips folders with no matching expense. Light and dark widget tests verified switching between two profiles with the same currency, including the persisted ID and the highlighted label. The APK installed on a read-only Android 16 emulator, but a System UI ANR and a UI automation timeout blocked the interactive smoke tests.

Append new verified findings here or in a clearly named dated section when they are too specific for the permanent rules above. Include the verification command or behavior that established the finding.

- The 2026-11-22 staged review traced an outstanding Reports invalidation gap: editing or deleting an expense through the Expenses tab calls only its local refresh and wallet callback, while Reports refreshes its cached futures on the home data revision. The category, tag, and trend totals can remain stale until another invalidation or selection change. All 98 Flutter tests and the staged whitespace check passed; analysis reported 95 informational diagnostics. This finding was established by source tracing, without an on-device smoke test.

- Expenses-tab edits and deletions now notify the home expense-change callback, refreshing Reports, Dashboard, wallet, and the expense list; tag drilldowns opened from the day list forward the same notification. Two focused widget tests verify that an edit and deletion refresh cached Reports totals. All 100 tests passed with flutter test --no-pub; flutter analyze --no-pub reported the existing 95 informational diagnostics. The Android emulator contains an existing owner profile, so no destructive on-device edit or deletion was performed in this verification.

- The 2026-11-22 staged review identified a remaining wallet recovery failure path by tracing `ExpenseWalletChange.recover` and the independent Settings balance writer. If a rolled-back debit or refund is restored but both removal of its recovery record and writing the resolved marker fail, the operation reports an error while the app remains usable. A subsequent Settings balance change can then be overwritten when recovery retries the unresolved snapshot. Block all wallet writes until recovery is retired, or otherwise prevent replay over later writes; cover this combined failure and a later balance edit with fault injection. The full 100-test suite and staged whitespace check passed; analysis reported 95 informational diagnostics. No on-device flow was run in this review.
- A temporary fault-injection Flutter test reproduced the unresolved recovery replay: after both retirement writes failed, changing cash and total from 100 to 70 was overwritten to 100 by the next recovery. The test mocked SharedPreferences persistence; it did not exercise an Android storage failure.
- Wallet writes now share the database helper's serialized recovery gate, including Settings, Dashboard, transfers, expense save/edit, backup import, and delete-all. A failed recovery prevents these operations from starting; Settings no longer writes legacy balances while loading. Transfers and expense saves recheck the relevant balance after entering the gate. On 2026-11-22 fault-injection tests covered failed record removal and resolved-marker writes after debit and refund rollbacks, blocking later edits until recovery succeeds, and queue ordering. `flutter test --no-pub` passed all 103 tests, `flutter analyze --no-pub` reported the existing 95 infos, and `flutter build apk --debug --no-pub` passed. The connected Android 16 emulator has an existing owner profile; no wallet mutations or destructive manual smoke tests were performed on it.
