# Firebase push setup

ShareKind now registers the signed-in Android device with FCM and the backend sends the saved notification through Firebase. Push cannot be delivered until both sides use the same Firebase project.

1. In Firebase Console, create or select a project and add an Android app with package name `edu.rdp.resource_distribution_app`.
2. Download that app's `google-services.json` and put it at `mobile/android/app/google-services.json`. The app applies the Google Services Gradle plugin when this file exists.
3. In Firebase Project settings, create a service account key for the Firebase Admin SDK. Save it locally as `backend/secrets/firebase-service-account.json`; do not commit or share this private key.
4. Edit the ignored `.env.local` file in the project root and set `FCM_ENABLED=true` plus `FIREBASE_CREDENTIALS` to that file's absolute path, for example:

   ```powershell
   FCM_ENABLED=true
   FIREBASE_CREDENTIALS=C:\Projects\ResourceDistributionPlatform\backend\secrets\firebase-service-account.json
   ```

   Then start the backend:

   ```powershell
   .\scripts\start-backend.ps1
   ```

5. Rebuild and reinstall the app, sign in, and allow notifications when Android asks. The app uploads the current device token after sign-in.

Android shows FCM notification payloads while ShareKind is backgrounded or closed. When the app is open, Flutter displays the incoming FCM notification as a system notification. Android 13+ requires notification permission. Force-stopping ShareKind in Android settings prevents delivery until it is opened again.

Voice calls currently signal through the live chat connection, so both people need to have that chat open to receive or answer a call. While the chat is open, calls show a full-screen incoming, outgoing, or connected call view with accept, decline, hang up, mute, and speaker controls. Calls do not ring when ShareKind is backgrounded or closed; background calling needs Firebase call invitations and Android's native incoming-call UI. Calls use a public STUN server; some restrictive mobile networks require a TURN relay to connect reliably.
