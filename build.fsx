#r "paket:
nuget Fake.Core.Target
nuget Fake.Core.Process
nuget Fake.Core.Trace
nuget Fake.Net.Http //"

#load "./.fake/build.fsx/intellisense.fsx"

open System
open System.IO
open System.Security.Cryptography
open Fake.Core
open Fake.Core.TargetOperators
open Fake.IO
open Fake.IO.Globbing.Operators
open Fake.Net

let packerExe = "packer"
let isoDir = "iso"

// ISO Information
type IsoInfo = {
    Name: string
    Url: string
    Checksum: string
    FileName: string
}

let isoInfos = [
    { Name = "windows-10"
      Url = "https://software-static.download.prss.microsoft.com/dbazure/988969d5-f34g-4e03-ac9d-1f9786c66750/19045.2006.220908-0225.22h2_release_svc_refresh_CLIENTENTERPRISEEVAL_OEMRET_x64FRE_en-us.iso"
      Checksum = "ef7312733a9f5d7d51cfa04ac497671995674ca5e1058d5164d6028f0938d668"
      FileName = "windows_10.iso" }
    { Name = "windows-11"
      Url = "https://software-static.download.prss.microsoft.com/dbazure/888969d5-f34g-4e03-ac9d-1f9786c66749/26200.6584.250915-1905.25h2_ge_release_svc_refresh_CLIENTENTERPRISEEVAL_OEMRET_x64FRE_en-us.iso"
      Checksum = "a61adeab895ef5a4db436e0a7011c92a2ff17bb0357f58b13bbc4062e535e7b9"
      FileName = "windows_11.iso" }
    { Name = "windows-server-2025"
      Url = "https://software-static.download.prss.microsoft.com/dbazure/888969d5-f34g-4e03-ac9d-1f9786c66749/26100.1742.240906-0331.ge_release_svc_refresh_SERVER_EVAL_x64FRE_en-us.iso"
      Checksum = "d0ef4502e350e3c6c53c15b1b3020d38a5ded011bf04998e950720ac8579b23d"
      FileName = "windows_server_2025.iso" }
]

let getIsoInfo name =
    isoInfos |> List.find (fun i -> i.Name = name)

type Provider =
    | VirtualBox
    | VmWare

let args = Target.getArguments ()

let tryGetArgValue (prefix: string) (args: string seq) =
    args
    |> Seq.tryFind (fun arg -> arg.StartsWith prefix)
    |> Option.map (fun arg -> arg.Substring prefix.Length)

let provider =
    match args with
    | Some args' ->
        tryGetArgValue "--provider=" args'
        |> Option.bind (fun p ->
            match p.ToLower() with
            | "virtualbox" -> Some VirtualBox
            | "vmware" -> Some VmWare
            | _ -> None)
    | None -> None

let theme =
    match args with
    | Some args' -> tryGetArgValue "--theme=" args'
    | None -> None

let locale =
    match args with
    | Some args' -> tryGetArgValue "--locale=" args'
    | None -> None

let timezone =
    match args with
    | Some args' -> tryGetArgValue "--timezone=" args'
    | None -> None

// SHA256 hash computation
let computeSha256 (filePath: string) =
    use sha256 = SHA256.Create()
    use stream = File.OpenRead(filePath)
    let hash = sha256.ComputeHash(stream)
    BitConverter.ToString(hash).Replace("-", "").ToLowerInvariant()

// ISO download with hash verification
let downloadIso (info: IsoInfo) =
    if not (Directory.Exists isoDir) then
        Directory.CreateDirectory isoDir |> ignore

    let targetPath = Path.Combine(isoDir, info.FileName)

    if File.Exists(targetPath) then
        Trace.logfn "Checking hash for existing ISO %s..." info.FileName
        let existingHash = computeSha256 targetPath
        if existingHash.Equals(info.Checksum, StringComparison.OrdinalIgnoreCase) then
            Trace.logfn "ISO %s already exists with correct hash, skipping download." info.FileName
        else
            Trace.logfn "ISO %s exists but hash mismatch (expected: %s, got: %s). Re-downloading..." info.FileName info.Checksum existingHash
            File.Delete(targetPath)
            Trace.logfn "Downloading %s from %s..." info.FileName info.Url
            Http.downloadFile targetPath info.Url |> ignore
            Trace.logfn "Download complete. Verifying hash..."
            let newHash = computeSha256 targetPath
            if not (newHash.Equals(info.Checksum, StringComparison.OrdinalIgnoreCase)) then
                failwithf "Downloaded ISO hash mismatch! Expected: %s, Got: %s" info.Checksum newHash
            Trace.logfn "Hash verified successfully."
    else
        Trace.logfn "Downloading %s from %s..." info.FileName info.Url
        Http.downloadFile targetPath info.Url |> ignore
        Trace.logfn "Download complete. Verifying hash..."
        let newHash = computeSha256 targetPath
        if not (newHash.Equals(info.Checksum, StringComparison.OrdinalIgnoreCase)) then
            failwithf "Downloaded ISO hash mismatch! Expected: %s, Got: %s" info.Checksum newHash
        Trace.logfn "Hash verified successfully."

let validatePacker () =
    let result = CreateProcess.fromRawCommand packerExe [ "--version" ] |> Proc.run

    if result.ExitCode <> 0 then
        failwith "Packer not found or not working. Ensure it's in PATH."

let buildOne osName provider buildParallel =
    let varFile = sprintf "../%s/%s.pkrvars.hcl" osName osName

    Trace.logfn "Running packer init to install any needed plugins..."

    CreateProcess.fromRawCommand packerExe [ "init"; "." ]
    |> CreateProcess.withWorkingDirectory "common"
    |> CreateProcess.ensureExitCode
    |> Proc.run
    |> ignore

    Trace.logfn "Building %s..." osName

    let providerArgs =
        provider
        |> Option.map (function
            | VmWare -> "-only=vmware-iso.*"
            | VirtualBox -> "-only=virtualbox-iso.*")
        |> Option.defaultValue ""

    let variableArgs =
        [ theme |> Option.map (sprintf "-var=theme=%s")
          locale |> Option.map (sprintf "-var=locale=%s")
          timezone |> Option.map (sprintf "-var=timezone=%s") ]
        |> List.choose id

    let args =
        [ "build"
          sprintf "-var-file=%s" varFile
          providerArgs
          "-on-error=ask"
          "-force"
          if not buildParallel then "-parallel-builds=1"
          yield! variableArgs
          "." ]
        |> List.filter String.isNotNullOrEmpty

    let proc =
        CreateProcess.fromRawCommand packerExe args
        |> CreateProcess.withWorkingDirectory "common"
        |> CreateProcess.ensureExitCode

    proc |> Proc.run |> ignore
    Trace.logfn "%s built successfully!" osName

let package osName provider =
    let provider' =
        match provider with
        | VirtualBox -> "virtualbox"
        | VmWare -> "vmware"

    let outputDir = Path.Combine("build", osName, provider')
    if not (Directory.Exists outputDir) then
        Directory.CreateDirectory outputDir |> ignore<DirectoryInfo>

    let boxFile = Path.Combine("build", osName, provider', sprintf "%s-%s.box" osName provider')

    Trace.tracefn "Packaging %s for %s into %s..." outputDir provider' boxFile

    let metadata =
        sprintf
            """{
            "provider": "%s",
            "version": "1.0.0"
        }"""
            provider'

    File.WriteAllText(Path.Combine(outputDir, "metadata.json"), metadata)

    if File.Exists "vagrant/Vagrantfile.windows-template" then
        File.Copy("vagrant/Vagrantfile.windows-template", Path.Combine(outputDir, "Vagrantfile"), true)

    let args = [ "czvf"; boxFile; "-C"; outputDir; "." ]
    CreateProcess.fromRawCommand "tar" args |> Proc.run |> ignore

    Trace.tracefn "Vagrant box created: %s" boxFile

let packageOne osName =
  provider
  |> Option.map List.singleton
  |> Option.defaultValue [ VmWare; VirtualBox ]
  |> List.iter (package osName)

// Validation target
Target.create "validate" (fun _ ->
    validatePacker ()
    Trace.log "Packer validated.")

// ISO Download targets
Target.create "download-iso-win10" (fun _ -> downloadIso (getIsoInfo "windows-10"))
Target.create "download-iso-win11" (fun _ -> downloadIso (getIsoInfo "windows-11"))
Target.create "download-iso-server2025" (fun _ -> downloadIso (getIsoInfo "windows-server-2025"))
Target.create "download-all-isos" ignore

// Build targets in parallel, unless a specific provider is given
Target.create "build-win10" (fun _ -> buildOne "windows-10" provider provider.IsNone)
Target.create "build-win11" (fun _ -> buildOne "windows-11" provider provider.IsNone)
Target.create "build-server2025" (fun _ -> buildOne "windows-server-2025" provider provider.IsNone)

// Package targets
Target.create "package-win10" (fun _ -> packageOne "windows-10")
Target.create "package-win11" (fun _ -> packageOne "windows-11")
Target.create "package-server2025" (fun _ -> packageOne "windows-server-2025")

// Build all target
Target.create "all" (fun _ ->
    [ "windows-10"; "windows-11"; "windows-server-2025" ]
    |> List.iter (fun osName -> buildOne osName provider true))

Target.create "default" ignore

// Dependencies: ISO downloads
"download-iso-win10" ==> "download-all-isos"
"download-iso-win11" ==> "download-all-isos"
"download-iso-server2025" ==> "download-all-isos"

// Dependencies: validate before build
"validate" ==> "build-win10"
"validate" ==> "build-win11"
"validate" ==> "build-server2025"

// Dependencies: download ISO before build
"download-iso-win10" ==> "build-win10"
"download-iso-win11" ==> "build-win11"
"download-iso-server2025" ==> "build-server2025"

// Dependencies: build before package
"build-win10" ==> "package-win10"
"build-win11" ==> "package-win11"
// Clean target
Target.create "clean" (fun _ ->
  Trace.log "Cleaning temporary build files..."
  
  !! "build/**"
  ++ "**/packer_*-iso" // TODO: Fake doesn't pick these up. Fix them
  ++ "**/packer_*-iso"
  ++ "**/packer_cache/**"
  |> Shell.deleteDirs
  
  Trace.log "Clean complete.")

// Full clean target (clean + delete ISOs)
Target.create "full-clean" (fun _ ->
  Trace.log "Cleaning ISOs..."
  
  if Shell.testDir isoDir then
    Shell.deleteDir isoDir
  
  Trace.log "ISO cleanup complete.")

"clean" ==> "full-clean"

"build-win10" ==> "package-win10"
"build-win11" ==> "package-win11"
"build-server2025" ==> "package-server2025"

let target =
    match Environment.GetCommandLineArgs() |> Array.tryItem 2 with
    | Some t -> t
    | None -> "all"

Target.runOrDefaultWithArguments target
