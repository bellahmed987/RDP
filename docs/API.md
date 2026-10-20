# API overview

Interactive API reference: http://localhost:8080/swagger-ui.html

Authenticated endpoints expect the Authorization header with Bearer and a JWT. Register accepts DONOR or RECIPIENT; normal users cannot self-create administrators. JSON is used except image uploads, which use multipart/form-data.

| Area | Main routes |
|---|---|
| Auth/profile | POST /api/auth/register, POST /api/auth/login, GET /api/auth/me, POST /api/auth/logout, GET/PUT /api/profile, GET /api/donors/{id}/profile |
| Browse | GET /api/donations?q=&category=&city=, GET /api/donations/nearby?latitude=&longitude=&radiusKm=, GET /api/donations/{id} |
| Donor | GET /api/donations/mine, POST /api/donations, PUT/DELETE /api/donations/{id}, POST /api/donations/{id}/images |
| Requests | POST /api/donations/{id}/requests, GET /api/requests/mine, GET /api/requests/incoming, PATCH /api/requests/{id}/decision, /cancel, /complete |
| Recipient | GET/POST/DELETE /api/favorites, GET /api/recommendations, POST /api/requests/{id}/rating |
| Chat | POST /api/donations/{id}/conversation (recipient contacts donor before requesting), POST /api/requests/{id}/conversation, GET /api/conversations, GET/POST /api/conversations/{id}/messages, STOMP endpoint /ws |
| Notifications | GET /api/notifications, PATCH /api/notifications/{id}/read, PUT /api/notifications/device-token |
| Reports/admin | POST /api/reports, GET /api/admin/stats, GET /api/admin/users, PATCH /api/admin/users/{id}/status, GET /api/admin/donations, GET/PATCH /api/admin/reports |
| Help | POST /api/chatbot |

Categories are FOOD, CLOTHING, ELECTRONICS, BOOKS, FURNITURE, TOYS, HOUSEHOLD, OTHER. Requests move through PENDING, ACCEPTED, REJECTED, CANCELLED, COMPLETED. A recipient can start a private conversation from an available listing before requesting it; the same donor-recipient thread is reused across that pair's listings and any later accepted requests. Location-radius discovery requires actual coordinates. Donors and recipients arrange pickup directly.
