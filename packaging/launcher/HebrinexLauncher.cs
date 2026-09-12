using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using System.Web.Script.Serialization;

namespace Hebrinex.Packaging
{
    internal sealed class PayloadFile
    {
        public string path { get; set; }
        public string source_path { get; set; }
        public string @class { get; set; }
        public long size { get; set; }
        public string sha256 { get; set; }
    }

    internal sealed class PayloadFeatures
    {
        public bool core { get; set; }
        public bool mcp { get; set; }
    }

    internal sealed class PayloadManifest
    {
        public string schema { get; set; }
        public int schema_version { get; set; }
        public string harness_version { get; set; }
        public string runtime_api { get; set; }
        public string architecture { get; set; }
        public PayloadFeatures features { get; set; }
        public PayloadFile[] files { get; set; }
    }

    internal static class Program
    {
        private const int ExitOptionalFeatureMissing = 4;
        private const int ExitEngineMissing = 10;
        private const int ExitLaunchFailed = 11;
        private const int ExitIntegrityFailed = 12;

        private static int Main(string[] args)
        {
            try
            {
                string binRoot = Path.GetFullPath(AppDomain.CurrentDomain.BaseDirectory);
                DirectoryInfo bin = new DirectoryInfo(binRoot.TrimEnd(Path.DirectorySeparatorChar));
                if (bin.Parent == null)
                    return Fail(ExitIntegrityFailed, "PAYLOAD_INTEGRITY_FAILED", "launcher root is unavailable");

                string installRoot = bin.Parent.FullName;
                PayloadManifest manifest = VerifyPayload(installRoot);

                if (args.Length > 0 && string.Equals(args[0], "mcp", StringComparison.OrdinalIgnoreCase))
                {
                    if (manifest.features == null || !manifest.features.mcp)
                        return Fail(ExitOptionalFeatureMissing, "OPTIONAL_FEATURE_MISSING", "MCP has no verified redistributable Node runtime in this candidate");
                    return Fail(ExitOptionalFeatureMissing, "OPTIONAL_FEATURE_MISSING", "MCP payload is not enabled");
                }

                string powershell = Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.System),
                    "WindowsPowerShell", "v1.0", "powershell.exe");
                if (!File.Exists(powershell))
                    return Fail(ExitEngineMissing, "RUNTIME_ENGINE_MISSING", powershell);

                string cli = Path.Combine(installRoot, "scripts", "hebrinex-central.ps1");
                List<string> cliArgs = new List<string>();
                for (int i = 0; i < args.Length; i++)
                    cliArgs.Add(args[i]);
                if (cliArgs.Count == 0)
                    cliArgs.Add("help");

                string cliEnvelope = Convert.ToBase64String(Encoding.UTF8.GetBytes(cli));
                string rootEnvelope = Convert.ToBase64String(Encoding.UTF8.GetBytes(installRoot));
                StringBuilder wrapperBuilder = new StringBuilder();
                wrapperBuilder.Append("$ErrorActionPreference='Stop';$ProgressPreference='SilentlyContinue';");
                wrapperBuilder.Append("$utf8=New-Object System.Text.UTF8Encoding($false);");
                wrapperBuilder.Append("[Console]::OutputEncoding=$utf8;[Console]::InputEncoding=$utf8;");
                wrapperBuilder.Append("$cli=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('");
                wrapperBuilder.Append(cliEnvelope);
                wrapperBuilder.Append("'));$root=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('");
                wrapperBuilder.Append(rootEnvelope);
                wrapperBuilder.Append("'));$argv=@(");
                bool firstArgument = true;
                foreach (string cliArgument in cliArgs)
                {
                    if (!firstArgument)
                        wrapperBuilder.Append(',');
                    wrapperBuilder.Append("[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('");
                    wrapperBuilder.Append(Convert.ToBase64String(Encoding.UTF8.GetBytes(cliArgument)));
                    wrapperBuilder.Append("'))");
                    firstArgument = false;
                }
                wrapperBuilder.Append(");try{");
                wrapperBuilder.Append("$metadata=(Get-Command -Name $cli -CommandType ExternalScript).Parameters;");
                wrapperBuilder.Append("$bound=@{Command=$argv[0];InstallRoot=$root};$i=1;");
                wrapperBuilder.Append("while($i -lt $argv.Count){$token=[string]$argv[$i];");
                wrapperBuilder.Append("if($token -notmatch '^--?(.+)$'){throw 'UNKNOWN_ARGUMENT: '+$token};$name=$Matches[1];");
                wrapperBuilder.Append("if($name -ieq 'InstallRoot'){throw 'INSTALL_ROOT_RESERVED'};");
                wrapperBuilder.Append("if(-not $metadata.ContainsKey($name)){throw 'UNKNOWN_PARAMETER: '+$name};");
                wrapperBuilder.Append("if($bound.ContainsKey($name)){throw 'DUPLICATE_PARAMETER: '+$name};");
                wrapperBuilder.Append("if($metadata[$name].ParameterType -eq [Management.Automation.SwitchParameter]){$bound[$name]=$true;$i++}");
                wrapperBuilder.Append("else{if($i+1 -ge $argv.Count){throw 'MISSING_PARAMETER_VALUE: '+$name};$bound[$name]=[string]$argv[$i+1];$i+=2}};");
                wrapperBuilder.Append("& $cli @bound;if($null -eq $LASTEXITCODE){exit 0}else{exit $LASTEXITCODE}}");
                wrapperBuilder.Append("catch{[Console]::Error.WriteLine($_.Exception.Message);exit 11}");
                string wrapper = wrapperBuilder.ToString();
                string encodedWrapper = Convert.ToBase64String(Encoding.Unicode.GetBytes(wrapper));

                ProcessStartInfo start = new ProcessStartInfo();
                start.FileName = powershell;
                start.Arguments = JoinArguments(new[] {
                    "-NoLogo", "-NoProfile", "-NonInteractive", "-InputFormat", "Text", "-OutputFormat", "Text", "-ExecutionPolicy", "Bypass",
                    "-EncodedCommand", encodedWrapper
                });
                start.UseShellExecute = false;
                start.CreateNoWindow = true;
                start.RedirectStandardOutput = true;
                start.RedirectStandardError = true;
                start.StandardOutputEncoding = new UTF8Encoding(false);
                start.StandardErrorEncoding = new UTF8Encoding(false);
                Process child = Process.Start(start);
                if (child == null)
                    return Fail(ExitLaunchFailed, "LAUNCH_FAILED", "process did not start");
                child.OutputDataReceived += delegate(object sender, DataReceivedEventArgs eventArgs)
                {
                    if (eventArgs.Data != null)
                        Console.Out.WriteLine(eventArgs.Data);
                };
                child.ErrorDataReceived += delegate(object sender, DataReceivedEventArgs eventArgs)
                {
                    if (eventArgs.Data != null)
                        Console.Error.WriteLine(eventArgs.Data);
                };
                child.BeginOutputReadLine();
                child.BeginErrorReadLine();
                child.WaitForExit();
                child.WaitForExit();
                return child.ExitCode;
            }
            catch (InvalidDataException ex)
            {
                return Fail(ExitIntegrityFailed, "PAYLOAD_INTEGRITY_FAILED", ex.Message);
            }
            catch (Exception ex)
            {
                return Fail(ExitLaunchFailed, "LAUNCH_FAILED", ex.Message);
            }
        }

        private static PayloadManifest VerifyPayload(string installRoot)
        {
            string manifestPath = Path.Combine(installRoot, "payload-manifest.json");
            EnsureRegularPath(installRoot, manifestPath);
            PayloadManifest manifest;
            try
            {
                JavaScriptSerializer serializer = new JavaScriptSerializer();
                serializer.MaxJsonLength = 16 * 1024 * 1024;
                manifest = serializer.Deserialize<PayloadManifest>(File.ReadAllText(manifestPath, Encoding.UTF8));
            }
            catch (Exception ex)
            {
                throw new InvalidDataException("manifest parse failed: " + ex.Message);
            }

            if (manifest == null || manifest.schema != "hebrinex.payload_manifest" ||
                manifest.schema_version != 1 || manifest.architecture != "x64" ||
                manifest.features == null || !manifest.features.core || manifest.files == null)
                throw new InvalidDataException("manifest identity is invalid");

            HashSet<string> seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            HashSet<string> required = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
            {
                "HARNESS_VERSION",
                "SHARED_MANIFEST.yaml",
                "scripts/hebrinex-central.ps1",
                "packaging/runtime-layout.json",
                "release.json",
                "bin/hebrinex.exe"
            };

            foreach (PayloadFile entry in manifest.files)
            {
                if (entry == null || !IsSafeRelativePath(entry.path) ||
                    string.IsNullOrEmpty(entry.sha256) || entry.sha256.Length != 64 || entry.size < 0 ||
                    (entry.@class != "product" && entry.@class != "template" && entry.@class != "generated"))
                    throw new InvalidDataException("manifest contains an invalid file entry");
                if (!seen.Add(entry.path))
                    throw new InvalidDataException("manifest contains a duplicate path: " + entry.path);

                string fullPath = Path.GetFullPath(Path.Combine(installRoot, entry.path.Replace('/', Path.DirectorySeparatorChar)));
                EnsureContained(installRoot, fullPath);
                EnsureRegularPath(installRoot, fullPath);
                FileInfo file = new FileInfo(fullPath);
                if (file.Length != entry.size)
                    throw new InvalidDataException("size mismatch: " + entry.path);
                string actualHash = Sha256(fullPath);
                if (!string.Equals(actualHash, entry.sha256, StringComparison.Ordinal))
                    throw new InvalidDataException("hash mismatch: " + entry.path);
                required.Remove(entry.path);
            }

            if (required.Count != 0)
                throw new InvalidDataException("required payload file is not declared: " + string.Join(",", required));

            string version = File.ReadAllText(Path.Combine(installRoot, "HARNESS_VERSION"), Encoding.UTF8).Trim();
            if (!string.Equals(version, manifest.harness_version, StringComparison.Ordinal))
                throw new InvalidDataException("HARNESS_VERSION does not match the manifest");
            return manifest;
        }

        private static bool IsSafeRelativePath(string value)
        {
            if (string.IsNullOrWhiteSpace(value) || Path.IsPathRooted(value) || value.IndexOf('\\') >= 0)
                return false;
            string[] parts = value.Split('/');
            foreach (string part in parts)
                if (part.Length == 0 || part == "." || part == "..")
                    return false;
            return true;
        }

        private static void EnsureContained(string root, string candidate)
        {
            string prefix = Path.GetFullPath(root).TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar;
            if (!candidate.StartsWith(prefix, StringComparison.OrdinalIgnoreCase))
                throw new InvalidDataException("path escapes install root");
        }

        private static void EnsureRegularPath(string installRoot, string fullPath)
        {
            EnsureContained(installRoot, Path.GetFullPath(fullPath));
            if (!File.Exists(fullPath))
                throw new InvalidDataException("missing file: " + Path.GetFileName(fullPath));
            FileInfo current = new FileInfo(fullPath);
            if ((current.Attributes & FileAttributes.ReparsePoint) != 0)
                throw new InvalidDataException("reparse file is unsupported: " + current.Name);
            DirectoryInfo parent = current.Directory;
            string root = Path.GetFullPath(installRoot).TrimEnd(Path.DirectorySeparatorChar);
            while (parent != null && !string.Equals(parent.FullName.TrimEnd(Path.DirectorySeparatorChar), root, StringComparison.OrdinalIgnoreCase))
            {
                if ((parent.Attributes & FileAttributes.ReparsePoint) != 0)
                    throw new InvalidDataException("reparse directory is unsupported: " + parent.Name);
                parent = parent.Parent;
            }
        }

        private static string Sha256(string path)
        {
            using (SHA256 algorithm = SHA256.Create())
            using (FileStream stream = File.OpenRead(path))
            {
                byte[] hash = algorithm.ComputeHash(stream);
                StringBuilder text = new StringBuilder(64);
                foreach (byte value in hash)
                    text.Append(value.ToString("x2"));
                return text.ToString();
            }
        }

        private static string JoinArguments(IEnumerable<string> values)
        {
            StringBuilder result = new StringBuilder();
            foreach (string value in values)
            {
                if (result.Length != 0)
                    result.Append(' ');
                result.Append(QuoteArgument(value ?? string.Empty));
            }
            return result.ToString();
        }

        private static string QuoteArgument(string value)
        {
            if (value.Length != 0 && value.IndexOfAny(new[] { ' ', '\t', '\n', '\v', '"' }) < 0)
                return value;
            StringBuilder result = new StringBuilder();
            result.Append('"');
            int slashes = 0;
            foreach (char current in value)
            {
                if (current == '\\')
                {
                    slashes++;
                    continue;
                }
                if (current == '"')
                {
                    result.Append('\\', slashes * 2 + 1);
                    result.Append('"');
                    slashes = 0;
                    continue;
                }
                result.Append('\\', slashes);
                slashes = 0;
                result.Append(current);
            }
            result.Append('\\', slashes * 2);
            result.Append('"');
            return result.ToString();
        }

        private static int Fail(int exitCode, string reason, string detail)
        {
            Console.Error.WriteLine("reason=" + reason);
            Console.Error.WriteLine("detail=" + detail);
            return exitCode;
        }
    }
}
