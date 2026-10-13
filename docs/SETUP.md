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

Build a debug APK with scripts\build-android.ps1. Output path: mobile\build\app\outputs\flutter-apk\app-debug.apk.

## MapTiler maps

The donor listing form uses the map to place a pickup pin. Search for a city, area, or address in the picker to move the pin, or tap the map to place it manually. Recipients can open an individual pickup map or switch Explore to a map of listings; Nearby lets them search for a place or choose a point on the map and a radius. The app saves listing coordinates in the backend and loads MapTiler raster tiles with flutter_map; place search uses the MapTiler Geocoding API with the same API key.

The client-side MapTiler key is included in mobile/maptiler.env.json as MAPTILER_API_KEY, and the project launch and build scripts pass it to Flutter automatically. This key is public in the GitHub repository and in the compiled app. Restrict it in MapTiler to the app's User-Agent string, flutter_map (edu.rdp.resource_distribution_app), and monitor account usage. Map tiles must retain MapTiler and OpenStreetMap attribution.

For a physical phone, run flutter from the mobile folder with --dart-define-from-file=maptiler.env.json and set API_BASE_URL for your computer’s LAN address.

## Optional Firebase push notifications

Set FCM_ENABLED=true and FIREBASE_CREDENTIALS=C:\path\to\firebase-service-account.json in .env.local. The Android app also needs the Firebase Android configuration file google-services.json and FlutterFire initialization to receive device tokens. Without credentials, backend startup and in-app notifications continue to work.

## Tests and builds

scripts\test-all.ps1 runs Maven verification, Flutter analysis, Flutter tests, and builds the debug APK. Backend integration tests use a private in-memory H2 database; normal application data is stored in MariaDB.

Stop Spring Boot with Ctrl+C. Stop MariaDB through XAMPP Control Panel.
