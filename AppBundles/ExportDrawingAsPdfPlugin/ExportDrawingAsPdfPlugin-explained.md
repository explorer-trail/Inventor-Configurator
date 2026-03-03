# ExportDrawingAsPdfPlugin — Documentation

## What It Does

ExportDrawingAsPdfPlugin opens a specific Inventor drawing file (`.idw`) and exports it to a PDF (`Drawing.pdf`), including all sheets. It is invoked **on-demand** when the user requests a drawing PDF in the configurator UI — not as part of the automatic adoption or update workflows.

---

## Files

| File | Purpose |
|---|---|
| `Automation.cs` | Main plugin logic — opens the drawing and exports to PDF |
| `PluginServer.cs` | COM entry point — Inventor loads this as an AddIn |
| `ExportDrawingAsPdfPlugin.csproj` | Build project — packages everything into a bundle ZIP |
| `ExportDrawingAsPdfPlugin.Inventor.addin` | Addin manifest — tells Inventor how to load the plugin |
| `PackageContents.xml` | Design Automation bundle definition |
| `WebApplication/Processing/ExportDrawing.cs` | Web app side — registers the activity with FDA |

The compiled bundle is:
```
WebApplication/AppBundles/ExportDrawingAsPdfPlugin.bundle.zip
```

---

## How It Works — Step by Step

### 1. Inventor loads the plugin
`PluginServer.Activate()` creates an instance of `Automation`.

### 2. `ExecWithArguments()` is called (inside a `HeartBeat`)
The drawing filename to export is read from `map.Item["_2"]` — a string parameter passed directly on the command line.

### 3. The drawing file is opened
The path is constructed as:
```
{CurrentWorkingDirectory}\unzippedIam\{drawingFilename}
```
The drawing is opened in read-only mode using `Documents.OpenWithOptions()`.

### 4. The drawing is updated and saved
`Update2(true)` is called to ensure the drawing reflects the latest model state, then `Save2(true)` saves any resolved changes.

### 5. The PDF translator AddIn is located
The plugin searches for Inventor's built-in PDF translator by its fixed class ID:
```
{0AC6FD96-2F4D-42CE-8BE0-8AEA580399E4}
```
If not found, the plugin logs an error and exits without producing output.

### 6. Export options are configured
| Option | Value |
|---|---|
| Sheet range | All sheets |
| Resolution | 300 DPI |
| Color | Preserved (not converted to black) |
| Per-sheet config | Name and 3DModel=false for each sheet |

### 7. `SaveCopyAs()` exports the PDF
The translator writes `Drawing.pdf` to the current working directory. FDA uploads this file to OSS.

---

## Input and Output

### Inputs
| Parameter | Description |
|---|---|
| `InventorDoc` | The assembly (`.iam` ZIP) that references the drawing |
| `DrawingParameter` | The relative path to the specific drawing to export (e.g. `Drawing1.idw`) |

The drawing file itself is found inside the `unzippedIam/` subdirectory at the path specified by `DrawingParameter`.

### Output
| File | Description |
|---|---|
| `Drawing.pdf` | All-sheets PDF export of the specified drawing, 300 DPI |

---

## How It Is Invoked (FDA Activity)

```
$(engine.path)\InventorCoreConsole.exe /al "$(appbundles[ExportDrawing].path)" "$(args[InventorDoc].path)" "$(args[DrawingParameter].value)"
```

Note: the drawing parameter is passed as a plain string value (not a file URL).

**Engine:** Autodesk.Inventor+2025

The PDF output is marked as **optional** — if the drawing has no exportable content, the work item still succeeds.

---

## Where It Fits in the Workflows

This plugin is **not part of AdoptProject or UpdateProject**. It is invoked on-demand:

1. User clicks to view/download a drawing PDF in the UI
2. `ExportDrawingPdfJobItem` is created
3. `ProjectWork.ExportDrawingPdfAsync()` checks the OSS cache
4. If not cached: FDA activity is invoked via `FdaClient.ExportDrawingAsync()`
5. The resulting PDF is stored in OSS and its URL is returned to the UI

**Caching:** Once generated, a drawing PDF is cached in OSS by its drawing index and parameters hash. Subsequent requests for the same drawing return the cached file without re-invoking FDA.

---

## Error Handling

| Situation | Behaviour |
|---|---|
| Drawing parameter not provided | Logs a warning, continues (may fail to open file) |
| Drawing file not found on disk | Exception propagates — FDA work item marked as failed |
| PDF translator AddIn not found | Logs error, exits — no PDF produced |
| `HasSaveCopyAsOptions` returns false | Silently skips export — no PDF produced |
| `SaveCopyAs()` fails | Exception propagates — FDA work item marked as failed |

---

## Plugin Registration

| Property | Value |
|---|---|
| COM Class GUID | `{6ace2032-7f14-4d7d-b3f4-bfd2e1190014}` |
| Assembly | `ExportDrawingAsPdfPlugin.dll` |
| Target Framework | .NET Framework 4.8 |
| Assembly Version | 1.0.0.2 |
