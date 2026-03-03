# LocalCache — How It Works

## Overview

The `LocalCache` folder is the local disk cache for data downloaded from Autodesk Platform Services (APS/OSS). It sits at:
```
{WebApplication working directory}/LocalCache/
```
It is served to the frontend as the virtual path `/data`.

---

## Directory Structure

```
LocalCache/
├── [UserHash]/
│   └── [ProjectName]/
│       ├── metadata.json        ← project metadata
│       ├── thumbnail.png        ← project thumbnail
│       ├── drawingsList.json    ← list of drawings
│       ├── adopt-messages.json  ← messages from adoption
│       └── [ParametersHash]/
│           ├── parameters.json  ← Inventor parameters
│           ├── bom.json         ← Bill of Materials
│           ├── drawing_0.pdf    ← drawing PDFs
│           └── SVF/
│               └── bubble.json  ← 3D model viewer files
└── Reports/
    ├── [timestamp]_[workItemId].txt        ← FDA processing logs
    └── [timestamp]_[workItemId].stats.json ← processing statistics
```

---

## When Files Are Created

### 1. On Application Startup
**`Middleware/LocalCache.cs` — constructor**

The `LocalCache` root directory itself is created (if missing) at startup. It is registered as a singleton in `ServiceConfigurator.cs` and the middleware is wired up in `Startup.cs` via `localCache.Serve(app)`.

### 2. On Project Adoption (first upload)
**`State/ProjectStorage.cs` — `EnsureLocalAsync()`**

When a user adopts a new project, the app downloads from OSS and writes locally:
- `metadata.json`
- `thumbnail.png`
- `drawingsList.json`
- `adopt-messages.json`
- The **SVF ZIP** is downloaded and extracted into the `SVF/` subdirectory

### 3. On First 3D Model View Request (lazy restore)
**`Middleware/SvfRestore.cs`**

This middleware intercepts requests to `bubble.json`. If the SVF directory does not exist locally (e.g. after a server restart), it downloads and extracts it from OSS on-demand. Files are recreated transparently without the user noticing.

### 4. On Design Automation Completion (FDA callback)
**`Processing/PostProcessing.cs`**

When Forge Design Automation finishes processing, the app writes into `LocalCache/Reports/`:
- A `.txt` log file with the FDA report
- A `.stats.json` file with processing statistics

Controlled by the `SaveReport` setting in `appsettings.json`:
- **Development**: saves all reports (`"SaveReport": "All"` in `appsettings.Development.json`)
- **Production**: saves errors only (`"SaveReport": "ErrorsOnly"` in `appsettings.json`)

---

## When Files Are Deleted

| Trigger | What Is Deleted | Where |
|---|---|---|
| App starts with `clear=true` flag | Everything inside LocalCache | `Initializer.cs → ClearAsync()` |
| Project is **re-adopted** | That project's directory | `ProjectStorage.cs → DeleteLocal()` |
| Project is **deleted** via API | That project's directory | `ProjectService.cs` |
| Upload completes | Temporary uploaded file | `Job/AdoptJobItem.cs` |

---

## Key Files

| File | Role |
|---|---|
| `Middleware/LocalCache.cs` | Creates the root dir; serves files as static content via `/data` |
| `Middleware/SvfRestore.cs` | Lazy-restores SVF files from OSS on first viewer request |
| `State/ProjectStorage.cs` | Core download logic — writes all project files to cache |
| `Utilities/LocalNameConverter.cs` | Defines all file paths and names within LocalCache |
| `Processing/PostProcessing.cs` | Writes FDA report files into `LocalCache/Reports/` |
| `Initializer.cs` | Handles bulk clearing of LocalCache on startup |
