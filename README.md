# K2040 xEdit JSON Exporter

A read-only xEdit/FO4Edit Pascal script that exports Bethesda plugin data to JSON.

## What it does

The exporter is intended for inspection, comparison, documentation, and external tooling. It does not apply JSON back to plugins and is not a runtime dependency for mods.

It supports whole-plugin, group, single-record, and multi-record exports.

The exporter preserves useful record identity and structure where xEdit exposes it, including signatures, FormIDs, EditorIDs, names, nested data, arrays, child order, and repeated fields.

## Installation

Copy `src/K2040_xEdit_JSON_Exporter.pas` into the xEdit/FO4Edit `Edit Scripts` folder.

Start xEdit/FO4Edit, load the plugin or records you want to inspect, then use **Apply Script** and select the exporter.

On Linux, run xEdit/FO4Edit through Wine or the compatibility setup used by your mod manager.

See `docs/usage.md` for the basic workflow.

## Output

The exporter writes JSON for the selected plugin data. Repeated xEdit child names are preserved instead of silently overwriting earlier values.

Generated JSON should be validated before being used by other tools, especially when working with large plugins or unusual record structures.

## Safety

The exporter is read-only. It does not edit, clean, compact, renumber, add, remove, or save plugin records.

Do not commit game files, third-party plugins, saves, load-order data, or large generated exports to this repository.

## Development

Keep the exporter generic and source-neutral. Game- or mod-specific interpretation belongs outside the exporter itself.

Contributor testing guidance is available in `docs/testing.md`.

## License

K2040 xEdit JSON Exporter is released under the GNU General Public License version 3. See `LICENSE` for the full terms.
