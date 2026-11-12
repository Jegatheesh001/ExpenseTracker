# Project Entry Point

Read `HELP.md` before starting work. It is the authoritative Expense Tracker development handbook for environment setup, source layout, architecture, persistence, security, backups, notifications, UI, testing, and release verification. If guidance conflicts, follow `HELP.md`.

## Code-specific reminders

- The application source is available in `lib/`; tests are in `test/`, and platform integration is under `android/`, `ios/`, `linux/`, `macos/`, and `web/`.
- Complete implementations only: never leave placeholders, truncated classes, omitted branches, or unhandled persistence and profile-state updates.
- Trace each feature through its screen/widget, service, SQLite and preference state, backup/restore representation, notification behavior, and native integration before declaring the work complete.
- Preserve existing user data and backup compatibility. Database schema changes require a versioned migration, fresh-install coverage, upgrade-path verification, and any necessary backup/restore updates.
- Treat financial correctness, data integrity, credential safety, privacy, accessibility, and lifecycle safety as higher priorities than visual convenience.
- **Continuous improvement (strict):** Record every durable project discovery, code fix, build optimization, architectural decision, schema change, security rule, and verified implementation lesson in `HELP.md` during the same task. Do not leave this knowledge only in chat, commits, or `AGENTS.md`.
