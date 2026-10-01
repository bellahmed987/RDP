# API overview

Interactive API reference: http://localhost:8080/swagger-ui.html

Authenticated endpoints expect the Authorization header with Bearer and a JWT. Register accepts DONOR or RECIPIENT; normal users cannot self-create administrators. JSON is used except image uploads, which use multipart/form-data.

Google sign-in accepts `POST /api/auth/google` with an ID token from Google. Existing Donor and Recipient accounts receive an app JWT. For a first-time account, the response sets `requiresRole: true`; send the same ID token again with `role: DONOR` or `role: RECIPIENT` to create the account. Admin accounts cannot use Google sign-in.

| Area | Main routes |
|---|---|
| Auth/profile | POST /api/auth/register, POST /api/auth/login, POST /api/auth/google, GET /api/auth/me, POST /api/auth/logout, GET/PUT /api/profile |
| Browse | GET /api/donations?q=&category=&city=, GET /api/donations/nearby?latitude=&longitude=&radiusKm=, GET /api/donations/{id} |
| Donor | GET /api/donations/mine, POST /api/donations, PUT/DELETE /api/donations/{id}, POST /api/donations/{id}/images |
| Requests | POST /api/donations/{id}/requests, GET /api/requests/mine, GET /api/requests/incoming, PATCH /api/requests/{id}/decision, /cancel, /complete |
| Recipient | GET/POST/DELETE /api/favorites, GET /api/recommendations, POST /api/requests/{id}/rating |
| Chat | POST /api/requests/{id}/conversation, GET /api/conversations, GET/POST /api/conversations/{id}/messages, STOMP endpoint /ws |
| Notifications | GET /api/notifications, PATCH /api/notifications/{id}/read, PUT /api/notifications/device-token |
| Reports/admin | POST /api/reports, GET /api/admin/stats, GET /api/admin/users, PATCH /api/admin/users/{id}/status, GET /api/admin/donations, GET/PATCH /api/admin/reports |
| Help | POST /api/chatbot |

Categories are FOOD, CLOTHING, ELECTRONICS, BOOKS, FURNITURE, TOYS, HOUSEHOLD, OTHER. Requests move through PENDING, ACCEPTED, REJECTED, CANCELLED, COMPLETED. Chat access is limited to the donor and recipient after request acceptance. Location-radius discovery requires actual coordinates. Donors and recipients arrange pickup directly.
