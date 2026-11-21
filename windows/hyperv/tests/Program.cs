using System.Text.Json;
using Ougsi.HyperV;

const string Name = """ "name":"kvm-lab_01" """;
const string Storage = """ "storageRoot":"D:\\VM Storage" """;
const string Iso = """ "isoPath":"D:\\Images\\linux.iso" """;
const string SourceVhdx = """ "sourceVhdxPath":"D:\\Images\\linux.vhdx" """;
const string IsoFields = $"{Name},{Storage},{Iso}";

var tests = new (string Name, Action Run)[]
{
    (nameof(UsesIsoDefaults), UsesIsoDefaults),
    (nameof(UsesExplicitIsoResourcesAndOptions), UsesExplicitIsoResourcesAndOptions),
    (nameof(AcceptsSourceVhdxWithoutProvisioningADisk), AcceptsSourceVhdxWithoutProvisioningADisk),
    (nameof(RejectsMissingAndConflictingBootMedia), RejectsMissingAndConflictingBootMedia),
    (nameof(RejectsInvalidVmNames), RejectsInvalidVmNames),
    (nameof(RejectsInvalidLocalPaths), RejectsInvalidLocalPaths),
    (nameof(RejectsOutOfRangeResourcesAndInvalidOptions), RejectsOutOfRangeResourcesAndInvalidOptions),
    (nameof(RejectsMalformedJsonAndInvalidFieldNamesOrTypes), RejectsMalformedJsonAndInvalidFieldNamesOrTypes)
};

var failures = 0;
foreach (var test in tests)
{
    try
    {
        test.Run();
        Console.WriteLine($"PASS {test.Name}");
    }
    catch (Exception error)
    {
        failures++;
        Console.Error.WriteLine($"FAIL {test.Name}: {error.Message}");
    }
}

return failures == 0 ? 0 : 1;

static void UsesIsoDefaults()
{
    var request = Parse(IsoFields);

    Equal("create", request.Operation);
    Equal("kvm-lab_01", request.Name);
    Equal(2, request.CpuCount);
    Equal(4096 * 1024L * 1024, request.MemoryBytes);
    Equal(32 * 1024L * 1024 * 1024, request.DiskBytes);
    Equal(@"D:\VM Storage", request.StorageRoot);
    Equal(@"D:\Images\linux.iso", request.IsoPath);
    Equal(null, request.SourceVhdxPath);
    Equal(null, request.SwitchName);
    Equal(null, request.SecureBootTemplate);
    Equal(false, request.NestedVirtualization);
    Equal(true, request.Start);
}

static void UsesExplicitIsoResourcesAndOptions()
{
    var request = Parse(IsoFields + """
        ,"vcpus":64,"memoryMiB":1048576,"diskGiB":65536,"switchName":"Lab Switch",
        "nestedVirtualization":true,"secureBootTemplate":"MicrosoftUEFICertificateAuthority","start":false
        """);

    Equal(64, request.CpuCount);
    Equal(1048576 * 1024L * 1024, request.MemoryBytes);
    Equal(65536 * 1024L * 1024 * 1024, request.DiskBytes);
    Equal("Lab Switch", request.SwitchName);
    Equal("MicrosoftUEFICertificateAuthority", request.SecureBootTemplate);
    Equal(true, request.NestedVirtualization);
    Equal(false, request.Start);

    request = Parse(IsoFields + ""","vcpus":1,"memoryMiB":512,"diskGiB":1""");
    Equal(1, request.CpuCount);
    Equal(512 * 1024L * 1024, request.MemoryBytes);
    Equal(1024L * 1024 * 1024, request.DiskBytes);
}

static void AcceptsSourceVhdxWithoutProvisioningADisk()
{
    var request = Parse($"{Name},{Storage},{SourceVhdx}," + """ "secureBootTemplate":"MicrosoftWindows" """);

    Equal(@"D:\Images\linux.vhdx", request.SourceVhdxPath);
    Equal(null, request.IsoPath);
    Equal(0L, request.DiskBytes);
    Equal("MicrosoftWindows", request.SecureBootTemplate);
}

static void RejectsMissingAndConflictingBootMedia()
{
    Reject<ArgumentException>($"{Name},{Storage}");
    Reject<ArgumentException>($"{IsoFields},{SourceVhdx}");
    Reject<ArgumentException>($"{Name},{Storage},{SourceVhdx}," + """ "diskGiB":32""");
}

static void RejectsInvalidVmNames()
{
    string[] invalidNames = ["", "-vm", "_vm", "vm name", "vm/name", "машина", "con", "Com1", new string('a', 64)];
    foreach (var invalidName in invalidNames)
    {
        Reject<ArgumentException>($"\"name\":{JsonSerializer.Serialize(invalidName)},{Storage},{Iso}");
    }
}

static void RejectsInvalidLocalPaths()
{
    Reject<ArgumentException>($"{Name},{Iso}," + """ "storageRoot":"images\\vm" """);
    Reject<ArgumentException>($"{Name},{Iso}," + """ "storageRoot":"D:vm" """);
    Reject<ArgumentException>($"{Name},{Iso}," + """ "storageRoot":"\\\\server\\share" """);
    Reject<ArgumentException>($"{Name},{Storage}," + """ "isoPath":"D:\\Images\\linux.img" """);
    Reject<ArgumentException>($"{Name},{Storage}," + """ "isoPath":"linux.iso" """);
    Reject<ArgumentException>($"{Name},{Storage}," + """ "isoPath":"\\\\server\\share\\linux.iso" """);
    Reject<ArgumentException>($"{Name},{Storage}," + """ "sourceVhdxPath":"D:\\Images\\linux.vhd" """);
}

static void RejectsOutOfRangeResourcesAndInvalidOptions()
{
    string[] invalidOptions =
    [
        """ "vcpus":0""", """ "vcpus":65""", """ "memoryMiB":511""", """ "memoryMiB":1048577""",
        """ "diskGiB":0""", """ "diskGiB":65537""", """ "switchName":"   " """,
        """ "secureBootTemplate":"UnsupportedTemplate" """
    ];
    foreach (var invalidOption in invalidOptions)
    {
        Reject<ArgumentException>($"{IsoFields},{invalidOption}");
    }
}

static void RejectsMalformedJsonAndInvalidFieldNamesOrTypes()
{
    Throws<JsonException>("{");
    Reject<JsonException>(IsoFields + ""","unknown":1""");
    Reject<JsonException>(IsoFields + ""","Vcpus":4""");
    Reject<JsonException>(IsoFields + ""","vcpus":1,"vcpus":2""");
    Reject<JsonException>(IsoFields + ""","vcpus":"4" """);
    Reject<JsonException>(IsoFields + ""","start":1""");
}

static HyperVRequest Parse(string fields) => VmConfiguration.Parse($"{{{fields}}}");

static void Reject<TException>(string fields) where TException : Exception => Throws<TException>($"{{{fields}}}");

static void Throws<TException>(string json) where TException : Exception
{
    try
    {
        VmConfiguration.Parse(json);
    }
    catch (TException)
    {
        return;
    }
    catch (Exception error)
    {
        throw new InvalidOperationException($"Expected {typeof(TException).Name} for {json}, got {error.GetType().Name}.", error);
    }

    throw new InvalidOperationException($"Expected {typeof(TException).Name} for {json}.");
}

static void Equal<T>(T expected, T actual)
{
    if (!EqualityComparer<T>.Default.Equals(expected, actual))
    {
        throw new InvalidOperationException($"Expected '{expected}', got '{actual}'.");
    }
}
