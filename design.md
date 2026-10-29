# ShareKind UI Design Brief

## Product

ShareKind helps people donate useful items and helps nearby recipients request them. The app supports donor and recipient accounts, item listings, map-based pickup locations, requests, chat, notifications, calls, and an admin area.

The design should feel trustworthy, humane, practical, and easy to use on a phone. Prioritize clear next steps and readable information over decoration.

## Visual direction

Use a deep charcoal foundation with vivid teal as the primary action color. Keep the interface warm and community-minded with amber highlights used sparingly and restrained coral for destructive or urgent states. Use clear layers between the page, cards, and inputs. Listing photos should lead each card, while status, donor identity, location, and next actions remain easy to scan.

| Token | Value | Use |
| --- | --- | --- |
| Page background | `#0C1114` | Main app background |
| Raised surface | `#151D21` | Cards, forms, dialogs |
| Navigation surface | `#11181C` | Bottom navigation |
| Primary teal | `#20DFBD` | Main actions, links, selected icons |
| Deep teal | `#123A34` | Brand and supporting emphasis |
| Warm amber | `#FFC66D` | Small highlights and secondary emphasis |
| Primary text | `#EDF5F0` | Headings and important content |
| Secondary text | `#AEBDBF` | Supporting text and metadata |
| Border | `#29383C` | Input outlines and separators |
| Error | Use the theme error color | Validation and destructive feedback |

Use the current Material 3 theme as the source of shared colors. Do not add unrelated per-screen colors. Check contrast for all text, icons, badges, and disabled controls.

## Layout and type

- Design for narrow Android phones first; keep content usable on larger phones and tablets.
- Use an 8 dp spacing rhythm. Keep screen edges around 20–24 dp and group related controls closely.
- Use one clear screen title, short section headings, and concise labels.
- Use the platform system font. Use bold weights for titles and card names, regular weight for body text, and muted text for metadata.
- Keep tap targets at least 48 dp. Keep primary actions easy to reach and visually distinct.
- Avoid long forms in one scroll when a clear, staged flow is possible.

## Shared components

- **App bar:** ShareKind mark, current section title, notification action, help, and sign-out where appropriate. Keep action icons consistent and give icon-only controls tooltips or semantic labels.
- **Cards:** Raised dark surface, consistent rounded corners, modest separation, and clear hierarchy. Listing cards should show the item, availability, location, and one obvious next action.
- **Buttons:** One primary filled action per decision area; secondary actions use outlined or text styles. Destructive actions require clear labels and confirmation when they cannot be undone.
- **Forms:** Persistent labels, appropriate keyboard types, inline validation, and useful error text. Keep sensitive answers masked only when the user expects it.
- **Status badges:** Reuse a small, consistent set of colors and labels for pending, accepted, ongoing, completed, cancelled, and rejected states.
- **Feedback:** Show loading, empty, success, and failure states close to the affected content. Never leave a button appearing active while its request is in progress.
- **Motion:** Keep transitions short and subtle. Animation should clarify navigation or state changes and must not delay an action.

## Navigation and role-specific screens

Keep role-based navigation simple and predictable. Show only the sections that apply to the signed-in role, while keeping chats, notifications, profile, and sign-out easy to find.

For recipient accounts, keep four primary bottom destinations: Explore, Requests, Chats, and Profile. Expose Favorites and personalized recommendations as prominent shortcuts on Explore, with a clear route back to Explore from those secondary screens.

### Recipients

- **Explore:** Search and filter listings, switch between list and map, and make distance/location information easy to scan.
- **Listing details:** Show item photos, description, donor profile, pickup location, availability, and actions to message or request.
- **My Requests:** Provide clear Pending, Accepted, Ongoing, Completed, and Cancelled views with the next available action for each request.
- **Favorites:** Keep saved items easy to revisit.

### Donors

- **My Listings:** Separate available and unavailable items. Make create, edit, and delete actions discoverable from the donor’s own listing.
- **Incoming Requests:** Make recipient identity, requested quantity, message, and request status clear. Put accept and reject actions together and confirm their result.
- **Pickup and completion:** Once accepted, show the pickup address/map and the action to mark the donation complete.

### Admins

- Treat the dashboard as a management entry point, not just a set of numbers. Each statistic should open its matching filtered management screen.
- Provide clear search, role/status filters, and record details for accounts, listings, requests, and reports.
- Keep approve, reject, suspend, restore, and other management actions visible and confirm meaningful changes.
- Ensure a Donors view contains donors only and a Recipients view contains recipients only.

## Chat and calls

- Render messages as separate left/right bubbles with readable timestamps and clear sender ownership.
- Keep the latest conversation at the top of the inbox and show a useful last-message preview and unread indicator.
- Place call and conversation actions in a consistent header menu. Voice message recording must clearly show recording, send, cancel, and playback states.
- For calls, use a focused full-screen or prominent call view with caller identity, connection/ringing state, mute, speaker, and end-call controls. Make the end-call action unmistakable.
- Show shared locations as tappable map previews with a text fallback.

## Account flows

- **Sign in:** Username and password, with clear validation, loading feedback, and a visible password recovery path.
- **Create account:** First collect account details; continue to a separate recovery-question step; then show a persistent success confirmation and return to sign-in. Do not sign the user in automatically after signup.
- Present account creation as a guided two-step flow with a visible progress indicator and clear donor/recipient choices.
- Keep recovery questions and password reset language plain and private. Never display stored answers after setup.

## Maps and location

- Keep map and search behavior consistent between browsing listings, selecting a pickup point, and viewing an accepted request.
- Show a selected address in text beside the map pin so users can confirm the place before saving.
- Ask for location permission only when a location feature needs it. Offer manual search or address entry when permission is unavailable.

## Accessibility and quality bar

- Maintain readable contrast and support larger text without clipped controls.
- Use text labels in addition to color for request, account, and report states.
- Provide semantic labels for icon-only buttons, maps, images, and call controls.
- Keep keyboard focus and form validation usable on small screens.
- Before calling a screen finished, review loading, empty, success, error, and offline states as well as the normal state.

## Implementation guidance

- The Flutter app is in `mobile/lib/main.dart`; the shared theme is defined near `RdpApp`.
- Reuse the existing Material 3 theme and shared widgets before introducing new styling.
- Keep backend behavior and API contracts unchanged during visual-only work unless a UI feature requires a specific missing data field.
- Build small screen-sized changes that preserve the donor, recipient, and admin role flows.
