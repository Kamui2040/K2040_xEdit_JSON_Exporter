# Testing

Use the smallest test set that covers the change.

## Every change

- review the changed files and relevant diff;
- run `git diff --check`;
- make sure no game files, private data, machine-specific paths, or large generated exports were added.

## Exporter behavior changes

Run the script in xEdit/FO4Edit and verify the behavior directly.

Check the parts affected by the change, including where relevant:

- valid JSON output;
- whole-plugin, group, single-record, and multi-record exports;
- signatures, FormIDs, EditorIDs, names, nested structures, and arrays;
- repeated same-name fields without silent data loss;
- empty, null, missing, unresolved, unsupported, or malformed values;
- Unicode and JSON escaping;
- deterministic output from equivalent repeated exports;
- ESP/ESM/ESL and light-plugin identity when FormID handling changes;
- confirmation that the loaded plugins remain unchanged.

Generated test exports stay outside the repository unless a small fixture is deliberately created and is safe to redistribute.
