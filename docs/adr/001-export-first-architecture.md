# ADR-001: Export-First Architecture

**Status:** ACCEPTED (MVP Requirement)

## Context

DailyFrame serves two distinct roles:
1. **Director/Creator Role**: Immediately review shot footage to verify quality and decide to keep/reshoot
2. **Distribution Role**: Export finalized videos to QuickTime format for external sharing, editing, or archival outside the app

The original design conflated creation with consumption; this ADR clarifies the split.

## Decision

DailyFrame is a **creation-first tool** with two critical features:

### 1. In-App Playback (QA Only)
Minimal video viewer to review just-shot footage for quality control. Director can immediately see what was captured and decide: keep or reshoot. This is a critical creation workflow, not a consumption interface.

### 2. Export to QuickTime (Distribution)
All finalized videos are exported as standard MOV files to the app's Documents/Videos directory, making them accessible for:
- External editing (Final Cut Pro, Adobe Premiere, DaVinci Resolve, etc.)
- Sharing via iOS ecosystem (AirDrop, Mail, iCloud Drive, Messages, Files app)
- Archival in standard format (not locked to app)
- Future re-import to other tools

## Rationale

1. **Creator Control:** Director sees footage immediately and owns quality decision
2. **No Vendor Lock-in:** All exported videos are standard MOV files in the filesystem
3. **Workflow Clarity:** App handles capture + QA; external tools handle editing + sharing
4. **Flexibility:** Users can edit in any video editor they choose
5. **Simplicity:** Clear separation of concerns (create → review → decide → export → edit)
6. **Privacy & Ownership:** Videos live in user's Documents directory, fully auditable and portable

## Consequences

### Positive
- Creator has immediate feedback loop (shoot → review → decide)
- Exported videos are true assets, not app-proprietary
- Seamless integration with external editing tools
- Clear workflow: DailyFrame is shooting, not editing

### Negative
- App includes QA playback (adds ~2 views), but it's minimal and purposeful
- Users responsible for managing video files outside app

## Alternative Considered

Eliminate playback entirely and use Files app for review — rejected because it breaks the director's immediate feedback loop; creators need to see footage instantly post-capture to make quality decisions.
