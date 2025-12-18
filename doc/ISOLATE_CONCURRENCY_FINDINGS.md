# Isolate Concurrency Lag: Findings & Fix Options (Handoff)

Date: 2025-12-17

## Important Context

**Sonix is a package/library**, not an application. This means:

- We have no control over the consuming app's lifecycle.
- We cannot rely on "app shutdown" hooks to clean up.
- Cleanup must either be:
  - Explicitly called by the consumer via a public API, or
  - Handled automatically/safely at the native level (e.g., refcount), or
  - Simply omitted (let the OS reclaim on process exit).
- The API must be safe for consumers who create/dispose many `Sonix` instances.

---

## Summary of the Symptom

- When generating many waveforms concurrently, fewer concurrent isolates are faster.
  - Example: ~2 isolates → ~1s to 2.5s per file.
  - Example: ~8 isolates → up to ~8s per file.
- UI becomes laggy (jank) even when overall CPU usage appears low.

This pattern strongly indicates contention on **global/serialized resources** (dynamic loader / FFmpeg globals / I/O) rather than CPU-bound work.

---

## Key Findings (Most Likely Causes)

### 1) FFmpeg init/cleanup thrash (process-global state, called per job)

**What happens**

Each waveform job (each spawned isolate) calls:
1. `NativeAudioBindings.initialize()`
2. Decode audio + generate waveform
3. `NativeAudioBindings.cleanup()`

This happens inside the isolate worker entry point.

**Evidence (code locations)**

- Isolate worker always calls init and cleanup per job:
  - `lib/src/isolate/isolate_runner.dart`
    - init: `NativeAudioBindings.initialize()`
    - cleanup: `NativeAudioBindings.cleanup()` (in both success and error paths)

- Native FFmpeg init/cleanup uses process-wide globals:
  - `native/src/sonix_ffmpeg.c`
    - `static int g_ffmpeg_initialized = 0;`
    - `sonix_init_ffmpeg()` sets this flag
    - `sonix_cleanup_ffmpeg()` calls `avformat_network_deinit()` and resets the flag

**Why this kills throughput (and can cause jank)**

- FFmpeg initialization is effectively **global** to the process.
- Cleanup deinitializes that global state.
- With many isolates in parallel, you get **init/deinit contention and races**:
  - Multiple isolates may call init while others are calling deinit.
  - The dynamic loader and FFmpeg internals use global locks.
  - Threads wait on locks → CPU appears low, wall time increases dramatically.

**This is the prime explanation for "8 isolates slower than 2 isolates".**

### 2) Disk / filesystem contention (especially for "read whole file" path)

**What happens**

For smaller files, decoding uses `SimpleAudioFileDecoder`, which does:
- `await file.readAsBytes()` (reads entire file into memory)

**Evidence (code locations)**

- `lib/src/decoders/audio_file_decoder.dart`
  - `SimpleAudioFileDecoder.decode()` reads entire file in one shot

**Why it kills throughput**

- 8 parallel full-file reads can saturate or thrash disk I/O (HDD seek thrash, limited queue depth, network FS latency).
- Result: isolates block on I/O, CPU stays low, total wall time increases.

### 3) UI jank from bursty isolate spawning + frequent UI rebuilds

Even when computation is off-main-thread:

- `Isolate.spawn` and port setup costs work on the main (UI) isolate.
- Spawning many isolates in a short burst steals time from frame rendering.
- If the UI calls `setState` very frequently (per-task start/finish), it adds frame pressure.

---

## What to Change (Fix Options)

### Option A (Recommended for a package): Init once, never cleanup per job

**Idea**

- Initialize FFmpeg once (lazily, on first use) and **never** call cleanup per job.
- FFmpeg's global state remains initialized for the process lifetime.
- Let the OS reclaim resources when the process exits.

**Why it's appropriate for a package**

- Packages have no control over app lifecycle — there's no reliable "shutdown" hook.
- Calling `Sonix.dispose()` on an instance should **not** deinit FFmpeg globals, because other `Sonix` instances (or future ones) may still need it.
- FFmpeg is designed to stay initialized for a process's lifetime. `avformat_network_deinit()` is rarely necessary and mostly for leak-checker hygiene.

**Implementation sketch**

1. In `lib/src/isolate/isolate_runner.dart` (isolate worker):
   - Keep `NativeAudioBindings.initialize()` (idempotent, checks `_initialized`).
   - **Remove** both `NativeAudioBindings.cleanup()` calls (success path and error path).

2. In `lib/src/native/native_audio_bindings.dart`:
   - Keep `cleanup()` method for API completeness, but either:
     - Make it a no-op, or
     - Document it as "optional, only for tests/leak-checkers".

**Tradeoffs**

- Minor: FFmpeg resources (a few KB of global state) remain allocated until process exit.
- This is normal and expected for media libraries.

---

### Option B: Native-side reference counting + mutex (more robust, more complex)

**Idea**

- Add a thread-safe refcount in native code.
- `sonix_init_ffmpeg()` increments refcount (and inits if 0→1).
- `sonix_cleanup_ffmpeg()` decrements refcount (and deinits if 1→0).
- Protect with a mutex (pthread_mutex on POSIX, CriticalSection on Windows).

**Why it helps**

- Safe for any usage pattern (multiple Sonix instances, concurrent jobs, etc.).
- Cleanup happens exactly once when truly no longer needed.

**Tradeoffs**

- More complex native code.
- Must be correct on all platforms.
- Probably overkill for a media lib where "init once, never deinit" is acceptable.

---

### Option C: Expose a static `Sonix.shutdownNative()` (optional, for power users)

**Idea**

- Provide a static method that consumers can call if they really want to release FFmpeg resources.
- Document it as: "Only call this when you're certain no more audio processing will occur."

**Implementation sketch**

```dart
class Sonix {
  /// Releases native FFmpeg resources. 
  /// Only call when no more waveform generation will occur.
  /// Most apps should never call this.
  static void shutdownNative() {
    NativeAudioBindings.cleanup();
  }
}
```

**Tradeoffs**

- Gives control to advanced users.
- Risk: user calls it prematurely, then tries to generate a waveform → crash or error.
- Could be combined with Option A (no per-job cleanup, but optional explicit shutdown).

---

### Option D: Concurrency limiting (complementary, not the root fix)

**Idea**

- Limit concurrent isolate jobs to 2–4 in the consumer code or example app.

**Why it helps**

- Reduces isolate spawn bursts → less UI jank.
- Reduces I/O contention.

**But**

- Does not fix the FFmpeg init/cleanup thrash.
- Should be done **in addition to** Option A or B, not instead of.

---

### Option E: Reduce I/O amplification

If the bottleneck is file I/O:

- Lower the chunk threshold in `AudioFileProcessor` so streaming kicks in earlier.
- Consumers should ensure files are on SSD (or locally cached) when benchmarking.

---

## Experiments to Validate Root Cause (Fast Checks)

1. **A/B test**: Comment out per-job `NativeAudioBindings.cleanup()` in isolate worker.
   - If 8 isolates becomes much faster and UI less laggy → confirmed FFmpeg global thrash.

2. **I/O test**: Run the same benchmark with files on SSD vs HDD/network drive.
   - If SSD massively improves scaling → I/O contention is dominant.

3. **Spawn burst test**: Add a small stagger (e.g., 50ms) between isolate spawns.
   - If jank reduces but throughput doesn't improve → spawn/rebuild pressure is secondary.

---

## Summary for Next Agent Session

- The "single isolate per request" simplification is fine.
- **FFmpeg lifecycle must not be per-request** — that's the root cause.
- Recommended fix: **Option A** (remove per-job cleanup, init once, let OS reclaim).
- Optionally combine with **Option C** (static shutdown method for power users).
- Apply **Option D** (concurrency limiting in examples) as a complementary measure.

**Minimal PR to test the hypothesis:**
- Edit `lib/src/isolate/isolate_runner.dart`
- Remove the two `NativeAudioBindings.cleanup()` calls
- Re-run the concurrent example with 8 isolates and verify improvement
