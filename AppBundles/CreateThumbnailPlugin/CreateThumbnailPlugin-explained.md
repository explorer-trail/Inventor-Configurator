# CreateThumbnailPlugin — Documentation

## What It Does

CreateThumbnailPlugin renders a small preview image (`thumbnail.png`, 30×30 pixels) of an Inventor document. The thumbnail is shown in the configurator UI as the project's visual identifier. It runs as the **3rd step** in the **AdoptProject** workflow.

---

## Files

| File | Purpose |
|---|---|
| `CreateThumbnailAutomation.cs` | Main plugin logic — renders and saves the thumbnail |
| `PluginServer.cs` | COM entry point — Inventor loads this as an AddIn |
| `CreateThumbnailPlugin.csproj` | Build project — packages everything into a bundle ZIP |
| `CreateThumbnailPlugin.Inventor.addin` | Addin manifest — tells Inventor how to load the plugin |
| `PackageContents.xml` | Design Automation bundle definition |
| `WebApplication/Processing/CreateThumbnail.cs` | Web app side — registers the activity with FDA |

The compiled bundle is:
```
WebApplication/AppBundles/CreateThumbnailPlugin.bundle.zip
```

---

## How It Works — Step by Step

### 1. Inventor loads the plugin
`PluginServer.Activate()` creates an instance of `CreateThumbnailAutomation`.

### 2. Visibility is cleaned up
Before rendering, the plugin hides elements that should not appear in the thumbnail:
- Work features (planes, axes, points)
- 2D sketches and 3D sketches
- Weldment symbols (assembly documents only)

### 3. A camera is created and positioned
A transient `Camera` object is created and configured:
- **Scene:** the document's `ComponentDefinition` (the geometry)
- **View:** Isometric Top-Right orientation
- `Fit()` is called to auto-frame the model
- `ApplyWithoutTransition()` applies the camera instantly

### 4. A 60×60 intermediate image is rendered
`Camera.SaveAsBitmap()` renders a 60×60 PNG with a **light gray background (RGB 236, 236, 236)**. This double-resolution intermediate is used to get a sharper final result.

### 5. The image is downsampled to 30×30
Using `System.Drawing.Graphics` with high-quality settings:
- Interpolation: `HighQualityBicubic`
- Compositing quality: `HighQuality`
- Smoothing: `HighQuality`
- Pixel offset: `HighQuality`
- Wrap mode: `TileFlipXY`

The final `thumbnail.png` (30×30) is saved to the working directory.

### 6. The intermediate file is deleted
The temporary 60×60 image (`thumbnail-large.png`) is removed.

---

## Input and Output

### Input
| Parameter | Description |
|---|---|
| `InventorDoc` | `.ipt` or `.iam` (assembly provided as a ZIP) |

### Output
| File | Description |
|---|---|
| `thumbnail.png` | 30×30 pixel PNG, light gray background, isometric view |

---

## How It Is Invoked (FDA Activity)

```
$(engine.path)\InventorCoreConsole.exe /al "$(appbundles[CreateThumbnail].path)" /ilod "$(args[InventorDoc].path)"
```

**Engine:** Autodesk.Inventor+2025

---

## Where It Fits in the Workflows

### AdoptProject (3rd step)
```
DataChecker → CreateSVF → CreateThumbnail → CreateBOM → ExtractParameters
```

---

## Error Handling

All logic is wrapped in a single try-catch. Any exception is logged as `"Processing failed."` with the full stack trace. The plugin does not validate the document type — both `.ipt` and `.iam` are processed the same way.

---

## Plugin Registration

| Property | Value |
|---|---|
| COM Class GUID | `{9779EFBE-3CA7-45A6-AE90-DA85485DD674}` |
| Assembly | `CreateThumbnailPlugin.dll` |
| Target Framework | .NET Framework 4.8 |
