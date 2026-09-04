# Static Analysis Guide (Running on This Device)

> How to run `analyze` on the Famhub Web project from this Android/Termux device.
> Written so you never have to re-figure out the setup.

---

## 1. Environment Facts

| Item | Value |
|------|-------|
| Device | Android (aarch64), Termux shell |
| Toolchain location | **Inside the Ubuntu proot-distro container** |
| Flutter SDK | `/opt/flutter` inside the container (Flutter **3.47.1** stable, Dart **3.13.1**) |
| Project repo | `/data/data/com.termux/files/home/projects/Famhub-web` (bind-mounted into the container) |
| Analysis is possible? | **Yes.** Verified working on this device (no network needed once packages are fetched). |

The Flutter SDK is **not** installed on the raw Termux host. It lives under:
`/data/data/com.termux/files/usr/var/lib/proot-distro/containers/ubuntu/rootfs/opt/flutter`
which maps to `/opt/flutter` once you are inside the Ubuntu container.

---

## 2. One-Line Reminder

Run from the project directory **inside the Ubuntu container**:

```bash
flutter analyze
```

or, if `flutter` is not on `PATH`:

```bash
/opt/flutter/bin/flutter analyze
```

### Faster alternative (Dart SDK directly)

```bash
/opt/flutter/bin/cache/dart-sdk/bin/dart analyze
```

---

## 3. Step-by-Step (from the Termux host)

1. **Enter the Ubuntu container** (Termux command):
   ```bash
   proot-distro login ubuntu
   ```

2. **Go to the project** (the path is the same inside the container because the
   Termux home is bind-mounted):
   ```bash
   cd /data/data/com.termux/files/home/projects/Famhub-web
   ```

3. **Run the analyzer**:
   ```bash
   flutter analyze
   ```
   Expected output ends with something like:
   ```
   91 issues found. (ran in 57.9s)
   ```

---

## 4. Interpreting Results

- **Errors** (`error -`) mean code that won't compile — fix these first.
- **Warnings** (`warning -`) are likely bugs / dead code.
- **Infos** (`info -`) are style hints (`prefer_const_constructors`, etc.).
- Exit code is non-zero when issues are found.
- Baseline at the time of writing: **0 errors**, ~91 warnings + infos.

Current `analysis_options.yaml` ignores `unused_import` / `library_private_types_in_public_api`
and **excludes** generated/platform folders (`build/**`, `android/**`, `ios/**`,
`web/**`, `windows/**`, `macos/**`, `linux/**`).

---

## 5. Timing Reference (this device)

| Command | Wall time |
|---------|-----------|
| `flutter analyze` (whole project) | ~58 s |
| `dart analyze` (whole project) | ~51 s |
| `dart analyze <single file>` | ~16 s |

Whole-project analysis is the only slow path; single files/libraries are quick.

---

## 6. Useful Variants

```bash
# Analyze one file or folder only (much faster)
dart analyze lib/features/farm_management/presentation/pages/crops_page.dart
dart analyze lib/features/auth

# Fix auto-fixable style issues in place
dart fix --dry-run
dart fix --apply
```

---

## 7. Troubleshooting

| Symptom | Cause / Fix |
|---------|-------------|
| `flutter: command not found` | You are on the Termux host, not inside the container. Run `proot-distro login ubuntu` first, or use the full path `/opt/flutter/bin/flutter`. |
| Errors about missing packages | Run `flutter pub get` once inside the project dir (needs network the first time). |
| `Woah! You appear to be trying to run flutter as root.` | Harmless warning; the container runs as root. Ignore it. |
| `Error: proot-distro should not be executed under PRoot.` | You are already inside the container. Don't nest `proot-distro login` — just run the analyze commands. |
