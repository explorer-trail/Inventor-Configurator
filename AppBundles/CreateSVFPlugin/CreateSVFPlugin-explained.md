# CreateSVFPlugin — Documentation

## What It Does

CreateSVFPlugin is an Autodesk Inventor Design Automation plugin that exports an Inventor document (`.ipt` part or `.iam` assembly) into **SVF (Simple View Format)** — the format used by the Autodesk Platform Services Viewer to display 3D models in a browser.

It runs headlessly in the cloud via Forge Design Automation (FDA) and is triggered as part of two workflows:
- **AdoptProject** — when a new project is first uploaded
- **UpdateProject** — when project parameters are updated

---

## Files

| File | Purpose |
|---|---|
| `CreateSvfAutomation.cs` | Main plugin logic — performs the SVF export |
| `PluginServer.cs` | COM entry point — Inventor loads this as an AddIn |
| `CreateSVFPlugin.csproj` | Build project — packages everything into a bundle ZIP |
| `CreateSVFPlugin.Inventor.addin` | Addin manifest — tells Inventor how to load the plugin |
| `CreateSVFPlugin.X.manifest` | COM registration manifest |
| `PackageContents.xml` | Design Automation bundle definition |
| `WebApplication/Processing/CreateSVF.cs` | Web app side — registers the activity with FDA |

The compiled and packaged artifact is:
```
WebApplication/AppBundles/CreateSVFPlugin.bundle.zip
```

---

## How It Works — Step by Step

### 1. Inventor loads the plugin
Inventor (running headlessly in the FDA cloud) loads `PluginServer.cs` as a COM AddIn via the `.addin` manifest. The `Activate()` method initialises the `InventorServer` reference and creates an instance of `CreateSvfAutomation`.

### 2. `ExecWithArguments()` is called
FDA calls `ExecWithArguments(Document doc, NameValueMap map)` on the automation class, passing the opened Inventor document.

### 3. The SVF Translator AddIn is located
The plugin searches Inventor's loaded AddIns collection for the built-in SVF Translator by its fixed class ID:
```
{C200B99B-B7DD-4114-A5E9-6557AB5ED8EC}
```
This is Inventor's internal SVF export component.

### 4. Export options are configured
A `NameValueMap` is populated with these export settings:

| Option | Value | Effect |
|---|---|---|
| `GeometryType` | `1` | Standard geometry detail level |
| `EnableExpressTranslation` | `false` | Full translation (not fast/lightweight) |
| `SVFFileOutputDir` | `{workdir}\SvfOutput` | Where SVF files are written |
| `ExportFileProperties` | `true` | Includes document properties in output |
| `ObfuscateLabels` | `false` | Keeps part/component labels readable |

### 5. `SaveCopyAs()` exports the SVF
The translator AddIn's `SaveCopyAs()` method performs the actual export. The operation is wrapped in a `HeartBeat()` using statement, which keeps the FDA service alive during the potentially long export process.

### 6. `bubble.json` is moved to the output root
The translator writes `bubble.json` inside an `output/` subdirectory. After export, the plugin moves it up to the root of `SvfOutput/` so the web application can find it at the expected path.

### 7. `SvfOutput/` is zipped and uploaded
FDA zips the entire `SvfOutput/` folder and uploads it to OSS as `SvfOutput.zip`. The web application later downloads and extracts this zip into `LocalCache`.

---

## Input and Output

### Input
| Parameter | Description |
|---|---|
| `InventorDoc` | The `.ipt` or `.iam` file to process (assembly is provided as a ZIP) |

### Output Directory Structure
```
SvfOutput/
├── bubble.json          ← SVF manifest (index file for the viewer)
├── result.collaboration ← Main SVF output file from SaveCopyAs
└── output/
    ├── *.svf            ← Viewable geometry files
    ├── *.pdb            ← Property data blocks
    ├── *.bin            ← Binary mesh data
    └── (other SVF assets)
```

The entire `SvfOutput/` folder is zipped before upload (`SvfOutput.zip`).

---

## How It Is Invoked (FDA Activity)

The FDA activity command line is:
```
$(engine.path)\InventorCoreConsole.exe /al "$(appbundles[CreateSVF].path)" /ilod "$(args[InventorDoc].path)"
```

| Flag | Meaning |
|---|---|
| `/al` | Auto-load the plugin bundle |
| `/ilod` | Input load-on-demand (optimised document open) |

The engine used is **Autodesk.Inventor+2025**.

---

## Where It Fits in the Workflows

### AdoptProject workflow
```
DataChecker → CreateSVF → CreateThumbnail → CreateBOM → ExtractParameters
```

### UpdateProject workflow
```
UpdateParameters → CreateSVF → CreateBOM
```

---

## Error Handling

```
ExecWithArguments()
└── try
    └── SaveAsSVF()
        └── try
                TranslatorAddIn.SaveCopyAs()
            catch Exception e
                LogError("********Export to format SVF failed: {e.Message}")
    catch Exception e
        LogError("Processing failed. " + e.ToString())
```

- If the SVF Translator AddIn is not found (`oAddin == null`), the export is silently skipped.
- Errors inside `SaveCopyAs()` are caught and logged with an `"********"` prefix to make them stand out in the FDA report log.
- All logging goes via `Trace.TraceInformation()` / `Trace.TraceError()`, which FDA captures into the report file saved in `LocalCache/Reports/`.

---

## Plugin Registration

| Property | Value |
|---|---|
| COM Class GUID | `{5b608275-a063-4323-ae3b-195eaabf2049}` |
| Assembly | `CreateSVFPlugin.dll` |
| Target Framework | .NET Framework 4.8 |
| Assembly Version | 1.0.0.3 |

---

## Build and Packaging

The `AfterBuild` target in `CreateSVFPlugin.csproj` automatically:
1. Copies `PackageContents.xml` into the bundle folder
2. Copies the compiled `.dll`, `.addin`, and `.pdb` into `bundle/Contents/`
3. Zips everything into `WebApplication/AppBundles/CreateSVFPlugin.bundle.zip`

This ZIP is what gets uploaded to FDA when `FdaClient` initialises the activity via:
```csharp
await new CreateSVF(_publisher).InitializeAsync(_paths.CreateSVF);
```
