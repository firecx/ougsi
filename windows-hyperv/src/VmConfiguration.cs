using System.Text.Json;
using System.Text.Json.Serialization;

namespace Ougsi.HyperV;

internal static class VmConfiguration
{
    private const long Mebibyte = 1024 * 1024;
    private const long Gibibyte = 1024 * Mebibyte;
    private static readonly JsonSerializerOptions FileOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        UnmappedMemberHandling = JsonUnmappedMemberHandling.Disallow,
        AllowDuplicateProperties = false,
    };

    internal static HyperVRequest Parse(string json)
    {
        var config = JsonSerializer.Deserialize<VmOptions>(json, FileOptions)
            ?? throw new ArgumentException("Конфигурация ВМ должна быть объектом JSON.");

        var name = ValidateName(config.Name);
        var storageRoot = LocalPath(config.StorageRoot, "storageRoot");
        if ((config.IsoPath is null) == (config.SourceVhdxPath is null))
        {
            throw new ArgumentException("Укажите ровно одно поле: isoPath или sourceVhdxPath.");
        }

        var isoPath = config.IsoPath is null ? null : LocalPath(config.IsoPath, "isoPath", ".iso");
        var sourceVhdxPath = config.SourceVhdxPath is null
            ? null : LocalPath(config.SourceVhdxPath, "sourceVhdxPath", ".vhdx");
        if (sourceVhdxPath is not null && config.DiskGiB is not null)
        {
            throw new ArgumentException("Поле diskGiB применяется только к новой ВМ из ISO.");
        }

        if (config.SwitchName is not null && string.IsNullOrWhiteSpace(config.SwitchName))
        {
            throw new ArgumentException("Имя виртуального коммутатора switchName не может быть пустым.");
        }

        if (config.SecureBootTemplate is not (null or "MicrosoftWindows" or "MicrosoftUEFICertificateAuthority"))
        {
            throw new ArgumentException("В secureBootTemplate укажите MicrosoftWindows или MicrosoftUEFICertificateAuthority.");
        }

        return new HyperVRequest(
            Operation: "create",
            Name: name,
            CpuCount: InRange(config.Vcpus, 1, 64, "vcpus"),
            MemoryBytes: InRange(config.MemoryMiB, 512, 1_048_576, "memoryMiB") * Mebibyte,
            DiskBytes: isoPath is null ? 0 : InRange(config.DiskGiB ?? 32, 1, 65_536, "diskGiB") * Gibibyte,
            SwitchName: config.SwitchName,
            IsoPath: isoPath,
            SourceVhdxPath: sourceVhdxPath,
            StorageRoot: storageRoot,
            NestedVirtualization: config.NestedVirtualization,
            SecureBootTemplate: config.SecureBootTemplate,
            Start: config.Start);
    }

    private static string ValidateName(string? name)
    {
        if (name is null || name.Length is < 1 or > 63 || !char.IsAsciiLetterOrDigit(name[0])
            || name.Any(character => !char.IsAsciiLetterOrDigit(character) && character is not ('-' or '_')))
        {
            throw new ArgumentException("Имя ВМ должно начинаться с латинской буквы или цифры и содержать до 63 латинских букв, цифр, дефисов или подчёркиваний.");
        }

        var upperName = name.ToUpperInvariant();
        if (upperName is "CON" or "PRN" or "AUX" or "NUL"
            || upperName.Length == 4 && upperName[3] is >= '1' and <= '9'
                && upperName[..3] is ("COM" or "LPT"))
        {
            throw new ArgumentException("Имя ВМ зарезервировано Windows.");
        }

        return name;
    }

    private static string LocalPath(string? value, string field, string? extension = null)
    {
        if (value is null || value.Length < 3 || !char.IsAsciiLetter(value[0]) || value[1] != ':'
            || value[2] is not ('\\' or '/') || value.IndexOfAny([':', '"', '<', '>', '|', '*', '?'], 2) >= 0
            || value.Any(char.IsControl))
        {
            throw new ArgumentException($"В {field} укажите абсолютный путь на локальном диске Windows.");
        }

        var path = Path.GetFullPath(value);
        if (extension is not null && !string.Equals(Path.GetExtension(path), extension, StringComparison.OrdinalIgnoreCase))
        {
            throw new ArgumentException($"Файл в {field} должен иметь расширение {extension}.");
        }

        return path;
    }

    private static int InRange(int value, int min, int max, string field)
    {
        return value >= min && value <= max
            ? value : throw new ArgumentException($"Значение {field} должно быть от {min} до {max}.");
    }

    private sealed record VmOptions
    {
        public string? Name { get; init; }
        public string? StorageRoot { get; init; }
        public string? IsoPath { get; init; }
        public string? SourceVhdxPath { get; init; }
        public int Vcpus { get; init; } = 2;
        public int MemoryMiB { get; init; } = 4096;
        public int? DiskGiB { get; init; }
        public string? SwitchName { get; init; }
        public bool NestedVirtualization { get; init; }
        public string? SecureBootTemplate { get; init; }
        public bool Start { get; init; } = true;
    }
}

internal sealed record HyperVRequest(
    string Operation,
    string Name,
    int CpuCount,
    long MemoryBytes,
    long DiskBytes,
    string? SwitchName,
    string? IsoPath,
    string? SourceVhdxPath,
    string StorageRoot,
    bool NestedVirtualization,
    string? SecureBootTemplate,
    bool Start);
