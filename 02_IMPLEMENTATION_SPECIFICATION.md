# Grand Piano — Implementation Specification

## Purpose

This document is the implementation phase that comes **after the audit has been verified**.

The goal is not to blindly implement every recommendation from the previous audit.

Only implement changes that are confirmed by the verified audit and provide meaningful benefit.

---

# 1. Implementation Rules

Before changing anything:

1. Read the verified audit.
2. Inspect the current source code again.
3. Identify exact files that will change.
4. Understand dependencies between changes.
5. Preserve existing working behavior.
6. Do not redesign the product unnecessarily.
7. Do not introduce architecture complexity without a concrete benefit.
8. Do not change approved visual decisions.
9. Do not modify game mechanics unless explicitly requested.
10. Keep the app buildable after each logical batch of changes.

---

# 2. Priority Order

Implement in this order:

## Phase 1 — P0

Only:
- crashes;
- data corruption/loss;
- severe UI freezes;
- broken core functionality;
- severe audio/playback problems;
- severe export failures.

Do not start architectural cleanup before critical functionality is stable.

---

## Phase 2 — P1

Implement:
- major UX problems;
- meaningful performance problems;
- important reliability issues;
- important accessibility problems;
- clearly visible visual inconsistencies.

---

## Phase 3 — P2

Implement:
- maintainability improvements;
- moderate performance improvements;
- cleanup;
- design consistency;
- technical debt with measurable benefit.

---

## Phase 4 — P3

Only implement:
- polish;
- minor cleanup;
- nice-to-have improvements.

Do not spend significant development time on P3 items while P0/P1 work remains unfinished.

---

# 3. Required Implementation Format

For every implementation task, document:

## Task

Short name.

## Problem

What is currently wrong.

## Evidence

Exact file/class/function responsible.

## Change

What will be modified.

## Files

List every file that will change.

## Behavior Before

What the application currently does.

## Behavior After

What the application should do.

## Risk

Low / Medium / High.

## Validation

Exactly how the change will be tested.

---

# 4. Audio Performance

If the verified audit confirms playback latency:

Inspect the current audio architecture before changing it.

Do not automatically replace `just_audio`.

Determine whether the best solution is:

- preloading assets;
- reusing players;
- player pooling;
- audio source caching;
- a different audio API;
- another low-latency approach.

The implementation must preserve:

- polyphonic playback;
- rapid repeated notes;
- multi-touch;
- glissando;
- recording synchronization;
- mute/unmute behavior.

Test:
- single key;
- rapid repeated key;
- multiple simultaneous keys;
- fast glissando;
- long playing sessions.

---

# 5. Video Export Performance

If the verified audit confirms UI blocking:

Understand the complete pipeline before modifying it.

Potential approaches include:

- background isolate processing;
- raw pixel frame processing;
- asynchronous frame encoding;
- temporary-file optimization;
- FFmpeg streaming;
- reducing unnecessary conversions.

Do not change the pipeline merely because raw frames sound faster.

Verify compatibility with the existing FFmpeg implementation.

Preserve:
- video resolution choices;
- frame rate;
- audio synchronization;
- piano appearance;
- output format;
- sharing behavior.

Test:
- short recording;
- long recording;
- 360p;
- 720p;
- 1080p;
- audio export;
- cancelled export;
- failed export;
- repeated exports.

---

# 6. Keyboard Rebuild Optimization

If confirmed:

Do not optimize purely by removing `setState`.

First determine which widgets actually rebuild.

Use the simplest suitable approach.

Possible approaches:
- `ValueNotifier`;
- localized state;
- `AnimatedBuilder`;
- `ListenableBuilder`;
- individual key widgets;
- another existing state mechanism.

Preserve:
- pressed state;
- animations;
- touch hit testing;
- multi-touch;
- horizontal scrolling;
- black/white key positioning.

Validation must include:
- single key press;
- rapid taps;
- glissando;
- multi-touch;
- scrolling.

---

# 7. Animation Controllers

Only change the 88-controller design if profiling/evidence shows a meaningful problem.

If controllers are retained:
- ensure correct disposal;
- avoid unnecessary ticking;
- avoid leaks.

If replaced:
- preserve visual behavior exactly;
- verify animation timing;
- verify simultaneous key animations.

Do not optimize merely because "88" looks large.

---

# 8. Architecture Modularization

Only modularize after P0/P1 performance and reliability issues are addressed unless the verified audit proves modularization is required first.

Preferred practical separation:

- Piano screen/widget
- Keyboard/key widgets
- Audio service
- Recording state
- Export service
- File/storage service
- Reusable UI components
- Theme/design tokens

Do not introduce unnecessary:
- repositories;
- use cases;
- dependency injection frameworks;
- state-management packages;
- abstractions.

The architecture should become simpler, not more complicated.

---

# 9. Icon System

The application is standardizing on PhosphorIcons.

Preserve the approved mappings from the original specification.

Do not invent new icon meanings.

Verify every icon replacement visually.

Check:
- weight;
- size;
- alignment;
- optical balance;
- semantic meaning;
- consistency.

Do not replace intentionally different icons without evidence.

---

# 10. Safe Area / Responsive Layout

If confirmed by testing:

Preserve the premium full-screen piano experience.

Do not simply remove SafeArea globally.

Instead separate:
- full-bleed keyboard/background areas;
- interactive controls that require safe insets.

Test:
- small phones;
- normal phones;
- large phones;
- notched devices;
- portrait;
- landscape;
- different aspect ratios.

---

# 11. Export Progress

If export progress can be measured reliably:

Provide:
- percentage or meaningful progress;
- current stage;
- clear exporting state;
- success state;
- failure state;
- cancellation behavior if supported.

Never display fake progress.

If exact progress is unavailable, use honest staged progress instead.

---

# 12. Error Handling

Replace swallowed errors only when meaningful handling is possible.

Every user-facing failure should provide:
- what failed;
- that the original recording/data is safe where applicable;
- what the user can do next.

Do not expose technical stack traces to normal users.

Keep useful diagnostic logging available during development.

---

# 13. Theme / Design Tokens

Only centralize repeated values when doing so actually improves consistency.

Preserve the existing:
- wood aesthetic;
- gold palette;
- ivory/ebony keys;
- typography;
- premium visual identity;
- successful splash animation.

Do not redesign the application just to introduce a design system.

---

# 14. Accessibility

Improve accessibility without damaging the product personality.

Priorities:
- meaningful semantic labels;
- accessible controls;
- adequate touch targets;
- readable contrast;
- support for text scaling where practical;
- clear state communication.

For piano keys, determine an appropriate semantic interaction model rather than adding meaningless labels to every visual element.

---

# 15. Validation After Every Batch

After each meaningful implementation batch:

1. Run formatter.
2. Run static analysis.
3. Run tests if available.
4. Build the application.
5. Test the affected flow manually.
6. Check for regressions.
7. Review changed files.
8. Confirm no unrelated behavior changed.

Do not move to the next major phase if the current phase introduces regressions.

---

# 16. Performance Validation

Do not claim performance improvements without evidence where measurable.

Before/after measurements should include when relevant:

- frame performance;
- rebuild frequency;
- audio startup latency;
- export duration;
- memory usage;
- CPU usage;
- output file size;
- startup time.

Use profiling where practical.

Avoid claims such as "5x faster" unless actually measured.

---

# 17. Preserve These Existing Strengths

Do NOT unnecessarily change:

- premium wood-and-gold visual identity;
- splash animation concept;
- custom visual effects;
- piano key appearance;
- responsive keyboard calculations;
- core recording behavior;
- export formats;
- existing successful interactions.

The objective is:

**better engineering + better performance + better reliability + same product identity.**

---

# 18. Final Implementation Report

After implementation, produce:

## Changes Made

List every completed change.

## Files Changed

List files and purpose.

## Performance Improvements

Only include measured or technically verified improvements.

## UX Improvements

List user-visible improvements.

## Architecture Improvements

Explain the new structure.

## Bugs Fixed

List confirmed bugs.

## Remaining Technical Debt

List what intentionally remains.

## Risks

List known risks.

## Testing Performed

List:
- static analysis;
- builds;
- tests;
- manual flows;
- device/orientation testing;
- export testing;
- audio testing.

## Final Verdict

Answer:

1. Is the app production-ready?
2. What remains before release?
3. What can safely be postponed?
4. What should never be changed without a product reason?

---

# FINAL RULE

Do not optimize for "clean code" at the expense of the actual product.

Do not optimize for architectural fashion.

Do not make large changes without evidence.

Do not remove working behavior merely because another implementation is theoretically better.

**Every change must have a reason, evidence, measurable benefit where possible, and a validation method.**
