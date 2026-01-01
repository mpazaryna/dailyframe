# SwiftUI Navigation Architecture & AttributeGraph Management

**Project:** PAB (Practice Scribe)
**Date:** October 4, 2025
**Critical Importance:** CORE KNOWLEDGE - Read before refactoring views

---

## Executive Summary

This document captures a critical architectural discovery about SwiftUI's NavigationSplitView, the AttributeGraph reactive system, and config-driven patterns. After hours of debugging UI freezes and crashes during SOAP note generation, we identified that **shared config patterns across multiple views in a NavigationSplitView hierarchy create cascading AttributeGraph updates that cause freezes and crashes**.

**Key Finding:** Configuration-driven patterns are safe and recommended, but **must be scoped locally** when used in NavigationSplitView hierarchies with high-frequency state updates.

---

## Table of Contents

1. [The Problem](#the-problem)
2. [Timeline of Investigation](#timeline-of-investigation)
3. [Root Cause Analysis](#root-cause-analysis)
4. [The Solution](#the-solution)
5. [Technical Deep Dive](#technical-deep-dive)
6. [Development Best Practices](#development-best-practices)
7. [Case Study: SOAP Generation Success](#case-study-soap-generation-success)
8. [Warning Signs to Watch For](#warning-signs-to-watch-for)

---

## The Problem

### Symptoms

After refactoring multiple views to use a shared configuration pattern for platform-adaptive layouts, the application exhibited critical issues:

1. **UI Freeze After SOAP Generation**
   - Navigation sidebar became completely unresponsive
   - Could not click on any navigation items
   - UI appeared frozen but Activity Monitor showed 0.3% CPU (indicating deadlock, not infinite loop)
   - Closing and reopening sidebar temporarily restored functionality

2. **Application Crashes**
   - AttributeGraph cycle errors logged to console
   - Crashes occurred immediately after SOAP note generation completed
   - Error: `AttributeGraph: cycle detected through attribute [ID]`

3. **AutoLayout Constraint Conflicts**
   - NSSplitView (backing NavigationSplitView) reported unsatisfiable constraints
   - Navigation structure became unstable

### Context

The issues appeared after:
- Refactoring 6+ views to use shared `*LayoutConfig` pattern
- All views existed within the same NavigationSplitView hierarchy
- SOAP generation view updates 5 `@State` variables simultaneously on completion

The most critical aspect: **SOAP generation had been working flawlessly for days before the refactor**, with no code changes to MLX processors or generation logic.

---

## Timeline of Investigation

### Initial Hypothesis: MainActor Threading Issue
**Attempted Fix:** Added `@MainActor` annotations and `await MainActor.run { }` blocks
**Result:** Created deadlock - button Task already ran on MainActor, so awaiting MainActor.run from within caused circular wait
**Evidence:** CPU dropped to 0.3% during freeze (classic deadlock symptom)

### Second Hypothesis: State Update Batching
**Attempted Fix:** Wrapped state updates in `withAnimation` blocks to batch transactions
**Result:** Caused AttributeGraph cycles - animation blocks created circular dependencies in view graph
**Evidence:** Console flooded with `AttributeGraph: cycle detected` errors

### Third Hypothesis: NavigationSplitView Architecture
**Attempted Fix:** Replaced NavigationSplitView with custom HStack sidebar, then TabView
**Result:** Different navigation issues, not a complete fix
**Evidence:** Continued instability, constraint conflicts persisted

### Fourth Hypothesis: Config Pattern Coupling (BREAKTHROUGH)
**Attempted Fix:** Created local config pattern scoped to SOAPGenerationResultsView only, inlined all child views
**Result:** Complete stability - SOAP generation works perfectly on macOS and iPad
**Evidence:** No freezes, no crashes, no AttributeGraph cycles

---

## Root Cause Analysis

### The Shared Config Pattern

Before the fix, views used this pattern:

```swift
// In multiple views throughout the NavigationSplitView hierarchy
struct SomeView: View {
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var config: SomeLayoutConfig {
        SomeLayoutConfig.current(sizeClass)  // ⚠️ Computed property
    }
    #else
    private var config: SomeLayoutConfig {
        SomeLayoutConfig.current
    }
    #endif

    var body: some View {
        VStack(spacing: config.spacing) {  // ⚠️ Creates reactive dependency
            // ...
        }
        .padding(config.padding)
        .background(config.backgroundColor)
    }
}
```

### Why This Caused Issues

#### 1. AttributeGraph Reactive Dependencies

SwiftUI's AttributeGraph tracks all dependencies between views and state:

- Each view with a `config` computed property creates graph nodes
- Each `@Environment(\.horizontalSizeClass)` dependency creates edges
- 6+ views × multiple config accesses = complex dependency graph
- When SOAP generation updates 5 `@State` variables simultaneously, SwiftUI must:
  1. Invalidate all dependent graph nodes
  2. Re-evaluate all computed properties
  3. Propagate changes through entire hierarchy
  4. Update all affected views

#### 2. NavigationSplitView Shared Hierarchy

NavigationSplitView is architecturally different from TabView or NavigationStack:

```
NavigationSplitView
├── Sidebar (List of navigation items)
│   └── Multiple views with shared config pattern
└── Detail (Content view)
    └── SOAPGenerationResultsView (updates 5 states)
```

**Critical Issue:** Sidebar and detail views share the same parent hierarchy. State updates in detail propagate to sidebar for re-evaluation, even though sidebar doesn't display the changed data.

#### 3. The Cascade Effect

When SOAP generation completes:

1. **5 state variables update simultaneously:**
   - `isGenerating = false`
   - `soapResult = ChiroTestResult(...)`
   - `icd10Suggestions = [...]`
   - `vertebralAnalysis = VertebralAnalysisResult(...)`
   - `cptAnalysis = CPTAnalysisResult(...)`

2. **SwiftUI propagates through AttributeGraph:**
   - All dependent graph nodes invalidated
   - All views in hierarchy marked for re-evaluation

3. **Each config-dependent view re-evaluates:**
   - Computes `config` property
   - Reads `@Environment(\.horizontalSizeClass)`
   - Creates new graph nodes
   - Triggers further propagation

4. **Graph becomes overloaded:**
   - Too many simultaneous updates
   - Circular dependencies detected
   - NSSplitView constraints conflicted
   - Result: Freeze or crash

### Evidence

1. **Activity Monitor: 0.3% CPU during freeze**
   - Not an infinite loop (would be 100% CPU)
   - Deadlock from circular wait in AttributeGraph

2. **Console AttributeGraph errors:**
   ```
   AttributeGraph: cycle detected through attribute 137832
   ```

3. **NSSplitView constraint conflicts:**
   ```
   Unable to simultaneously satisfy constraints:
   NSLayoutConstraint: ... NSSplitViewItemViewWrapper ...
   ```

4. **Timing:** Issues only appeared after config pattern refactor, not before

---

## The Solution

### Local Config Pattern

Instead of shared configs across many views, scope the config pattern to individual files:

```swift
// INSIDE SOAPGenerationResultsView.swift

// MARK: - Layout Configuration
struct SOAPLayoutConfig {
    let headerPadding: CGFloat
    let contentSpacing: CGFloat
    let cardSpacing: CGFloat
    let cornerRadius: CGFloat
    let headerBackground: Color
    let useNavigationBarTitle: Bool

    #if os(macOS)
    static let current = SOAPLayoutConfig(
        headerPadding: 16,
        contentSpacing: 16,
        cardSpacing: 16,
        cornerRadius: 8,
        headerBackground: Color.platformSecondaryBackground,
        useNavigationBarTitle: false
    )
    #else
    static func current(_ sizeClass: UserInterfaceSizeClass?) -> SOAPLayoutConfig {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return SOAPLayoutConfig(
                headerPadding: 16,
                contentSpacing: 16,
                cardSpacing: 16,
                cornerRadius: 8,
                headerBackground: Color(uiColor: .secondarySystemGroupedBackground),
                useNavigationBarTitle: true
            )
        }
        // iPhone config...
    }
    #endif
}

struct SOAPGenerationResultsView: View {
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var config: SOAPLayoutConfig {
        SOAPLayoutConfig.current(sizeClass)
    }
    #else
    private var config: SOAPLayoutConfig {
        SOAPLayoutConfig.current
    }
    #endif

    // View implementation...
}

// MARK: - Inline Child Views
// All child views (ICD10SuggestionsView, CPTAnalysisView, etc.)
// inlined in the same file
```

### Why This Works

✅ **Config overhead isolated to one view**
- Only SOAPGenerationResultsView has reactive config dependencies
- Other views in NavigationSplitView hierarchy remain simple

✅ **No cross-view AttributeGraph cascade**
- State updates in SOAP view don't trigger config re-evaluation in other views
- Sidebar views have no reactive config dependencies

✅ **Self-contained and predictable**
- All code in one file (1015 lines)
- Easy to understand, modify, and debug
- No hidden dependencies on shared infrastructure

✅ **Proven stable**
- Tested successfully on macOS
- Tested successfully on iPad
- No freezes, no crashes, no AttributeGraph cycles

---

## Technical Deep Dive

### SwiftUI AttributeGraph

The AttributeGraph is SwiftUI's internal reactive dependency tracking system:

```
View Hierarchy          AttributeGraph
┌─────────────┐        ┌──────────────┐
│ ParentView  │───────▶│ Node: Parent │
│   @State    │        │ Deps: []     │
└─────────────┘        └──────────────┘
       │                       │
       │                       │ edge
       ▼                       ▼
┌─────────────┐        ┌──────────────┐
│ ChildView   │───────▶│ Node: Child  │
│   config    │        │ Deps: [State]│
└─────────────┘        └──────────────┘
```

**When state changes:**
1. Graph invalidates dependent nodes
2. SwiftUI schedules re-render
3. Computes new values for computed properties
4. Updates view body
5. Propagates to children

**With many config-dependent views:**
- Graph becomes dense (many nodes, many edges)
- State changes trigger broad invalidation
- Multiple simultaneous changes overwhelm the system
- Circular dependencies can form

### NavigationSplitView Architecture

Unlike TabView (which only renders active tab), NavigationSplitView keeps both sidebar and detail in memory:

```
┌──────────────────────────────────────┐
│ NavigationSplitView                  │
│  ┌────────────┐  ┌────────────────┐ │
│  │  Sidebar   │  │     Detail     │ │
│  │  (List)    │  │ (NavStack)     │ │
│  │            │  │                │ │
│  │  Always    │  │  Changes based │ │
│  │  rendered  │  │  on selection  │ │
│  └────────────┘  └────────────────┘ │
└──────────────────────────────────────┘
         │                    │
         └────────┬───────────┘
                  │
        Shared parent hierarchy
   (state updates propagate to both)
```

**Why this matters:**
- State updates in detail view propagate to sidebar
- If sidebar has reactive dependencies (like computed configs), it re-evaluates
- Creates unnecessary work and potential conflicts

### MainActor Isolation

SwiftUI views are MainActor-isolated by default:

```swift
struct MyView: View {  // Implicitly @MainActor
    var body: some View {  // Already on MainActor
        Text("Hello")
    }

    func someMethod() {  // Already on MainActor
        // This code runs on MainActor
    }
}
```

**Common mistake:**
```swift
Button("Generate") {
    Task {  // ✅ This Task runs on MainActor (inherits from button context)
        await MainActor.run {  // ❌ DEADLOCK: Already on MainActor!
            self.state = newValue
        }
    }
}
```

**Correct approach:**
```swift
Button("Generate") {
    Task {  // Runs on MainActor
        let result = await someAsyncWork()  // Suspends, may run elsewhere
        self.state = result  // ✅ Back on MainActor, direct assignment
    }
}
```

---

## Development Best Practices

### 1. Config Pattern Guidelines

#### ✅ DO: Use Local Config Patterns

**When to use local config:**
- View is mission-critical (e.g., SOAP generation)
- View has high-frequency state updates (5+ `@State` variables)
- View exists in NavigationSplitView hierarchy
- View has complex child components

**Benefits:**
- Isolated scope prevents cross-view issues
- Easy to debug and understand
- Self-documenting (all code in one file)
- Safe to evolve independently

**Example structure:**
```swift
// MyComplexView.swift

// MARK: - Layout Configuration
struct MyViewLayoutConfig {
    // Config properties...

    #if os(macOS)
    static let current = MyViewLayoutConfig(...)
    #else
    static func current(_ sizeClass: UserInterfaceSizeClass?) -> MyViewLayoutConfig {
        // Platform-specific configs...
    }
    #endif
}

// MARK: - Main View
struct MyComplexView: View {
    // Config usage...
}

// MARK: - Child Components
// Inline all child views here
struct MyChildView1: View { }
struct MyChildView2: View { }
```

#### ⚠️ CAUTION: Shared Config Patterns

**Only use shared configs when:**
- Views are simple (1-2 `@State` variables)
- Low-frequency updates
- Not in NavigationSplitView hierarchy
- Benefits of code reuse outweigh risks

**If using shared configs:**
- Monitor for AttributeGraph errors in console
- Test thoroughly with realistic state updates
- Watch Activity Monitor for CPU spikes/drops
- Consider `.id()` modifiers to force view recreation

### 2. NavigationSplitView Best Practices

#### Isolate Detail View State

```swift
NavigationSplitView {
    // Sidebar
    List(selection: $selectedTab) {
        // Navigation items...
    }
} detail: {
    NavigationStack {
        destinationView(for: selectedTab)
    }
    .id(selectedTab)  // ✅ Force recreation on tab change
}
```

**Why `.id(selectedTab)` matters:**
- Forces complete view recreation when selection changes
- Breaks dependency chains between tabs
- Prevents stale state accumulation

#### Minimize Shared State

```swift
// ❌ BAD: Shared state between sidebar and detail
struct ContentView: View {
    @State private var sharedManager = SomeManager()  // Both use this

    var body: some View {
        NavigationSplitView {
            SidebarView(manager: sharedManager)
        } detail: {
            DetailView(manager: sharedManager)  // Updates propagate to sidebar
        }
    }
}

// ✅ GOOD: Isolated state
struct ContentView: View {
    @State private var selectedTab = Tab.dashboard
    @State private var managers = ManagerContainer()

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) { /* ... */ }
        } detail: {
            destinationView(for: selectedTab)  // Gets specific manager
                .id(selectedTab)
        }
    }
}
```

### 3. State Update Patterns

#### Batch Related Updates Together

```swift
// ✅ GOOD: Single transaction
func updateResults(_ results: Results) {
    self.isLoading = false
    self.data = results.data
    self.metadata = results.metadata
    self.error = nil
    // All updates in one pass
}

// ❌ BAD: Multiple async transactions
func updateResults(_ results: Results) async {
    await MainActor.run { self.isLoading = false }
    await MainActor.run { self.data = results.data }
    await MainActor.run { self.metadata = results.metadata }
    // Each triggers separate view update
}
```

#### Avoid withAnimation for State Updates

```swift
// ❌ BAD: Creates AttributeGraph complications
withAnimation {
    self.result = newResult
    self.suggestions = newSuggestions
    self.analysis = newAnalysis
}

// ✅ GOOD: Direct updates, let SwiftUI handle animation
self.result = newResult
self.suggestions = newSuggestions
self.analysis = newAnalysis
```

### 4. Debugging Techniques

#### Monitor AttributeGraph Cycles

Enable in scheme or via environment:
```bash
# In Xcode scheme environment variables
NSConstraintBasedLayoutVisualizeMutuallyExclusiveConstraints = YES
```

Watch console for:
```
AttributeGraph: cycle detected through attribute [ID]
```

#### Activity Monitor for Deadlock Detection

- **Freeze with 0-5% CPU**: Likely deadlock (circular wait)
- **Freeze with 100% CPU**: Likely infinite loop
- **Freeze with 30-50% CPU**: Heavy computation or AttributeGraph overhead

#### Symbolic Breakpoint

Set breakpoint on:
```
LAYOUT_CONSTRAINTS_NOT_SATISFIABLE
```

This catches AutoLayout/constraint issues immediately.

#### Bisect Refactors

When introducing config patterns:
1. Refactor ONE view at a time
2. Test thoroughly after each view
3. Monitor console and Activity Monitor
4. If issues appear, isolate that view's config locally

---

## Case Study: SOAP Generation Success

### The Mission-Critical Feature

SOAP note generation is the core value proposition:
- Analyzes chiropractic exam dictation
- Runs 3 MLX neural network processors in parallel (ICD-10, CPT, Vertebral)
- Calls Foundation Models API
- Updates 5 state variables simultaneously
- Displays complex analysis results
- Must work on macOS AND iPad (market requirement)

### Before Refactor

- 3 separate Component files:
  - `CPTAnalysisView.swift`
  - `ICD10SuggestionsView.swift`
  - `VertebralAnalysisView.swift`
- Hardcoded platform checks with `#if os(macOS)` / `#if os(iOS)`
- **Working perfectly for days of production use**

### During Shared Config Refactor

- Applied shared config pattern to 6+ views including SOAP
- Result: Complete UI freeze after generation
- Critical feature became unusable

### Local Config Solution

**Created:** `soap-local-config` branch

**Changes:**
1. Created `SOAPLayoutConfig` struct inside SOAPGenerationResultsView.swift
2. Inlined all 3 analysis views (1015 total lines in one file)
3. Deleted separate Component files
4. Refactored platform checks to use local config
5. Added toolbar button to iPad view

**Result:**
- ✅ macOS: Generates notes perfectly, no freezes
- ✅ iPad: Generates notes perfectly, correct layout
- ✅ No AttributeGraph cycles
- ✅ No crashes
- ✅ No NSSplitView constraint conflicts

### Key Insight

**The config pattern works beautifully when scoped locally.** The problem wasn't the pattern itself, but architectural coupling through shared configs in a NavigationSplitView hierarchy with high-frequency state updates.

### File Structure

```
SOAPGenerationResultsView.swift (1015 lines)
├── SOAPLayoutConfig struct (lines 11-52)
│   ├── macOS static config
│   └── iOS function returning iPad/iPhone configs
├── SOAPGenerationResultsView (lines 54-468)
│   ├── Config computed property
│   ├── macOS/iPad/iPhone platform views
│   └── SOAP generation logic
└── Inline Analysis Views (lines 470-1014)
    ├── ICD10SuggestionsView
    ├── ICD10EnhancedSuggestionRow
    ├── VertebralAnalysisView
    ├── CPTAnalysisView
    └── CPTSuggestionRow
```

**Philosophy:** Self-contained, mission-critical code stays independent of shared infrastructure until that infrastructure is proven stable across the entire app.

---

## Warning Signs to Watch For

### During Development

⚠️ **Console Warnings:**
```
AttributeGraph: cycle detected through attribute [ID]
AttributeGraph: cycle detected through attribute [ID]  // Repeated
```
**Action:** Immediately check for shared config patterns or computed properties creating circular dependencies.

⚠️ **Constraint Conflicts:**
```
Unable to simultaneously satisfy constraints:
  NSLayoutConstraint: ... NSSplitViewItemViewWrapper ...
```
**Action:** NavigationSplitView state isolation issue. Add `.id()` modifier or isolate configs.

⚠️ **Build Warnings:**
```
main actor-isolated property 'X' cannot be mutated from a nonisolated context
```
**Action:** Threading issue, but less critical. Review MainActor isolation patterns.

### During Testing

⚠️ **UI Freeze After Async Operation:**
- Check Activity Monitor CPU usage
- If 0-5% CPU: Deadlock, likely MainActor.run in MainActor context
- If 100% CPU: Infinite loop, check state update logic
- If 30-50% CPU: AttributeGraph overhead, likely shared config issue

⚠️ **Sidebar Becomes Unresponsive:**
- Classic NavigationSplitView state propagation issue
- Detail view state updates affecting sidebar
- Solution: Add `.id()` to detail, isolate configs

⚠️ **Crashes Only After Complex Operations:**
- Check for AttributeGraph cycles in console
- Likely many simultaneous state updates overwhelming graph
- Solution: Isolate view configs locally

### In Production

⚠️ **Regression After Refactor:**
- If feature worked before refactor, refactor introduced the issue
- Don't blame the original code
- Isolate the refactored view's config pattern

⚠️ **Platform-Specific Issues:**
- If macOS works but iPad doesn't: Config function logic issue
- If both freeze: Architectural issue, likely shared config
- If neither work: Check generation logic, not configs

---

## Conclusions

### Core Principles

1. **Config patterns are valuable** - they centralize platform adaptation logic and reduce duplication
2. **Scope matters more than technique** - local configs are safer than shared configs in complex hierarchies
3. **NavigationSplitView has unique architecture** - sidebar and detail share hierarchy, state propagates
4. **AttributeGraph has limits** - too many reactive dependencies overwhelm the system
5. **Mission-critical code deserves isolation** - don't couple your most important features to shared infrastructure until proven

### Development Workflow

When refactoring to config patterns:

1. **Start with low-risk views** (simple, few states, not in NavigationSplitView)
2. **Refactor one view at a time** (test after each)
3. **Monitor console and Activity Monitor** (catch issues early)
4. **For mission-critical features**: Use local config pattern first, extract later if beneficial
5. **When issues appear**: Isolate, don't fight the architecture

### Success Criteria

A refactor is successful when:
- ✅ No AttributeGraph cycle errors in console
- ✅ No constraint conflict warnings
- ✅ Activity Monitor shows normal CPU usage during operations
- ✅ UI remains responsive after async operations
- ✅ Navigation works smoothly across all tabs/views
- ✅ Works on all target platforms (macOS, iPad, iPhone)

### Future Direction

**Short term:**
- Keep SOAP generation with local config pattern
- Monitor other refactored views for stability
- Document any additional issues in this file

**Long term:**
- Once app is stable, consider extracting common patterns from local configs
- Create shared configs only for proven-stable, low-complexity views
- Maintain local configs for high-frequency state update views

### Final Thought

**"Premature optimization is the root of all evil, but so is premature abstraction."** - Adapted from Donald Knuth

The shared config pattern was a premature abstraction for this architecture. The local config pattern proved that the technique works - we just needed the right scope.

---

**Document History:**
- 2025-10-04: Initial document created after SOAP generation refactor success
- Location: `/Users/mpaz/workspace/pab-native/pab/SWIFTUI_NAVIGATION_ARCHITECTURE.md`
- Branch: `soap-local-config`
- Author: Development team with Claude Code

**Next Update:** When merging to `main` or encountering new NavigationSplitView issues.
