# Grand Piano — Audit Verification & Evidence Rules

## Purpose

Use this document **before implementing any changes** to the Grand Piano Flutter application.

The previous audit report contains useful findings, but some findings may be assumptions. Your job is to verify every important finding against the actual source code before accepting it as a task.

## Critical Rule

**Do not modify application code while performing this verification.**

For every finding, inspect the actual relevant files and code paths.

Do not accept a finding merely because:
- it sounds like a Flutter best practice;
- another developer recommended it;
- it is theoretically possible;
- it appears in the previous audit report.

A finding is valid only when the project provides evidence for it.

---

# 1. Verify the Previous Audit

Review the previous audit report and classify each significant finding as:

- **CONFIRMED** — directly supported by the code.
- **PARTIALLY CONFIRMED** — direction is correct, but severity/details are inaccurate.
- **UNCONFIRMED** — insufficient evidence.
- **INCORRECT** — contradicted by the actual code.
- **NOT APPLICABLE** — based on a misunderstanding of the project.

For every finding, provide:

### Finding
What the previous audit claimed.

### Evidence
Exact file path and relevant class/function/code behavior.

### Verification
CONFIRMED / PARTIALLY CONFIRMED / UNCONFIRMED / INCORRECT / NOT APPLICABLE.

### Technical explanation
Why the evidence supports or rejects the finding.

### Correct priority
P0 / P1 / P2 / P3.

### Correct effort
Small / Medium / Large.

### Correct impact
Very High / High / Medium / Low.

---

# 2. Specifically Verify These Claims

Pay special attention to the following claims from the previous audit.

## A. 2000+ line monolithic piano.dart

Verify:
- actual line count;
- responsibilities contained in the file;
- whether the file truly combines UI, state, audio, export, storage, and business logic;
- whether splitting it would materially improve maintainability;
- whether modularization should happen before or after performance fixes.

Do not automatically treat a large file as a problem.

---

## B. Audio Playback Latency

Inspect:
- audio player creation;
- player count;
- asset loading;
- `setAsset`;
- `setUrl`;
- playback calls;
- initialization;
- reuse of players;
- concurrent note playback.

Determine whether latency actually exists based on the implementation.

Do not claim a specific latency such as 50–150 ms unless the code or measurement supports it.

Also determine whether `just_audio` is actually the bottleneck or merely a possible limitation.

---

## C. PNG Encoding / Video Export

Inspect the complete export pipeline.

Determine:

1. How frames are generated.
2. Whether `ui.Image.toByteData()` is used.
3. Whether PNG compression happens on the UI isolate.
4. Whether FFmpeg receives PNG frames, raw frames, or another format.
5. Whether temporary files are created.
6. Whether frames are generated sequentially.
7. Whether the UI is blocked.
8. Whether progress can be calculated accurately.
9. Whether export can fail or be cancelled.
10. Whether the previous report's claim of ANR is justified.

Do not claim that a particular optimization gives "5x" improvement unless measured.

---

## D. 88 AnimationControllers

Verify:
- number of controllers;
- whether all 88 are active;
- whether they tick continuously;
- whether they are disposed;
- whether implicit animations would actually be better;
- whether 88 controllers are truly causing measurable performance problems.

Do not recommend removing them simply because the number is large.

---

## E. Global Keyboard Rebuilds

Inspect:
- `setState`;
- pressed-note state;
- keyboard widget tree;
- individual key widgets;
- whether all 88 keys rebuild;
- whether rebuilds are actually expensive;
- whether multi-touch/glissando produces excessive rebuilds.

Distinguish:

**Widget rebuild**
from
**layout/paint/raster work**
from
**actual dropped frames**.

Do not automatically equate rebuilds with performance problems.

---

## F. Phosphor Icons

Verify the actual dependency and imports.

Check:
- whether `phosphor_flutter` already exists;
- where Material icons remain;
- whether those Material icons are intentionally used;
- whether the approved icon mapping supplied by the user is being followed.

Do not add a dependency if it already exists.

Do not replace icons that were intentionally preserved.

The approved icon decisions in the original audit prompt must remain unchanged.

---

## G. SafeArea / Landscape

Inspect actual layout behavior.

Verify:
- SafeArea usage;
- MediaQuery;
- orientation;
- keyboard dimensions;
- notch/inset behavior;
- header behavior;
- landscape layout.

Do not claim black gutters exist unless the layout actually creates them.

---

## H. Null Safety / Force Unwraps

Find every important `!` operator.

For each one determine:
- whether null is genuinely possible;
- whether the value is guaranteed by program flow;
- whether replacing it would improve safety;
- what failure behavior should be used.

Do not blindly replace every `!`.

Also inspect empty `catch` blocks and determine whether errors are genuinely swallowed.

---

## I. Security / Reliability Claims

Verify every security claim against actual code.

Especially check:
- filename generation;
- simultaneous export behavior;
- temporary file cleanup;
- disk usage;
- API keys/secrets;
- local storage;
- file permissions;
- exception handling.

Do not call something a security vulnerability when it is only a theoretical concern.

---

# 3. Inspect Files Completely

Do not inspect only the files mentioned in the previous report.

Inspect:
- `pubspec.yaml`
- all Dart files
- assets
- Android configuration
- iOS configuration if present
- services
- models
- utility classes
- theme files
- audio files/configuration
- export code
- storage code

Build a dependency/feature map before deciding what should change.

---

# 4. Correct the Previous Audit

At the end produce:

## Confirmed Findings

Only findings supported by code.

## Partially Correct Findings

Explain what was right and what was overstated.

## Incorrect / Unsupported Findings

Explain why they should be removed.

## Missing Findings

Identify important issues the previous audit failed to notice.

## Priority Changes

Show where P0/P1/P2/P3 priorities should change.

## Final Verified Top 10

Provide the final 10 improvements after verification.

---

# 5. Evidence Standard

For important findings, always provide:

`File → Class/Widget → Function → Behavior → Why it matters`

Use exact names from the project.

Avoid generic statements such as:

> "This could cause performance issues."

Instead explain the actual execution path and why it matters.

---

# 6. No Implementation Yet

This document is strictly for verification.

DO NOT:
- edit code;
- create Dart files;
- delete files;
- install packages;
- change dependencies;
- change UI;
- refactor;
- run automated modifications.

Finish with a verified technical audit that can safely be used as the implementation specification.
