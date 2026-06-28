# GuardianEye - Flutter App

Safety. Vision. Care. - Track and support impaired persons with smart device integration.

## Project Structure

```
guardian_eye_app/
├── lib/
│   ├── main.dart                          # App entry point
│   ├── app.dart                           # MaterialApp configuration
│   │
│   ├── config/
│   │   └── routes/
│   │       └── app_router.dart            # GoRouter configuration
│   │
│   ├── core/
│   │   ├── constants/
│   │   │   ├── app_constants.dart         # App-wide constants
│   │   │   ├── asset_paths.dart           # Asset path constants
│   │   │   └── route_paths.dart           # Route path constants
│   │   ├── di/
│   │   │   └── injection.dart             # Dependency injection (GetIt)
│   │   ├── errors/
│   │   │   └── failures.dart              # Failure classes
│   │   └── theme/
│   │       ├── app_colors.dart            # Color palette
│   │       ├── app_text_styles.dart       # Typography
│   │       └── app_theme.dart             # ThemeData configuration
│   │
│   ├── features/
│   │   ├── auth/
│   │   │   ├── data/
│   │   │   │   ├── datasources/
│   │   │   │   ├── models/
│   │   │   │   └── repositories/
│   │   │   ├── domain/
│   │   │   │   ├── entities/
│   │   │   │   ├── repositories/
│   │   │   │   └── usecases/
│   │   │   └── presentation/
│   │   │       └── screens/
│   │   │           ├── splash_screen.dart
│   │   │           ├── role_selection_screen.dart
│   │   │           └── login_screen.dart
│   │   │
│   │   ├── pairing/
│   │   │   └── presentation/
│   │   │       └── screens/
│   │   │           ├── qr_scan_screen.dart
│   │   │           ├── pairing_code_screen.dart
│   │   │           ├── pairing_success_screen.dart
│   │   │           └── add_person_screen.dart
│   │   │
│   │   ├── guardian/
│   │   │   └── presentation/
│   │   │       └── screens/
│   │   │           ├── guardian_home_screen.dart
│   │   │           └── tracking_map_screen.dart
│   │   │
│   │   ├── tracking/
│   │   │   ├── data/
│   │   │   │   ├── datasources/
│   │   │   │   └── repositories/
│   │   │   └── domain/
│   │   │       ├── entities/
│   │   │       ├── repositories/
│   │   │       └── usecases/
│   │   │
│   │   ├── profile/
│   │   │   └── presentation/
│   │   │       └── screens/
│   │   │           └── profile_screen.dart
│   │   │
│   │   └── settings/
│   │       └── presentation/
│   │           └── screens/
│   │               └── settings_screen.dart
│   │
│   └── shared/
│       └── widgets/
│           ├── guardian_logo.dart
│           ├── primary_button.dart
│           └── custom_text_field.dart
│
├── assets/
│   ├── fonts/
│   │   └── Poppins-*.ttf
│   ├── images/
│   │   ├── logo/
│   │   ├── onboarding/
│   │   ├── roles/
│   │   └── placeholders/
│   ├── icons/
│   │   ├── markers/
│   │   └── ui/
│   └── animations/
│
└── pubspec.yaml
```

## Features

- **Authentication**: Login/Register with role selection (Guardian/User)
- **Device Pairing**: QR code scanning and manual code entry
- **Guardian Dashboard**: Overview of tracked people with status
- **Live Tracking**: Real-time location tracking on map
- **Profile Management**: User profile and account settings
- **Settings**: Notifications, privacy, and appearance settings

## Removed Features (as requested)

- Camera streaming
- Video call functionality

## Setup Instructions

### 1. Download the Project

Click the **three dots (...)** in the top right corner and select **"Download ZIP"**

### 2. Extract and Navigate

```bash
unzip guardian_eye_app.zip
cd guardian_eye_app
```

### 3. Add Font Files

Download Poppins font from Google Fonts and place in `assets/fonts/`:
- Poppins-Regular.ttf
- Poppins-Medium.ttf
- Poppins-SemiBold.ttf
- Poppins-Bold.ttf

### 4. Install Dependencies

```bash
flutter pub get
```

### 5. Run the App

```bash
flutter run
```

## Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| flutter_riverpod | ^2.4.9 | State management |
| go_router | ^13.2.0 | Navigation |
| get_it | ^7.6.7 | Dependency injection |
| dartz | ^0.10.1 | Functional programming |
| shared_preferences | ^2.2.2 | Local storage |
| google_fonts | ^6.1.0 | Typography |
| equatable | ^2.0.5 | Value equality |
| google_maps_flutter | ^2.5.3 | Map integration |
| geolocator | ^10.1.0 | Location services |
| flutter_animate | ^4.3.0 | Animations |

## Architecture

This project follows **Clean Architecture** with:

- **Domain Layer**: Entities, Repositories (interfaces), Use Cases
- **Data Layer**: Models, Data Sources, Repository Implementations
- **Presentation Layer**: Screens, Widgets, State Management

## Screens

1. **Splash Screen** - Animated logo with loading
2. **Role Selection** - Choose Guardian or User role
3. **Login Screen** - Email/password authentication

5. **Pairing Code Screen** - Enter 6-digit pairing code
6. **Pairing Success Screen** - Confirmation with user details
7. **Add Person Screen** - Add tracked person details
8. **Guardian Home Screen** - Dashboard with stats and tracked people
9. **Tracking Map Screen** - Live location map view
10. **Profile Screen** - User profile and account info
11. **Settings Screen** - App settings and preferences

## Color Palette

| Color | Hex | Usage |
|-------|-----|-------|
| Primary | #2D9CDB | Main actions, buttons |
| Primary Light | #56CCF2 | Accents, highlights |
| Secondary | #0F4C81 | Headers, text |
| Success | #27AE60 | Online status, confirmations |
| Error | #EB5757 | Errors, destructive actions |
| Warning | #F2994A | Low battery, alerts |
| Background | #F8F9FB | Page backgrounds |
| Surface | #FFFFFF | Cards, surfaces |

## Typography

- **Font Family**: Poppins
- **Headings**: Bold/SemiBold, 18-32px
- **Body**: Regular, 14-16px
- **Captions**: Regular, 12px
