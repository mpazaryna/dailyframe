# ADR-005: Privacy and Scope Boundaries

**Status:** ACCEPTED

## Context

Video diary apps exist on a spectrum from private journals to social platforms. Apps like 1SE (One Second Everyday) blend personal capture with sharing features and subscription models. DailyFrame needs clear boundaries around what it is and isn't.

Additionally, the app could expand to capture photos, integrate with social platforms, or add cloud accounts. Each expansion adds complexity, privacy implications, and maintenance burden.

## Decision

DailyFrame enforces strict boundaries:

### 1. Video Only
Capture video, not photos. One medium, one constraint. This focuses development effort and creates a clear identity.

### 2. No Social Media Integration
Zero integration with social platforms—no share-to-Instagram, no TikTok export, no Twitter posting. The share sheet exists to send videos to people (Messages, AirDrop, Mail) or save to personal apps (Apple Journal, Notes, Files), not to broadcast.

### 3. No External Accounts
The only cloud service is the user's personal iCloud. No app accounts, no third-party analytics, no telemetry, no tracking. If iCloud is unavailable, the app falls back to local storage.

### 4. Simple Pricing Model
One-time purchase at an accessible price point. No subscriptions, no premium tiers, no in-app purchases, no ads.

## Rationale

1. **Privacy by Design:** No accounts means no data to breach. No analytics means no behavior to monetize. Videos stay on the user's devices and their personal iCloud.

2. **Reduced Attack Surface:** Every integration is a potential vulnerability. Social media APIs change, require maintenance, and create dependencies on external services.

3. **Clarity of Purpose:** Constraints create focus. "Video diary that stays private" is easier to understand than "video diary with optional sharing to 12 platforms."

4. **Sustainable Development:** A hobby project can't maintain integrations with shifting social media APIs. A one-time purchase can fund occasional updates without requiring ongoing revenue.

5. **User Trust:** Users can trust that their daily moments won't accidentally end up on social media. The share sheet is explicit and intentional.

## Consequences

### Positive
- Complete privacy—no data leaves user's control
- No ongoing API maintenance for social platforms
- Clear value proposition for App Store listing
- Sustainable as a side project

### Negative
- Users who want direct social sharing must use system share sheet and platform's own apps
- No viral growth mechanism (by design)
- Revenue limited to one-time purchases

## Alternatives Considered

1. **Optional social integrations** — Rejected because "optional" becomes expected, and every integration requires maintenance.

2. **Subscription model** — Rejected because it creates pressure to add features to justify ongoing payment. One-time purchase aligns incentives: ship a complete app.

3. **Photo + video capture** — Rejected to maintain focus. Photos are well-served by other apps. Video diary is the niche.
