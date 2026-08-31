# Usage

Copy `src/K2040_xEdit_JSON_Exporter.pas` into the xEdit/FO4Edit `Edit Scripts` folder.

Start xEdit/FO4Edit, load the plugin or records you want to inspect, then select a plugin, group, one record, or several records. Use **Apply Script** and choose the exporter.

If you leave the output name blank, the exporter creates a JSON filename from the plugin name. You can also enter a custom filename or path.

On Linux, run xEdit/FO4Edit through Wine or the compatibility setup provided by your mod manager.

## Repeated fields

When xEdit exposes several sibling fields with the same name, the exporter keeps all of them in an ordered JSON array. Fields that occur only once keep the normal object form.

This prevents later values from silently replacing earlier ones.

## After exporting

Validate the JSON before relying on it for comparison or other tooling.

Large generated exports, game data, plugins, saves, and load-order data should not be committed to this repository.
