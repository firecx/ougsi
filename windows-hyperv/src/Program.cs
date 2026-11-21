using System.ComponentModel;
using System.Text;
using System.Text.Json;

namespace Ougsi.HyperV;

internal static class Program
{
    private const string Usage = "Команды: check | create <путь к JSON>";

    internal static async Task<int> Main(string[] args)
    {
        Console.OutputEncoding = new UTF8Encoding(false);
        if (args is ["--help"] or ["-h"])
        {
            Console.WriteLine(Usage);
            return 0;
        }

        if (args is not (["check"] or ["create", _]))
        {
            Console.Error.WriteLine(Usage);
            return 2;
        }

        try
        {
            if (!OperatingSystem.IsWindows())
            {
                throw new InvalidOperationException("Для запуска модуля Hyper-V нужна Windows.");
            }

            object request = args is ["create", var path]
                ? VmConfiguration.Parse(await File.ReadAllTextAsync(path))
                : new { operation = "check" };

            Console.WriteLine(await HyperVHost.ExecuteAsync(request));
            return 0;
        }
        catch (Exception error) when (error is ArgumentException or IOException or UnauthorizedAccessException
            or JsonException or InvalidOperationException or NotSupportedException or Win32Exception)
        {
            Console.Error.WriteLine(error.Message);
            return 1;
        }
    }
}
