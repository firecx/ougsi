using System.Diagnostics;
using System.Text;
using System.Text.Json;

namespace Ougsi.HyperV;

internal static class HyperVHost
{
    private static readonly JsonSerializerOptions WireOptions = new() { PropertyNamingPolicy = JsonNamingPolicy.CamelCase };

    internal static async Task<string> ExecuteAsync(object request)
    {
        var script = Path.Combine(AppContext.BaseDirectory, "HyperV.ps1");
        if (!File.Exists(script))
        {
            throw new FileNotFoundException("Не найден сценарий модуля HyperV.ps1.", script);
        }

        var windowsPowerShell = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System),
            "WindowsPowerShell", "v1.0", "powershell.exe");
        var utf8 = new UTF8Encoding(false);
        var processInfo = new ProcessStartInfo(windowsPowerShell)
        {
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardInput = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            StandardInputEncoding = utf8,
            StandardOutputEncoding = utf8,
            StandardErrorEncoding = utf8,
        };

        foreach (var argument in new[] { "-NoLogo", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "RemoteSigned", "-File", script })
        {
            processInfo.ArgumentList.Add(argument);
        }

        using var process = Process.Start(processInfo)
            ?? throw new InvalidOperationException("Не удалось запустить Windows PowerShell.");
        var outputTask = process.StandardOutput.ReadToEndAsync();
        var errorTask = process.StandardError.ReadToEndAsync();
        try
        {
            using var input = process.StandardInput;
            await input.WriteLineAsync(JsonSerializer.Serialize(request, WireOptions));
        }
        catch (IOException)
        {
            // PowerShell may exit before reading input. Use its diagnostic below.
        }

        await process.WaitForExitAsync();
        var output = (await outputTask).Trim();
        var error = (await errorTask).Trim();
        if (process.ExitCode != 0)
        {
            throw new InvalidOperationException(error.Length == 0
                ? $"Модуль Hyper-V завершился с кодом {process.ExitCode}." : error);
        }

        using var result = JsonDocument.Parse(output);
        if (result.RootElement.ValueKind != JsonValueKind.Object)
        {
            throw new InvalidOperationException("Модуль Hyper-V вернул некорректный результат.");
        }

        return output;
    }
}
