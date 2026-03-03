# UpdateDrawingsPlugin — Documentation

## What It Does

UpdateDrawingsPlugin finds all Inventor drawing files (`.idw`, `.dwg`) inside a project, forces each one to update against the latest model state, and copies them into a single output folder. It is invoked **on-demand** when the user requests updated drawings from the configurator UI.

---

## Files

| File | Purpose |
|---|---|
| `UpdateDrawingsAutomation.cs` | Main plugin logic — finds, updates and copies drawings |
| `PluginServer.cs` | COM entry point — Inventor loads this as an AddIn |
| `UpdateDrawingsPlugin.csproj` | Build project — packages everything into a bundle ZIP |
| `UpdateDrawingsPlugin.Inventor.addin` | Addin manifest — tells Inventor how to load the plugin |
| `PackageContents.xml` | Design Automation bundle definition |
| `WebApplication/Processing/UpdateDrawings.cs` | Web app side — registers the activity with FDA |

The compiled bundle is:
```
WebApplication/AppBundles/UpdateDrawingsPlugin.bundle.zip
```

---

## How It Works — Step by Step

### 1. Inventor loads the plugin
`PluginServer.Activate()` creates an instance of `UpdateDrawingsAutomation`.

### 2. `RunWithArguments()` is called (inside a `HeartBeat`)
If no document was provided by FDA (i.e. the job was launched without a specific model file), the plugin activates or creates a default Inventor project file (`FDADefault.ipj`) so that Inventor has a valid project context.

### 3. Drawing files are discovered
The plugin scans the current working directory recursively for all files with `.idw` or `.dwg` extensions, excluding any `oldversions\` subdirectory (Inventor's automatic backup folder).

### 4. Each drawing is opened, updated, and saved
For each drawing file found:
1. The drawing is opened using `Documents.Open()`
2. `Update2(true)` is called to force the drawing to resolve against the latest model
3. `Save2(true)` saves the updated drawing

### 5. Updated drawings are copied to the output folder
Each updated drawing is copied into the `drawing/` output directory, preserving the original folder structure relative to the project root.

### 6. FDA zips and uploads `drawing/`
FDA zips the entire `drawing/` directory and uploads it as `drawing.zip` to OSS.

---

## Input and Output

### Input
| Parameter | Description |
|---|---|
| `InventorDoc` | The model file (optional — if absent, a default project is activated) |

All drawing files (`.idw`, `.dwg`) in the working directory are processed automatically.

### Output
| Folder / File | Description |
|---|---|
| `drawing/` (zipped) | All updated drawing files, with original subdirectory structure preserved |

The output is marked as **optional** — if no drawings exist in the project, the work item still succeeds.

---

## How It Is Invoked (FDA Activity)

```
$(engine.path)\InventorCoreConsole.exe /al "$(appbundles[UpdateDrawings].path)" "$(args[InventorDoc].path)"
```

**Engine:** Autodesk.Inventor+2025

---

## Where It Fits in the Workflows

This plugin is **not part of AdoptProject or UpdateProject**. It is invoked on-demand:

1. User requests updated drawing files from the UI
2. `DrawingJobItem` is created
3. `ProjectWork.GenerateDrawingAsync()` invokes `FdaClient.GenerateDrawing()`
4. FDA runs the plugin; the output ZIP is stored in OSS
5. The download URL is returned to the UI

---

## Error Handling

| Situation | Behaviour |
|---|---|
| No drawings found | Output folder is empty; work item succeeds (output is optional) |
| Drawing fails to open/update | Exception caught by outer try-catch, logged as error |
| Default project activation fails | Exception propagates — FDA work item marked as failed |

---

## Plugin Registration

| Property | Value |
|---|---|
| COM Class GUID | `{7DD8A91A-B063-44F2-B93B-C80827E1E155}` |
| Assembly | `UpdateDrawingsPlugin.dll` |
| Target Framework | .NET Framework 4.8 |
