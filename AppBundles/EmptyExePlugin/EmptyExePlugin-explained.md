# EmptyExePlugin — Documentation

## What It Does

EmptyExePlugin is a **do-nothing console executable** used solely as a vehicle to transfer files between OSS buckets via Forge Design Automation. Because FDA work items must execute some program, this stub `.exe` satisfies that requirement while the real work — copying a file from a source URL to a target URL — is handled entirely by the FDA parameter system.

It is registered as the `TransferData` activity.

---

## Files

| File | Purpose |
|---|---|
| `EmptyExePlugin.cs` | Console executable with an empty `Main()` — does nothing |
| `EmptyExePlugin.csproj` | Build project — produces an `.exe` (not a DLL) |
| `PackageContents.xml` | Design Automation bundle definition |
| `WebApplication/Processing/TransferData.cs` | Web app side — registers the activity and maps source/target URLs |

The compiled bundle is:
```
WebApplication/AppBundles/EmptyExePlugin.bundle.zip
```

---

## How It Works

The plugin itself does nothing:
```csharp
static void Main(string[] args) { }
```

All the work is done by FDA's own parameter system:
- The activity defines an **input** parameter (`source`) mapped to a signed OSS GET URL
- The activity defines an **output** parameter (`target`) mapped to a signed OSS PUT URL
- Both parameters use the same local filename: `fileForTransfer`
- FDA downloads the file from the source URL, runs `EmptyExePlugin.exe` (which does nothing), then uploads `fileForTransfer` to the target URL

The net effect: a file is copied from one OSS location to another.

---

## Input and Output

### Input
| Parameter | Description |
|---|---|
| `source` | Signed OSS GET URL for the file to copy |

### Output
| Parameter | Description |
|---|---|
| `target` | Signed OSS PUT URL for the destination |

Both map to the same local filename `fileForTransfer` inside FDA's working directory.

---

## How It Is Invoked (FDA Activity)

```
"$(appbundles[TransferData].path)\EmptyExePlugin.bundle\Contents\EmptyExePlugin.exe"
```

Unlike the Inventor plugins, this is a plain `.exe` command — no `InventorCoreConsole.exe` wrapper is needed.

---

## Where It Fits in the Workflows

`TransferData` is not part of AdoptProject or UpdateProject. It is called by `ProjectWork.FileTransferAsync()` whenever a file needs to be duplicated within OSS — for example, when the same model needs to be available at a new hash path after a parameter update.

---

## Plugin Registration

| Property | Value |
|---|---|
| Output type | Console Executable (`.exe`) |
| Target Framework | .NET Framework 4.8 |
| FDA Activity ID | `TransferData` |
