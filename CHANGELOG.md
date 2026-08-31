# Changelog

## v1.6

- Fixed silent data loss when xEdit exposes more than one sibling field with the same name.
- Repeated values are now preserved in order instead of later entries replacing earlier ones.
- Fixed the reported MGEF Actor Value export problem.
- Fixed repeated keyword loss in structures such as APPR and KWDA.
- Kept unique sibling fields in their existing JSON object form.

Thanks to twizz0r for the clear repeated-sibling reproduction that helped confirm the shared root cause.

## v1.5

- Fixed automatic filenames for full ESP/ESL/ESM exports so they no longer append every exported record signature.

## v1.4

- Shortened automatic filenames.
- Added selected-record signatures to filenames when useful.

## v1.3

- Added a compact export summary with readable record-type counts.

## v1.2

- Directory-only output paths now receive the automatic filename.

## v1.1

- Bare and relative output paths are resolved under xEdit's script path.
