# Isolate Concurrency Lag: Findings & Fix Options (Handoff)

Date: 2025-12-17

## Summary of the Symptom

- When generating many waveforms concurrently, fewer concurrent isolates are faster.
  - Example: ~2 isolates → ~1s to 2.5s.
  - Example: ~8 isolates → up to ~8s.
- UI becomes laggy (jank) even when overall CPU usage appears low.

This pattern strongly indicates contention on **global/serialized resources** (dynamic loader / FFmpeg globals / I/O) rather than CPU-bound work.

## Key Findings (Most Likely Causes)

### 1) FFmpeg init/cleanup thrash (process-global state, called per job)

**What happens**

- Each waveform job (each spawned isolate) calls:
  - `NativeAudioBindings.initialize()`
  - does decode+waveform
  - then calls `NativeAudioBindings.cleanup()`

This is inside the isolate worker entry point.

**Evidence (code locations)**

- Isolate worker always calls init and cleanup per job:
  - lib/src/isolate/isolate_runner.dart
    - init: `NativeAudioBindings.initialize()`
    - cleanup: `NativeAudioBindings.cleanup()`

- Native FFmpeg init/cleanup uses process-wide globals:
  - native/src/sonix_ffmpeg.c
    - `static int g_ffmpeg_initialized = 0;`
    - `sonix_init_ffmpeg()` sets it
    - `sonix_cleanup_ffmpeg()` calls `avformat_network_deinit()` and resets it

**Why this kills throughput (and can cause jank)**

- FFmpeg initialization is effectively **global**, and cleanup deinitializes global state.
- With many isolates in parallel, you end up with **init/deinit contention and races**:
  - Multiple isolates may call init while others are deiniting.
  - The dynamic loader and FFmpeg internals often use global locks.
  - Threads wait (CPU appears low), wall time increases dramatically.

**This is a prime explanation for “8 isolates slower than 2 isolates”.**

### 2) Disk / filesystem contention (especially for “read whole file” path)

**What happens**

- For smaller files, decoding uses `SimpleAudioFileDecoder`, which does:
  - `await file.readAsBytes()` (read entire file into memory)

**Evidence (code locations)**

- lib/src/decoders/audio_file_decoder.dart
  - `SimpleAudioFileDecoder.decode()` reads entire file in one go

**Why it kills throughput**

- 8 parallel reads can saturate or thrash disk I/O (HDD seek thrash, limited queue depth, network FS latency).
- Result: isolates block on I/O, CPU stays low, total wall time increases.

### 3) UI jank from bursty isolate spawning + frequent UI rebuilds

Even when computation is off-main-thread:

- `Isolate.spawn` and port setup still costs work on the main isolate.
- Spawning many isolates in a short burst can steal time from frame rendering.
- If the UI updates state very frequently per-task (start/finish events), it can add additional frame pressure.

## What to Change (Fix Options)

### Option A (Recommended): Stop calling `NativeAudioBindings.cleanup()` per job

**Idea**

- Initialize FFmpeg once per process, and keep it initialized for the lifetime of the app.
- Only call cleanup on app shutdown (or never, letting OS reclaim resources).

**Why it helps**

- Eliminates global init/deinit thrash.
- Avoids races and global locks around FFmpeg init/deinit.

**Implementation sketch**

- In lib/src/isolate/isolate_runner.dart isolate worker:
  - Keep `NativeAudioBindings.initialize()` (or use a “check/init if needed”).
  - Remove per-job `NativeAudioBindings.cleanup()`.

Potential follow-up:
- Add an explicit top-level shutdown hook (e.g., `Sonix.dispose()` or `Sonix.shutdownNative()`), if needed.

### Option B: Add native-side reference counting + a mutex around FFmpeg init/cleanup

**Idea**

- Make `sonix_init_ffmpeg()` and `sonix_cleanup_ffmpeg()` thread-safe.
- Track how many decoders/jobs are active.
- Only call `avformat_network_deinit()` when the refcount goes to zero.

**Why it helps**

- Prevents races and reduces redundant init/deinit cycles.

**Tradeoffs**

- More complex native logic.
- Must be correct across platforms.

### Option C: Concurrency control (queue) is still needed, but it’s not the root fix

**Idea**

- Limit concurrent jobs to a small number (2–4) to preserve UI responsiveness.

**Why it helps**

- Reduces isolate spawn bursts.
- Reduces I/O contention.

**But**

- If FFmpeg cleanup thrash exists, even a moderate concurrency can still be worse than expected.

### Option D: Reduce I/O amplification

If the bottleneck is file I/O:

- Prefer streaming decode paths earlier (lower chunk threshold) so jobs don’t all `readAsBytes()` simultaneously.
- Ensure test/demo files are on SSD (or locally cached) when benchmarking.

## Experiments to Validate Root Cause (Fast Checks)

1) A/B test: comment out per-job `NativeAudioBindings.cleanup()` in isolate worker.
   - If 8 isolates becomes much faster and UI less laggy → confirmed FFmpeg global thrash.

2) I/O test:
   - Run the same benchmark with files on SSD vs HDD/network drive.
   - If SSD massively improves scaling → I/O contention is dominant.

3) Spawn burst test:
   - Add a small stagger (e.g., 20–50ms) between spawns.
   - If jank reduces but throughput doesn’t → spawn/rebuild pressure is dominant but not the only cause.

## Notes for Next Agent Session

- The “single isolate per request” simplification is fine, but FFmpeg lifecycle must not be per-request.
- The highest-value fix is making FFmpeg init happen once, and making cleanup either:
  - only on app shutdown, or
  - ref-counted + thread-safe.

If you want a minimal PR:
- Remove per-job cleanup in the isolate worker, and leave global cleanup to app lifecycle (or omit it).
