# WebApplication — Folder & File Structure

The WebApplication is an **ASP.NET Core** backend that hosts a **React** frontend (in `ClientApp/`). The backend handles authentication, project storage in APS/OSS, and orchestrating Forge Design Automation (FDA) jobs. The frontend is the configurator UI the user interacts with.

---

## Top-Level Files

| File | Purpose |
|---|---|
| `Program.cs` | Application entry point — creates and runs the ASP.NET Core host |
| `Startup.cs` | Configures services (DI) and the HTTP request pipeline (middleware order) |
| `ServiceConfigurator.cs` | Registers all application services into the DI container (keeps Startup.cs clean) |
| `Initializer.cs` | Runs once at startup — initialises FDA app bundles/activities and optionally clears the LocalCache |
| `Worker.cs` | Background service — processes queued jobs (upload, update, RFA, drawing export) from a queue |
| `Migration.cs` | Logic for migrating OSS data between old and new storage layouts |
| `MigrationJob.cs` | Job item for running a migration as a background task |
| `WebApplication.csproj` | MSBuild project file — defines dependencies, build targets, and SPA integration |
| `appsettings.json` | Base configuration (APS credentials, FDA settings, feature flags) |
| `appsettings.Development.json` | Development overrides (e.g. `SaveReport: All`) |
| `appsettings.Local.json` | Local developer secrets — **not committed to git** |
| `appsettings.Local.template.json` | Template showing which keys need to be filled in `appsettings.Local.json` |
| `console.log` | Runtime log output file |

---

## AppBundles/

Pre-built plugin bundle ZIP files, ready to be uploaded to Forge Design Automation. These are produced by each plugin project's build step and consumed at application startup by `Initializer.cs`.

| File | Plugin |
|---|---|
| `CreateSVFPlugin.bundle.zip` | Exports Inventor model to SVF (3D viewer format) |
| `CreateThumbnailPlugin.bundle.zip` | Renders a 30×30 thumbnail image |
| `DataCheckerPlugin.bundle.zip` | Validates model and extracts drawings list |
| `EmptyExePlugin.bundle.zip` | No-op executable used for OSS-to-OSS file transfers |
| `ExportBOMPlugin.bundle.zip` | Extracts Bill of Materials from an assembly |
| `ExportDrawingAsPdfPlugin.bundle.zip` | Exports a drawing (.idw) to PDF |
| `ExtractParametersPlugin.bundle.zip` | Reads Inventor parameters into JSON |
| `RFAExportRCEPlugin.bundle.zip` | Exports model as a Revit Family (.rfa) |
| `UpdateDrawingsPlugin.bundle.zip` | Updates and collects all drawings in a project |
| `UpdateParametersPlugin.bundle.zip` | Applies new parameter values to the model |

---

## Controllers/

ASP.NET Core API controllers — handle HTTP requests from the React frontend.

| File | Purpose |
|---|---|
| `ProjectsController.cs` | CRUD for projects — list, upload, delete, adopt |
| `ProjectDataController.cs` | Serves project data — parameters, BOM, drawings list, messages |
| `DownloadController.cs` | Serves downloadable files — drawing PDFs, updated drawings, RFA, SAT |
| `JobsHub.cs` | SignalR hub — pushes real-time job progress updates to the browser |
| `LoginController.cs` | Handles APS OAuth login/logout and token exchange |
| `ShowParametersChangedController.cs` | Notifies the UI when parameters have changed after an update |
| `ClearSelf.cs` | Admin endpoint — clears LocalCache and re-initialises the application |
| `VersionController.cs` | Returns the application version number |

---

## Definitions/

Data Transfer Objects (DTOs), configuration models, and shared exception types. These are plain data classes with no logic — they define the shapes of data flowing between layers.

| File | Purpose |
|---|---|
| `AdoptionData.cs` | URLs and metadata passed to FDA during project adoption |
| `AdoptProjectWithParametersPayload.cs` | Request payload for adopting a project with an initial parameter set |
| `AdditionalAppSettings.cs` | Strongly-typed model for app-specific settings from `appsettings.json` |
| `PublisherConfiguration.cs` | Settings for the FDA Publisher (engine, labels, environment) |
| `ProjectInfo.cs` | Basic project identity (name, ID) |
| `ProjectMetadata.cs` | Richer project metadata stored alongside the model in OSS |
| `ProjectDTO.cs` | Project data sent to the frontend (thumbnail URL, parameters URL, etc.) |
| `ProjectDTOBase.cs` | Base class for project DTOs |
| `ProjectStateDTO.cs` | Snapshot of a project's processing state |
| `ProfileDTO.cs` | Logged-in user profile (name, avatar URL) |
| `FdaStatsDTO.cs` | FDA processing statistics (credit cost, time) returned to the UI |
| `ProcessingResult.cs` | Result of an FDA work item — success flag, report URL, stats |
| `FdaProcessingException.cs` | Exception thrown when an FDA work item fails |
| `ProcessingException.cs` | Exception thrown when project processing fails (with user-facing messages) |
| `SdkManagerExtensions.cs` | Helper extension methods for the APS SDK Manager |

---

## Job/

Background job item classes. Each one represents a single unit of async work that `Worker.cs` picks up from the queue and executes.

| File | Purpose |
|---|---|
| `JobItemBase.cs` | Abstract base — common job execution and error handling logic |
| `IResultSender.cs` | Interface for sending job results back to the browser via SignalR |
| `ProcessingError.cs` | Represents an error that occurred during job processing |
| `AdoptJobItem.cs` | Runs the full adoption workflow (upload to OSS → FDA AdoptProject pipeline) |
| `AdoptProjectWithParametersJobItem.cs` | Adoption with an initial parameter override applied immediately |
| `UpdateModelJobItem.cs` | Runs the update workflow (apply new parameters → FDA UpdateProject pipeline) |
| `DrawingJobItem.cs` | Runs UpdateDrawings FDA activity to refresh all drawings |
| `ExportDrawingPdfJobItem.cs` | Runs ExportDrawing FDA activity to generate a PDF for one drawing |
| `RFAJobItem.cs` | Runs CreateRFA FDA activity to generate a Revit Family file |

---

## Middleware/

Custom ASP.NET Core middleware — sits in the HTTP request pipeline and intercepts or modifies requests/responses.

| File | Purpose |
|---|---|
| `LocalCache.cs` | Creates the `LocalCache/` directory at startup and serves its contents as static files under the `/data` virtual path |
| `SvfRestore.cs` | Intercepts requests to `bubble.json` — if the SVF files are missing locally, downloads and extracts them from OSS on demand (lazy restore) |
| `HeaderTokenHandler.cs` | Attaches the APS access token to outgoing API requests via an HTTP header |
| `RouteTokenHandler.cs` | Attaches the APS access token via a route parameter instead of a header |
| `SvfHeaderTokenHandler.cs` | Specialised token handler for SVF viewer requests |

---

## Pages/

Razor pages for server-rendered HTML — used only for the error page (everything else is served by the React SPA).

| File | Purpose |
|---|---|
| `Error.cshtml` | Server-side error page (shown when the SPA itself cannot load) |
| `Error.cshtml.cs` | Code-behind for the error page |
| `_ViewImports.cshtml` | Shared Razor directives imported into all pages |

---

## Processing/

The FDA orchestration layer — every class here either defines an FDA activity or coordinates how work items are created, executed, and post-processed.

### Activity Definitions

Each of these inherits from `ForgeAppBase` and defines one FDA activity (its ID, command line, input/output parameters, and bundle).

| File | FDA Activity | What it does |
|---|---|---|
| `DataChecker.cs` | `DataChecker` | Validates model; extracts drawings list and adoption messages |
| `CreateSVF.cs` | `CreateSVF` | Exports model to SVF (3D viewer format) |
| `CreateThumbnail.cs` | `CreateThumbnail` | Renders a thumbnail image |
| `CreateBOM.cs` | `CreateBOM` | Extracts Bill of Materials |
| `ExtractParameters.cs` | `ExtractParameters` | Reads Inventor parameters into JSON |
| `UpdateParameters.cs` | `UpdateParameters` | Applies new parameter values and re-extracts |
| `ExportDrawing.cs` | `ExportDrawing` | Exports one drawing to PDF |
| `UpdateDrawings.cs` | `UpdateDrawings` | Updates and collects all drawings |
| `CreateRFA.cs` | `CreateRFA` | Exports model as a Revit Family file |
| `CreateSAT.cs` | `CreateSAT` | Exports model as a SAT geometry file |
| `TransferData.cs` | `TransferData` | Copies a file between OSS buckets (uses EmptyExePlugin) |

### Workflow Compositions

| File | Purpose |
|---|---|
| `AdoptProject.cs` | Aggregated workflow: DataChecker → CreateSVF → CreateThumbnail → CreateBOM → ExtractParameters |
| `UpdateProject.cs` | Aggregated workflow: UpdateParameters → CreateSVF → CreateBOM |
| `AggregatedDefinition.cs` | Base class for running multiple FDA activities as a single logical operation |

### Infrastructure

| File | Purpose |
|---|---|
| `ForgeAppBase.cs` | Base class for all activity definitions — handles bundle registration, activity creation, work item arguments |
| `Publisher.cs` | Low-level FDA client wrapper — submits work items and polls for completion |
| `FdaClient.cs` | High-level FDA gateway — initialises all activities at startup and exposes typed methods (AdoptAsync, UpdateAsync, etc.) |
| `Arranger.cs` | Prepares OSS signed URLs and parameter hashes for each work item; moves outputs to their final OSS paths after completion |
| `PostProcessing.cs` | Handles FDA callbacks — saves report files to `LocalCache/Reports/` and logs stats |
| `ProjectWork.cs` | Business logic orchestrator — coordinates the full lifecycle of adopt, update, RFA, drawing, and file-transfer operations |

---

## Properties/

| File | Purpose |
|---|---|
| `launchSettings.json` | Visual Studio / dotnet run launch profiles — sets environment variables (including PATH for npm) and URLs |

---

## Services/

Reusable services registered in DI — provide access to APS APIs and cross-cutting concerns.

| File | Purpose |
|---|---|
| `ForgeOSS.cs` | Wrapper around the APS OSS API — upload, download, list, delete objects in buckets |
| `IForgeOSS.cs` | Interface for `ForgeOSS` (enables mocking in tests) |
| `ProjectService.cs` | Project-level operations — list projects, delete projects (including local cache cleanup) |
| `TokenService.cs` | Manages APS OAuth tokens (2-legged and 3-legged) |
| `ProfileProvider.cs` | Fetches the logged-in user's APS profile (name, avatar) |
| `SDKManagerProvider.cs` | Creates and provides the APS SDK Manager singleton |
| `IBucketKeyProvider.cs` | Interface for resolving the OSS bucket key for a given user/context |
| `LoggedInUserBucketKeyProvider.cs` | Resolves bucket key based on the logged-in user's account ID |
| `MigrationBucketKeyProvider.cs` | Resolves bucket key during data migration |
| `BucketPrefixProvider.cs` | Provides the prefix used when naming OSS buckets |
| `AdoptProjectWithParametersPayloadProvider.cs` | Builds the adoption payload when parameters are supplied upfront |
| `Exceptions/ProjectAlreadyExistsException.cs` | Exception thrown when trying to adopt a project that already exists |

---

## State/

Domain model classes representing the in-memory and OSS state of projects and users.

| File | Purpose |
|---|---|
| `Project.cs` | Represents one project — holds its OSS object name paths and local cache paths |
| `ProjectStorage.cs` | Manages a project's data in both OSS and LocalCache — download, upload, delete, ensure-local logic |
| `OssBucket.cs` | Wrapper around an OSS bucket — provides typed get/put/delete methods for project files |
| `UserResolver.cs` | Resolves the current user's OSS bucket and project list from APS; creates per-user cache directories |
| `NewProjectModel.cs` | Represents an in-progress project upload (before adoption completes) |
| `Uploads.cs` | Tracks active file uploads to prevent duplicates |

---

## Utilities/

Small, focused helper classes used across the backend.

| File | Purpose |
|---|---|
| `LocalNameConverter.cs` | Maps project/hash combinations to their local file paths inside `LocalCache/` |
| `OSSObjectNameProvider.cs` | Maps project/hash combinations to their OSS object names |
| `DtoGenerator.cs` | Builds the `ProjectDTO` sent to the frontend — assembles URLs, thumbnails, parameter links |
| `ExtractedBomEx.cs` | Extension methods for working with the BOM data model |
| `Json.cs` | Helpers for serialising/deserialising JSON files on disk |
| `Crypto.cs` | SHA hash generation — used to compute parameter hashes for caching |
| `GuidGenerator.cs` | Generates deterministic GUIDs from strings |
| `Collections.cs` | General collection helper methods |
| `FileSystem.cs` | File and directory helper methods |
| `ForgeEx.cs` | APS API extension/helper methods |
| `Web.cs` | HTTP helper methods |
| `TempFile.cs` | RAII wrapper — creates a temp file and deletes it when disposed |
| `ResourceProvider.cs` | Resolves embedded resource paths |
| `ITaskUtil.cs` | Task/async utility helpers |
| `InviteOnlyChecker.cs` | Checks whether the application is running in invite-only mode |

---

## LocalCache/

Runtime folder — **not source code**. Created and managed by the application at runtime. See `LocalCache-explained.md` for full details.

```
LocalCache/
├── [UserHash]/[ProjectName]/[ParametersHash]/
│   ├── metadata.json, thumbnail.png, drawingsList.json, adopt-messages.json
│   └── SVF/bubble.json + viewer assets
└── Reports/
    └── [timestamp]_[workItemId].txt / .stats.json
```

---

## ClientApp/ — React Frontend

The React single-page application served by the ASP.NET Core backend in development mode.

### Root Config Files

| File | Purpose |
|---|---|
| `package.json` | npm dependencies and build scripts |
| `package-lock.json` | Locked dependency versions |
| `jsconfig.json` | JavaScript project settings for IDE support |
| `.eslintrc` | ESLint rules for code style enforcement |
| `.prettierrc` | Prettier formatting rules |
| `codecept.conf.js` | CodeceptJS configuration for end-to-end UI tests |
| `steps_file.js` | CodeceptJS custom step definitions |
| `steps.d.ts` | TypeScript type declarations for CodeceptJS steps |
| `teardown.js` | Cleanup logic run after the UI test suite completes |

### public/

Static assets served directly — not processed by webpack.

| File | Purpose |
|---|---|
| `index.html` | HTML shell into which the React app is mounted |
| `manifest.json` | Web app manifest (PWA metadata) |
| `favicon.ico` | Browser tab icon |
| `logo.png` / `logo-xs-white-BG.svg` | Application logo |
| `Assembly_icon.svg` | Icon for assembly-type projects |
| `Archive.svg` | Icon for archived/zip projects |
| `alert-24.svg` | Alert icon |
| `document-drawing-24.svg` | Drawing document icon |
| `file-spreadsheet-24.svg` | Spreadsheet/BOM icon |
| `products-and-services-24.svg` | Products icon |
| `bike.png` | Sample project image |
| `SampleDrawingPdf.pdf` | Sample drawing PDF for testing |

### src/ — Application Source

#### Root Files

| File | Purpose |
|---|---|
| `index.js` | React entry point — mounts `<App>` into the DOM, sets up Redux store |
| `App.js` | Root React component — handles routing and top-level layout |
| `App.test.js` | Smoke test for the root component |
| `app.css` | Global application styles |
| `JobManager.js` | Manages SignalR connection and dispatches job progress events to Redux |
| `Repository.js` | Thin API client — all HTTP calls to the backend (fetch wrappers for each endpoint) |

#### src/actions/

Redux action creators — each file corresponds to one domain of user interaction. Actions are dispatched to trigger state changes and API calls.

| File | Purpose |
|---|---|
| `projectListActions.js` | Load and refresh the project list |
| `uploadPackageActions.js` | Handle file upload and project adoption |
| `adoptWithParamsActions.js` | Adopt a project with an initial set of parameter values |
| `parametersActions.js` | Load parameters and submit parameter updates |
| `bomActions.js` | Load Bill of Materials data |
| `drawingsListActions.js` | Load the list of drawings for a project |
| `downloadActions.js` | Trigger downloads (drawings ZIP, PDF, RFA, SAT) |
| `deleteProjectActions.js` | Delete a project |
| `profileActions.js` | Load the logged-in user's profile |
| `uiFlagsActions.js` | Toggle UI state flags (modal open/close, tab selection, etc.) |
| `notificationActions.js` | Show and dismiss notification banners |
| `*.test.js` | Unit tests for each action creator |

#### src/components/

React UI components — each `.js` file is one component, paired with a `.css` for its styles and a `.test.js` for its unit tests.

| File(s) | Purpose |
|---|---|
| `toolbar.js/.css` | Top navigation bar — logo, project switcher, user details |
| `projectSwitcher.js/.css` | Dropdown for switching between loaded projects |
| `projectList.js/.css` | Sidebar list of all available projects |
| `userDetails.js/.css` | Displays logged-in user name and avatar |
| `uploadPackage.js/.css` | File picker and upload UI for adding a new project |
| `tabsContainer.js` / `tabs.css` | Tab bar — switches between Parameters, BOM, and Drawings panels |
| `parametersContainer.js/.css` | Panel showing all editable parameters; handles update submission |
| `parameter.js` | Single parameter input row (label, input, unit) |
| `bom.js/.css` / `bomUtils.js` | Bill of Materials table display |
| `drawingsContainer.js/.css` | Panel listing all drawings for the project |
| `drawing.js/.css` | Single drawing row with PDF/view actions |
| `forgeView.js/.css` | Embeds the APS 3D Model Viewer (SVF viewer) |
| `forgePdfView.js/.css` / `forgePdfViewExtension.js` | Embeds the APS PDF Viewer for drawing files |
| `downloads.js` | Downloads panel — links to generate RFA, drawings ZIP, etc. |
| `checkboxTable.js` / `checkboxTableHeader.js` / `checkboxTableRow.js` | Generic selectable table (used in BOM and drawings) |
| `creditCost.js` | Displays the FDA credit cost for an operation |
| `reportUrl.js` | Link to the FDA processing report log |
| `hyperlink.js` | Generic styled hyperlink component |
| `message.js/.css` | Adoption/validation message banner (info/warning/error) |
| `modalProgress.js/.css` | Modal dialog shown during long-running operations |
| `modalProgressUpload.js` | Modal shown specifically during file upload |
| `modalDownloadProgress.js` | Modal shown during file download generation |
| `modalFail.js/.css` | Modal shown when an operation fails |
| `modalUpdateFailed.js` | Modal shown when a parameter update fails |
| `deleteProject.js/.css` | Confirmation dialog for project deletion |
| `shared.js` | Shared component utility functions |
| `empty_state.svg` / `no-data.svg` / `next.svg` / `prev.svg` | Icons used within components |

#### src/reducers/

Redux reducers — each manages one slice of application state. Actions flow in; new state flows out.

| File | Purpose |
|---|---|
| `mainReducer.js` | Combines all reducers; holds top-level state (project list, active project, user) |
| `projectListReducers.js` | State for the list of available projects |
| `parametersReducer.js` | State for the current project's parameters |
| `updateParametersReducer.js` | State for the in-progress parameter update (dirty values, validation errors) |
| `bomReducer.js` | State for the Bill of Materials data |
| `uiFlagsReducer.js` | State for UI toggles (which modal is open, active tab, loading flags) |
| `uiFlagsTestStates.js` | Pre-built state fixtures used in UI flag tests |
| `notificationReducer.js` | State for notification banners |
| `profileReducer.js` | State for the logged-in user's profile |
| `*.test.js` | Unit tests for each reducer |

#### src/test/

Infrastructure for unit tests.

| File | Purpose |
|---|---|
| `custom-test-env.js` | Custom Jest environment — extends jsdom with missing browser APIs |
| `mockSignalR.js` | Mock SignalR client used in unit tests to simulate real-time job events |

#### src/ui-tests/

End-to-end browser tests using **CodeceptJS + Playwright**. These test the full application through the browser.

| File | Purpose |
|---|---|
| `elements_definition.js` | Shared CSS selectors and page element references used across all tests |
| `authentication_test.js` | Tests login/logout flow |
| `upload_IPT_test.js` | Tests uploading a single part file |
| `upload_select_test.js` | Tests the file picker and project selection |
| `upload_delete_test.js` | Tests deleting an uploaded project |
| `upload_fail_log_test.js` | Tests that upload failures show a report link |
| `embedded_adoption_test.js` | Tests adopting a project in embedded mode |
| `embedded_view_test.js` | Tests the embedded 3D viewer |
| `parameters_test.js` | Tests viewing and editing parameters |
| `iLogic_Parameters_test.js` | Tests iLogic form parameters |
| `update_params_test.js` | Tests submitting a parameter update |
| `update_failed_dialog_test.js` | Tests the update-failed error dialog |
| `parameter_notification_test.js` | Tests parameter change notifications |
| `tabs_test.js` | Tests tab switching (Parameters / BOM / Drawings) |
| `BOM_content_test.js` | Tests BOM data is displayed correctly |
| `drawing_test.js` | Tests the drawings list panel |
| `download_drawing_test.js` | Tests drawing file download |
| `downloads_test.js` | Tests the downloads panel (RFA, drawings ZIP) |
| `RFA_Link_test.js` | Tests the RFA download link |
| `viewer_test.js` | Tests the 3D model viewer loads correctly |
| `toolbar_test.js` | Tests toolbar elements (logo, user details) |
| `user_details_test.js` | Tests user profile display |
| `validate_report_link_test.js` | Tests that FDA report links are valid and accessible |
| `dataset/` | Sample Inventor files used as test inputs (`.ipt`, `.zip`) |

#### src/utils/

| File | Purpose |
|---|---|
| `conversion.js` | Unit conversion helpers for parameter display |
| `conversion.test.js` | Unit tests for conversion utilities |
