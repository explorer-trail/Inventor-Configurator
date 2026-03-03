# RFAExportRCEPlugin — Documentation

## What It Does

RFAExportRCEPlugin exports an Inventor model to a **Revit Family (`.rfa`) file** using Inventor's BIM (Building Information Modelling) component export. This allows configurator outputs to be used directly in Autodesk Revit. It is invoked **on-demand** when a user requests an RFA export from the UI.

---

## Files

| File | Purpose |
|---|---|
| `RFAExportRCEAutomation.cs` | Main plugin logic — finds the BIM component and exports it |
| `PluginServer.cs` | COM entry point — Inventor loads this as an AddIn |
| `RFAExportRCEPlugin.csproj` | Build project — packages everything into a bundle ZIP |
| `RFAExportRCEPlugin.Inventor.addin` | Addin manifest — tells Inventor how to load the plugin |
| `PackageContents.xml` | Design Automation bundle definition |
| `WebApplication/Processing/CreateRFA.cs` | Web app side — registers the activity with FDA |

Shared dependencies:

| File | Purpose |
|---|---|
| `Shared/AutomationBase.cs` | Base class — document opening with LOD support, logging |

The compiled bundle is:
```
WebApplication/AppBundles/RFAExportRCEPlugin.bundle.zip
```

---

## How It Works — Step by Step

### 1. Inventor loads the plugin
`PluginServer.Activate()` creates an instance of `RFAExportRCEAutomation`.

### 2. `ExecWithArguments()` is called (inside a `HeartBeat`)
The document is the Inventor model to export. The HeartBeat wrapper keeps the FDA service alive during the (potentially slow) RFA export.

### 3. The BIM component is retrieved
The plugin looks for the `BIMComponent` object on the document's `ComponentDefinition`:
- **Assembly document** → `AssemblyDocument.ComponentDefinition.BIMComponent`
- **Part document** → `PartDocument.ComponentDefinition.BIMComponent`

If no BIM component exists (the model was not set up for BIM export in Inventor), the plugin logs an error and exits without producing output.

### 4. The RFA is exported
`bimComponent.ExportBuildingComponentWithOptions(fileName, options)` is called with:
- **Output file:** `Output.rfa` in the current working directory
- **Report file:** `Report.html` (an export validation report)

The plugin records the start and end timestamps and logs the export duration.

### 5. Outputs are validated
After export, the plugin checks whether `Output.rfa` and `Report.html` exist:
- If `Output.rfa` exists → logs success with duration
- If `Output.rfa` is missing → logs an error
- Same check for `Report.html`

FDA uploads `Output.rfa` to OSS.

---

## Input and Output

### Input
| Parameter | Description |
|---|---|
| `InventorDoc` | `.ipt` or `.iam` (assembly provided as a ZIP), with a BIM component configured |

### Output
| File | Description |
|---|---|
| `Output.rfa` | Revit Family file for use in Autodesk Revit |
| `Report.html` | BIM export validation report (not uploaded to OSS, stays in FDA logs) |

---

## How It Is Invoked (FDA Activity)

```
$(engine.path)\InventorCoreConsole.exe /al "$(appbundles[CreateRFA].path)" /ilod "$(args[InventorDoc].path)"
```

| Flag | Meaning |
|---|---|
| `/al` | Auto-load the plugin bundle |
| `/ilod` | Input load-on-demand — opens the model with its last active Level of Detail and Design View representation |

**Engine:** Autodesk.Inventor+2025

---

## Where It Fits in the Workflows

This plugin is **not part of AdoptProject or UpdateProject**. It is invoked on-demand:

1. User requests an RFA export from the UI
2. `RFAJobItem` is created
3. `ProjectWork.GenerateRfaAsync()` prepares the work item via `_arranger.ForRfaAsync()`
4. `FdaClient.GenerateRfa()` executes the FDA activity
5. On success, the `.rfa` file is moved to its final OSS location via `_arranger.MoveRfaAsync()`
6. The download URL is returned to the UI

---

## Error Handling

| Situation | Behaviour |
|---|---|
| Document has no BIM component | Logs error, exits — no `.rfa` produced |
| Unsupported document type | Logged, BIM component returns null → exits |
| Export fails | Exception caught, logged as error |
| `Output.rfa` missing after export | Logged as error |
| `Report.html` missing after export | Logged as error |
| Any unhandled exception | Caught in `ExecWithArguments`, logged as `"Processing failed."` |

---

## Prerequisites

The Inventor document must have a **BIM component** configured. This is set up in Inventor via the BIM Exchange panel, where the model is prepared as a building component with appropriate classification and geometry simplification. Without it, the plugin exits without producing output.

---

## Plugin Registration

| Property | Value |
|---|---|
| COM Class GUID | `{506ce94e-88ba-4891-b989-d4cf85ba0fff}` |
| Assembly | `RFAExportRCEPlugin.dll` |
| Target Framework | .NET Framework 4.8 |
