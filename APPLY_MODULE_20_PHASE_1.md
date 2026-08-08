# Apply Mega Sprint 20 — Office Studio Pro Phase 1

If your GitHub repository is newer than this full-project archive, copy only these files into your repository:

1. `lib/features/documents/office_studio_page.dart`
2. `pubspec.yaml` (or only update the version to `1.20.0+40` if your pubspec has newer dependency edits)
3. `MEGA_SPRINT_20_OFFICE_STUDIO_PRO_PHASE_1.md`

The included `.github/workflows/flutter-ci.yml` is a minimal build-only CI matching the stable workflow approach used after analyzer/test gating was temporarily disabled. If your current GitHub Actions workflow already succeeds, keep your current workflow instead of overwriting it.

Then run:

```bash
flutter clean
flutter pub get
flutter run
```

And commit:

```bash
git add -A
git commit -m "Mega Sprint 20 Office Studio Pro Phase 1"
git push origin main
```
