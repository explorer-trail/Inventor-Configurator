# UpdateParametersPlugin — Documentation

## What It Does

UpdateParametersPlugin applies a set of parameter values (provided as JSON) to an Inventor document, then re-extracts all parameters to reflect the updated state. It is the first step in the **UpdateProject** workflow — run whenever the user changes parameter values in the configurator UI.

---

## Files

| File | Purpose |
|---|---|
| `UpdateParametersAutomation.cs` | Main plugin logic — applies parameters and re-extracts |
| `PluginServer.cs` | COM entry point — Inventor loads this as an AddIn |
| `UpdateParametersPlugin.csproj` | Build project — packages everything into a bundle ZIP |
| `UpdateParametersPlugin.Inventor.addin` | Addin manifest — tells Inventor how to load the plugin |
| `PackageContents.xml` | Design Automation bundle definition |
| `WebApplication/Processing/UpdateParameters.cs` | Web app side — registers the activity with FDA |

Shared logic used by this plugin (via project reference):

| File | Purpose |
|---|---|
| `PluginUtilities/ParametersExtractor.cs` | Re-extracts parameters after update |
| `PluginUtilities/iLogicUtility.cs` | Reads iLogic form definitions |
| `Shared/AutomationBase.cs` | Base class — document opening and logging |
| `Shared/InventorParameters.cs` | Data model for the input and output JSON |

The compiled bundle is:
```
WebApplication/AppBundles/UpdateParametersPlugin.bundle.zip
```

---

## How It Works — Step by Step

### 1. Inventor loads the plugin
`PluginServer.Activate()` is called by FDA, which creates an instance of `UpdateParametersAutomation`.

### 2. `ExecWithArguments()` is called
FDA passes the opened Inventor document and a `NameValueMap` containing the path to the parameters JSON file.

### 3. The input JSON is read
The path is obtained from `map.AsString("paramFile")`. The file is deserialised into an `InventorParameters` dictionary (the same format as `documentParams.json`), containing the target values the user has requested.

### 4. Each parameter is applied (inside a `HeartBeat`)
For each parameter in the incoming JSON:
1. The matching user parameter is located in the document by name
2. The new expression is validated via `UnitsOfMeasure.IsExpressionValid()`
3. If valid: `dynParameter.Expression = expression` is set on the Inventor parameter
4. If invalid: `paramData.ErrorMessage` is set and processing **stops** — no further parameters are applied
5. Any exception is caught and logged; processing continues to the next parameter

### 5. `ParametersExtractor.Extract()` is called
After applying changes, the plugin re-extracts all parameters (exactly as `ExtractParametersPlugin` does), passing the updated `incomingParams` as an override map. Any parameters that failed to apply will have their original values preserved in the output JSON with the `errormessage` field populated.

### 6. The document is saved and `documentParams.json` is written
`doc.Update2()` and `doc.Save2(SaveDependents: true)` are called. The updated parameter state is written to `documentParams.json` and the modified document is saved for use by the subsequent `CreateSVF` and `CreateBOM` steps.

---

## Input and Output

### Inputs
| Parameter | Description |
|---|---|
| `InventorDoc` | `.ipt` or `.iam` (assembly provided as a ZIP) |
| `InventorParams` | JSON file containing the parameter values to apply |

### Input JSON Structure (`InventorParams`)
```json
{
  "Width": { "value": "15 in" },
  "Material": { "value": "Aluminium" }
}
```

### Outputs
| File | Description |
|---|---|
| `documentParams.json` | Re-extracted parameters reflecting the updated state |
| Updated document | The modified `.ipt` or `.iam` with new parameter values baked in |

---

## How It Is Invoked (FDA Activity)

```
$(engine.path)\InventorCoreConsole.exe /al "$(appbundles[UpdateParameters].path)" /ilod "$(args[InventorDoc].path)" /paramFile "$(args[InventorParams].path)" /p
```

| Flag | Meaning |
|---|---|
| `/al` | Auto-load the plugin bundle |
| `/ilod` | Input load-on-demand (optimised document open) |
| `/paramFile` | Path to the incoming parameters JSON file |
| `/p` | Suppress Inventor's default parameter UI prompts |

**Engine:** Autodesk.Inventor+2025

---

## Where It Fits in the Workflows

### UpdateProject (1st step)
```
UpdateParameters → CreateSVF → CreateBOM
```

`UpdateParameters` runs first so that the modified document (with the new parameter values baked in) is available for `CreateSVF` and `CreateBOM` to work from.

---

## Error Handling

| Situation | Behaviour |
|---|---|
| Parameter name not found in document | Logs error, skips that parameter |
| Invalid expression for unit type | Sets `errormessage` in output JSON, **stops** applying further parameters |
| Exception setting a parameter | Logs full error, continues to next parameter |
| Any unhandled exception | Caught in `ExecWithArguments`, logged as `"Processing failed."` |

**Important:** When an invalid expression is encountered, the plugin stops applying any further parameters from that point. The parameters that were successfully applied before the error remain in the document.

---

## Plugin Registration

| Property | Value |
|---|---|
| Assembly | `UpdateParametersPlugin.dll` |
| Target Framework | .NET Framework 4.8 |
| FDA Activity ID | `UpdateParameters` |
