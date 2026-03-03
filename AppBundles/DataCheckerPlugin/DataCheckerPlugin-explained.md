# DataCheckerPlugin — Documentation

## What It Does

DataCheckerPlugin validates an uploaded Inventor document and extracts metadata needed before any other processing begins. It is always the **1st step** in the **AdoptProject** workflow. It produces two output files: a list of all drawings found in the project, and a set of user-facing messages describing any issues (missing references, unsupported add-ins, etc.).

---

## Files

| File | Purpose |
|---|---|
| `DataCheckerAutomation.cs` | Main plugin logic — runs all validation checks |
| `PluginServer.cs` | COM entry point — Inventor loads this as an AddIn |
| `DataCheckerPlugin.csproj` | Build project — packages everything into a bundle ZIP |
| `DataCheckerPlugin.Inventor.addin` | Addin manifest — tells Inventor how to load the plugin |
| `PackageContents.xml` | Design Automation bundle definition |
| `WebApplication/Processing/DataChecker.cs` | Web app side — registers the activity with FDA |

Shared dependencies:

| File | Purpose |
|---|---|
| `Shared/AutomationBase.cs` | Base class — logging utilities |
| `Shared/Message.cs` | Data model for the messages JSON |

The compiled bundle is:
```
WebApplication/AppBundles/DataCheckerPlugin.bundle.zip
```

---

## How It Works — Step by Step

The plugin uses the `Run(doc)` entry point (not `ExecWithArguments`) because it requires no extra arguments from the work item. Three checks run in sequence inside a `HeartBeat` wrapper:

### 1. Extract the drawings list
Scans the current working directory recursively for all `.idw` and `.dwg` files, excluding `oldversions\` subdirectories (Inventor's automatic backup folders). Paths are stored relative to the `unzippedIam/` root.

**Sorting:** The drawing whose filename matches the main assembly document is moved to the top of the list. All others are sorted alphabetically.

Output: `drawings-list.json`

### 2. Detect unsupported add-ins
Iterates through all `DocumentInterests` on the document and all its referenced documents (recursively), collecting the `ClientId` of any add-in that has marked itself as "interested" in the document.

The following add-ins are flagged as unsupported in the Design Automation environment:

| Add-in | GUID |
|---|---|
| Frame Generator | `{AC211AE0-A7A5-4589-916D-81C529DA6D17}` |
| Tube & Pipe | `{4D39D5F1-0985-4783-AA5A-FC16C288418C}` |
| Cable & Harness | `{C6107C9D-C53F-4323-8768-F65F857F9F5A}` |
| Mold Design | `{24E39891-3782-448F-8C33-0D8D137148AC}` |
| Design Accelerator | `{BB8FE430-83BF-418D-8DF9-9B323D3DB9B9}` |

A **Warning** message is added to the messages list for each unsupported add-in detected.

### 3. Check for missing references
Traverses the document's full file reference tree recursively using `File.ReferencedFileDescriptors`. Any reference where `ReferenceMissing == true` is collected. Foreign file types (non-Inventor) are not recursed into.

A **Warning** message is added listing the unresolved filenames (up to two shown by name; additional ones counted).

### 4. Save messages
All collected messages are written to `adopt-messages.json`. The messages are also logged to the FDA report for debugging.

---

## Input and Output

### Input
| Parameter | Description |
|---|---|
| `InventorDoc` | `.ipt` or `.iam` (assembly provided as a ZIP) |

### Outputs
| File | Description |
|---|---|
| `drawings-list.json` | Sorted array of relative paths to all `.idw` / `.dwg` files |
| `adopt-messages.json` | Array of validation messages with severity levels |

### `drawings-list.json`
```json
["Drawing1.idw", "subdir/Drawing2.dwg"]
```

### `adopt-messages.json`
```json
[
  { "text": "Found 2 drawings", "severity": 0 },
  { "text": "Detected unsupported plugin: Tube & Pipe.", "severity": 1 },
  { "text": "Unresolved file: 'missing_part.ipt'.", "severity": 1 }
]
```

Severity levels: `0` = Info, `1` = Warning, `2` = Error

---

## How It Is Invoked (FDA Activity)

```
$(engine.path)\InventorCoreConsole.exe /al "$(appbundles[DataChecker].path)" /i "$(args[InventorDoc].path)"
```

Note: uses `/i` (not `/ilod`) — the document is opened without Level of Detail options.

**Engine:** Autodesk.Inventor+2025

DataChecker registers **two** output parameters with FDA (unlike other plugins which register one):
- `DataCheckerOutput` → `drawings-list.json`
- `DataCheckerMessages` → `adopt-messages.json`

---

## Where It Fits in the Workflows

### AdoptProject (1st and mandatory step)
```
DataChecker → CreateSVF → CreateThumbnail → CreateBOM → ExtractParameters
```

DataChecker always runs first. If it fails, adoption is stopped before any expensive processing begins.

---

## Error Handling

| Situation | Behaviour |
|---|---|
| Unsupported add-in found | Adds a Warning message, continues |
| Missing file reference found | Adds a Warning message, continues |
| `ExecWithArguments()` called | Logs an error — this plugin only uses `Run()` |
| File write fails | Exception propagates to FDA work item (marks work item as failed) |

Validation results in messages, not hard failures — the adoption continues even if warnings are found. The web application checks the messages after adoption and surfaces warnings to the user.

---

## Plugin Registration

| Property | Value |
|---|---|
| COM Class GUID | `{ae8a3c51-4366-42b3-8ba3-f78ea849584a}` |
| Assembly | `DataCheckerPlugin.dll` |
| Target Framework | .NET Framework 4.8 |
