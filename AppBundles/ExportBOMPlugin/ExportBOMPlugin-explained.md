# ExportBOMPlugin — Documentation

## What It Does

ExportBOMPlugin extracts the Bill of Materials (BOM) from an Inventor assembly and writes it to a structured JSON file (`bom.json`). The BOM is shown in the configurator UI as a table listing all components, quantities, materials and descriptions. It runs as part of both the **AdoptProject** and **UpdateProject** workflows.

Part documents are skipped — BOM data only applies to assemblies.

---

## Files

| File | Purpose |
|---|---|
| `ExportBOMAutomation.cs` | Main plugin logic — extracts and serialises the BOM |
| `PluginServer.cs` | COM entry point — Inventor loads this as an AddIn |
| `ExportBOMPlugin.csproj` | Build project — packages everything into a bundle ZIP |
| `ExportBOMPlugin.Inventor.addin` | Addin manifest — tells Inventor how to load the plugin |
| `PackageContents.xml` | Design Automation bundle definition |
| `WebApplication/Processing/CreateBOM.cs` | Web app side — registers the activity with FDA |

Shared dependencies:

| File | Purpose |
|---|---|
| `Shared/ExtractedBOM.cs` | Data model for the BOM JSON structure |
| `Shared/AutomationBase.cs` | Base class — logging utilities |

The compiled bundle is:
```
WebApplication/AppBundles/ExportBOMPlugin.bundle.zip
```

---

## How It Works — Step by Step

### 1. Inventor loads the plugin
`PluginServer.Activate()` creates an instance of `ExportBOMAutomation`.

### 2. `Run(doc)` is called
The document type is checked:
- **Part document** — logs "No BOM for Part documents" and skips extraction. An empty BOM is written to JSON.
- **Assembly document** — proceeds to `ProcessAssembly()`.
- **Anything else** — throws `ArgumentOutOfRangeException`.

### 3. The BOM is set up (inside a `HeartBeat`)
An `ExtractedBOM` object is created with five fixed columns:

| Column | Numeric |
|---|---|
| Row Number | No |
| Part Number | No |
| Quantity | **Yes** |
| Description | No |
| Material | No |

The assembly's BOM object is retrieved and the **Structured** view is enabled (`bom.StructuredViewEnabled = true`). Structured view presents the BOM as a hierarchical breakdown of sub-assemblies and parts.

### 4. BOM rows are extracted recursively
`GetBomRowProperties()` iterates through each `BOMRow` in the structured view:
- Component properties are read from the **Design Tracking Properties** property set
- A data row is created: `[ItemNumber, PartNumber, Quantity, Description, Material]`
- If the row has child rows (a sub-assembly), the method recurses into them

### 5. `bom.json` is written
The `ExtractedBOM` is serialised to JSON using:
- `NullValueHandling.Ignore` — omits null fields
- `Formatting.None` — compact output (no whitespace)
- `CamelCaseNamingStrategy` — camelCase property names

---

## Input and Output

### Input
| Parameter | Description |
|---|---|
| `InventorDoc` | `.iam` assembly (provided as a ZIP); `.ipt` parts are skipped |

### Output
| File | Description |
|---|---|
| `bom.json` | Structured BOM table with columns and data rows |

### Output JSON Structure
```json
{
  "columns": [
    { "label": "Row Number" },
    { "label": "Part Number" },
    { "label": "Quantity", "numeric": true },
    { "label": "Description" },
    { "label": "Material" }
  ],
  "data": [
    [1, "PN-001", 2, "Base Plate", "Steel"],
    [2, "PN-002", 4, "Hex Bolt M8", "Steel"],
    [3, "PN-003", 1, "Cover Assembly", null]
  ]
}
```

---

## How It Is Invoked (FDA Activity)

```
$(engine.path)\InventorCoreConsole.exe /al "$(appbundles[CreateBOM].path)" /i "$(args[InventorDoc].path)"
```

Note: uses `/i` (not `/ilod`).

**Engine:** Autodesk.Inventor+2025

---

## Where It Fits in the Workflows

### AdoptProject (4th step)
```
DataChecker → CreateSVF → CreateThumbnail → CreateBOM → ExtractParameters
```

### UpdateProject (3rd step)
```
UpdateParameters → CreateSVF → CreateBOM
```

The BOM is regenerated whenever the project is updated because parameter changes can affect component quantities and configurations.

---

## Error Handling

| Situation | Behaviour |
|---|---|
| Part document provided | Logs info message, writes empty BOM JSON, exits cleanly |
| BOM extraction fails | Caught in inner try-catch, logs error, returns empty BOM |
| Unsupported document type | Throws `ArgumentOutOfRangeException` (caught by outer try-catch) |
| Any unhandled exception | Caught in `Run()`, logged as error — empty BOM is still written |

The plugin never throws out of `Run()`. Even on failure, a valid (possibly empty) `bom.json` is always written.

---

## Plugin Registration

| Property | Value |
|---|---|
| COM Class GUID | `{282d00a7-b2b5-488e-8a76-7c22280794a6}` |
| Assembly | `ExportBOMPlugin.dll` |
| Target Framework | .NET Framework 4.8 |
| Assembly Version | 1.0.0.4 |
