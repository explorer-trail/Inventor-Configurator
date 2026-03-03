# ExtractParametersPlugin — Documentation

## What It Does

ExtractParametersPlugin reads all user-facing parameters from an Inventor document (`.ipt` part or `.iam` assembly) and writes them to a JSON file (`documentParams.json`). This file drives the configurator UI, telling it which parameters exist, what their current values are, and what values are valid.

It is the final step in the **AdoptProject** workflow and is also invoked implicitly by **UpdateParametersPlugin** after applying changes.

---

## Files

| File | Purpose |
|---|---|
| `ExtractParametersAutomation.cs` | Main plugin logic — orchestrates parameter extraction |
| `PluginServer.cs` | COM entry point — Inventor loads this as an AddIn |
| `ExtractParametersPlugin.csproj` | Build project — packages everything into a bundle ZIP |
| `ExtractParametersPlugin.Inventor.addin` | Addin manifest — tells Inventor how to load the plugin |
| `PackageContents.xml` | Design Automation bundle definition |
| `WebApplication/Processing/ExtractParameters.cs` | Web app side — registers the activity with FDA |

Shared logic used by this plugin (via project reference):

| File | Purpose |
|---|---|
| `PluginUtilities/ParametersExtractor.cs` | Core extraction logic |
| `PluginUtilities/iLogicUtility.cs` | Reads iLogic form definitions |
| `Shared/AutomationBase.cs` | Base class — document opening and logging |
| `Shared/InventorParameters.cs` | Data model for the output JSON |

The compiled bundle is:
```
WebApplication/AppBundles/ExtractParametersPlugin.bundle.zip
```

---

## How It Works — Step by Step

### 1. Inventor loads the plugin
`PluginServer.Activate()` is called by FDA, which creates an instance of `ExtractParametersAutomation`.

### 2. `ExecWithArguments()` is called
FDA passes the opened Inventor document. The plugin checks the document type:
- `kPartDocumentObject` → reads `PartDocument.ComponentDefinition.Parameters`
- `kAssemblyDocumentObject` → reads `AssemblyDocument.ComponentDefinition.Parameters`
- Anything else → logs an error and exits

### 3. `ParametersExtractor.Extract()` runs (inside a `HeartBeat`)
The `HeartBeat` wrapper keeps the FDA service alive during the (potentially slow) extraction.

#### 3a. All user parameters are extracted
For each user parameter in the document:
- The unit type is resolved via `UnitsOfMeasure.GetTypeFromString()`
- The expression is validated via `UnitsOfMeasure.IsExpressionValid()`
- If valid: the value is converted to a display string via `GetPreciseStringFromValue()`
- If invalid: an `errorMessage` is attached to that parameter
- Any available `ExpressionList` (dropdown options) is captured as a `values` array

#### 3b. iLogic forms are scanned
The plugin reads any iLogic forms attached to the document using `UiStorage.LoadFormSpecification()`. Forms define which parameters are exposed to users and provide human-readable labels.

#### 3c. The winning parameter set is selected
- If an iLogic form exists with parameters → those parameters (with their labels) are used
- If no iLogic form exists → all user parameters are used

### 4. The document is updated and saved
`doc.Update2()` and `doc.Save2(SaveDependents: true)` are called before closing.

### 5. `documentParams.json` is written
The parameter dictionary is serialised to JSON (no whitespace, nulls omitted) and written to the working directory. FDA uploads this file to OSS.

---

## Input and Output

### Input
| Parameter | Description |
|---|---|
| `InventorDoc` | `.ipt` or `.iam` (assembly provided as a ZIP) |

### Output
| File | Description |
|---|---|
| `documentParams.json` | JSON dictionary of all extracted parameters |

### Output JSON Structure
```json
{
  "Width": {
    "value": "10 in",
    "unit": "in",
    "values": ["5 in", "10 in", "15 in"],
    "label": "Width of Part",
    "readonly": false
  },
  "Material": {
    "value": "Steel",
    "unit": "Text",
    "values": ["Steel", "Aluminium"],
    "errormessage": null
  }
}
```

| Field | Description |
|---|---|
| `value` | Current value or expression |
| `unit` | Unit type name (e.g. `"in"`, `"mm"`, `"Text"`) |
| `values` | Valid expression alternatives (dropdown options) |
| `label` | Human-readable label from iLogic form (if present) |
| `readonly` | Whether the parameter is read-only in the form |
| `errormessage` | Set if the expression is invalid for its unit type |

---

## How It Is Invoked (FDA Activity)

```
$(engine.path)\InventorCoreConsole.exe /al "$(appbundles[ExtractParameters].path)" /ilod "$(args[InventorDoc].path)"
```

| Flag | Meaning |
|---|---|
| `/al` | Auto-load the plugin bundle |
| `/ilod` | Input load-on-demand (optimised document open) |

**Engine:** Autodesk.Inventor+2025

---

## Where It Fits in the Workflows

### AdoptProject (5th and final step)
```
DataChecker → CreateSVF → CreateThumbnail → CreateBOM → ExtractParameters
```

### UpdateProject (invoked implicitly by UpdateParametersPlugin)
`UpdateParametersPlugin` calls `ParametersExtractor.Extract()` directly after applying parameter changes — it does not invoke this plugin as a separate FDA activity.

---

## Error Handling

| Situation | Behaviour |
|---|---|
| Unsupported document type | Logs error, exits cleanly |
| Invalid parameter expression | Sets `errormessage` field in JSON, continues |
| Exception reading a parameter | Logs error with parameter name, continues to next parameter |
| Exception in `SaveCopyAs` / `Save2` | Propagates to outer try-catch, logs full stack trace |
| Any unhandled exception | Caught in `ExecWithArguments`, logged as `"Processing failed."` |

---

## Plugin Registration

| Property | Value |
|---|---|
| COM Class GUID | `{824d9b00-545b-4929-accf-a47b7eca80a1}` |
| Assembly | `ExtractParametersPlugin.dll` |
| Target Framework | .NET Framework 4.8 |
| Assembly Version | 2.0.0.14 |
