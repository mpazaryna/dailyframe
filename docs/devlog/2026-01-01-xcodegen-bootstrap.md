# XcodeGen Bootstrap: Declarative Project Configuration

**Date:** 2026-01-01

## Summary

Bootstrapped DailyFrame using XcodeGen instead of a native `.xcodeproj`. This enables declarative project configuration via `project.yml`, eliminates merge conflicts, and makes the project structure auditable and reproducible.

## Why XcodeGen

Native Xcode projects (`.xcodeproj`) are opaque binary-ish plists that:
- Generate constant merge conflicts in team environments
- Accumulate cruft over time (dead file references, orphaned build phases)
- Are difficult to audit or understand at a glance
- Can't be meaningfully reviewed in PRs

XcodeGen solves this with a single `project.yml` that describes the project declaratively. Run `xcodegen generate` and you get a fresh `.xcodeproj` every time.

**For agentic programming**, this is critical: an AI agent can read and modify `project.yml` directly, understanding exactly what build settings exist and why. No parsing XML plists or navigating Xcode's GUI.

## Project Structure

```yaml
name: DailyFrame
options:
  bundleIdPrefix: com.paz
  deploymentTarget:
    iOS: "26.0"
    macOS: "26.0"

targets:
  DailyFrame-iOS:
    type: application
    platform: iOS
    sources:
      - path: DailyFrame
    settings:
      PRODUCT_BUNDLE_IDENTIFIER: com.paz.dailyframe
      DEVELOPMENT_TEAM: KDZZFKGF55
      # ...

  DailyFrame-macOS:
    type: application
    platform: macOS
    sources:
      - path: DailyFrame
    settings:
      PRODUCT_BUNDLE_IDENTIFIER: com.paz.dailyframe.macos
      DEVELOPMENT_TEAM: KDZZFKGF55
      # ...
```

## Key Decisions

### Separate Targets, Not Mac Catalyst

We use two native targets (`DailyFrame-iOS` and `DailyFrame-macOS`) sharing the same source folder, rather than Mac Catalyst. This gives us:
- Native macOS window chrome and menu bar
- No "Designed for iPad" compatibility shims
- Full control over platform-specific behavior via `#if os(iOS)` / `#if os(macOS)`

```yaml
SUPPORTS_MACCATALYST: false
SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD: false
```

### Shared Sources with Platform Compilation

Both targets point to the same `DailyFrame/` source folder:

```yaml
sources:
  - path: DailyFrame
    excludes:
      - "**/.DS_Store"
```

Platform differences are handled in code with conditional compilation, not separate source folders. This keeps the codebase unified while allowing platform-specific behavior.

### Persisted Development Team

Initially, `DEVELOPMENT_TEAM` was set manually in Xcode and lost on every `xcodegen generate`. Now it's in `project.yml`:

```yaml
DEVELOPMENT_TEAM: KDZZFKGF55
```

This ensures signing works immediately after regenerating the project—no manual Xcode configuration needed.

### Info.plist and Entitlements

Rather than letting Xcode auto-generate these, we maintain explicit files:

```yaml
GENERATE_INFOPLIST_FILE: false
INFOPLIST_FILE: DailyFrame/Info.plist
CODE_SIGN_ENTITLEMENTS: DailyFrame/DailyFrame.entitlements
```

This gives us full control over:
- Camera/microphone usage descriptions
- iCloud container identifiers
- App Transport Security settings
- Any future entitlements

### Explicit Schemes

Each target gets an explicit scheme with all actions defined:

```yaml
schemes:
  DailyFrame-iOS:
    build:
      targets:
        DailyFrame-iOS: all
    run:
      config: Debug
    archive:
      config: Release
```

This prevents Xcode from auto-creating schemes and ensures consistent behavior.

## Workflow

```bash
# After any project.yml change
xcodegen generate

# One-liner to regenerate and open
xcodegen generate && open DailyFrame.xcodeproj
```

The `.xcodeproj` is gitignored (or could be)—`project.yml` is the source of truth.

## Lessons Learned

1. **Persist everything in project.yml**: Any setting you configure in Xcode's GUI will be lost on regenerate. If it matters, it belongs in `project.yml`.

2. **Use `excludes` for noise**: DS_Store files, build artifacts, etc. should be excluded from sources.

3. **Explicit over implicit**: `GENERATE_INFOPLIST_FILE: false` prevents Xcode from "helping" in ways that conflict with your explicit config.

4. **Schemes matter**: Without explicit schemes, Xcode creates them automatically with potentially different settings.

## Files

- `project.yml` - XcodeGen configuration (97 lines)
- `DailyFrame/Info.plist` - App metadata and permissions
- `DailyFrame/DailyFrame.entitlements` - iCloud and app capabilities
- `.gitignore` - Excludes generated `.xcodeproj` artifacts

## References

- [XcodeGen Documentation](https://github.com/yonaskolb/XcodeGen)
- [project.yml Spec](https://github.com/yonaskolb/XcodeGen/blob/master/Docs/ProjectSpec.md)
