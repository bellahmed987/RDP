# Local setup and run guide (Windows)

## Start the backend

1. Start MySQL in XAMPP. This setup uses XAMPP's MariaDB on port 3306.
2. Run the project script scripts\start-backend.ps1. It reads the ignored .env.local, creates the database if needed, and starts Spring Boot.
3. Wait for the Spring Boot “Started RdpApplication” message. Swagger is at http://localhost:8080/swagger-ui.html.

The default local database is jdbc:mariadb://localhost:3306/resource_distribution_db with user root and an empty password. Change DB_URL, DB_USERNAME, or DB_PASSWORD in .env.local if your XAMPP setup differs. Hibernate updates local schema automatically.

The first startup creates an administrator only when ADMIN_EMAIL and ADMIN_PASSWORD (12+ characters) are set. Optional demo donor and recipient accounts are created when SEED_DEMO_PASSWORD is set. The generated local credentials are in ignored README.local.md.

## Run the Android app

Start the Android emulator from Android Studio Device Manager; the prepared virtual device is named RDP_Emulator. Then, in a second terminal, run scripts\start-mobile.ps1. The Android emulator reaches the computer's API at http://10.0.2.2:8080/api.

For a physical phone on the same network:

    cd mobile
    flutter run --dart-define=API_BASE_URL=http://YOUR_COMPUTER_LAN_IP:8080/api

## Google sign-in

Google sign-in is optional and requires OAuth configuration in a Google Cloud project:

1. Configure the OAuth consent screen and create an **Android** OAuth client for package `edu.rdp.resource_distribution_app`. While the consent screen is in Testing mode, add the Google accounts you’ll use under Test users.
2. Add the SHA-1 fingerprint for the signing key you use. For the local debug key, run:

       keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android

3. Create a **Web application** OAuth client. Put that Web client ID in the ignored `.env.local` as `GOOGLE_CLIENT_ID=...`. This is a client ID, not a client secret.
4. Restart the backend and run `scripts\start-mobile.ps1`. The script uses the same client ID for Flutter and the backend. For APK builds, `scripts\build-android.ps1` passes it to Flutter as well.

The backend verifies Google's signed ID token before creating an app session. First-time Google users choose Donor or Recipient. Existing Donor and Recipient accounts with the same verified email are linked; Admin accounts must continue using administrator sign-in. Without `GOOGLE_CLIENT_ID`, password sign-in continues to work and Google sign-in reports that setup is required.

Build a debug APK with scripts\build-android.ps1. Output path: mobile\build\app\outputs\flutter-apk\app-debug.apk.

## Optional Google Maps

Add MAPS_API_KEY=your-key to mobile/android/local.properties. Then start or build the Flutter app with the dart define GOOGLE_MAPS_ENABLED=true. Restrict the key to Android package edu.rdp.resource_distribution_app and Maps SDK for Android. Never commit the key.

## Optional Firebase push notifications

Set FCM_ENABLED=true and FIREBASE_CREDENTIALS=C:\path\to\firebase-service-account.json in .env.local. The Android app also needs the Firebase Android configuration file google-services.json and FlutterFire initialization to receive device tokens. Without credentials, backend startup and in-app notifications continue to work.

## Tests and builds

scripts\test-all.ps1 runs Maven verification, Flutter analysis, Flutter tests, and builds the debug APK. Backend integration tests use a private in-memory H2 database; normal application data is stored in MariaDB.

Stop Spring Boot with Ctrl+C. Stop MariaDB through XAMPP Control Panel.
