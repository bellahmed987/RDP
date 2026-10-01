# ShareKind (Resource Distribution Platform)

An Android-first community platform for sharing surplus resources. Donors can publish items with up to five PNG or JPEG photos and arrange pickup directly with recipients; there is no delivery service.

## Start locally

1. Start MySQL in the XAMPP Control Panel.
2. Run .\scripts\start-backend.ps1 from the project folder.
3. In another PowerShell window, run .\scripts\start-mobile.ps1.
4. Open http://localhost:8080/swagger-ui.html for the API.

The local administrator and demo credentials are written to the ignored README.local.md. Change them before sharing this project. Normal registration can create donors and recipients only.

## Project folders

- backend: Java 21, Spring Boot REST API, MariaDB, JWT security, STOMP chat, OpenAPI, local recommendations and chatbot providers.
- mobile: Flutter Android app with secure token storage, product photo selection and upload, and REST/WebSocket client.
- docs: setup, API overview, tests, and optional integrations.
- scripts: PowerShell commands to start, test, and build.

Run .\scripts\test-all.ps1 to verify backend and mobile builds.

Optional integrations and more detailed instructions are in docs/SETUP.md.
