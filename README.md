# VADA Admin (Web)

Milestone 1 foundation for a web-only admin panel with:

- Admin login (Firebase Auth)
- Admin-only protected routes (`/dashboard`, `/fighters`)
- Fighter account management (create, edit, enable/disable)
- Fighter profile fields (name, birth date, gender, phone, email, address, primary contact)
- Firestore base collections bootstrap (`contacts`, `locations`, `schedules`, `checkins`, `notifications`)
- Localization foundation (English, Japanese, Russian, Spanish)

## Setup

1. Install dependencies:
   - `flutter pub get`
2. Run for web:
   - `flutter run -d chrome`

## Firebase Requirements

1. Configure one admin user in Auth.
2. In Firestore, create `/users/{adminUid}`:
   - `role: "admin"`
3. Deploy security rules/indexes:
   - `firebase deploy --only firestore`

## Notes

- Fighter creation uses a secondary Firebase app instance to create email/password credentials without replacing the currently signed-in admin session.
- Access disable/enable is persisted as `disabled` in `users` documents (`role: "fighter"`).
