using System.Security.Cryptography;
using System.Text;
using Konscious.Security.Cryptography;

namespace VC.Common.Security;

public sealed class PasswordHashOptions
{
    public const string Section = "PasswordHash";

    /// <summary>Speicher in KiB. Standard 64 MiB.</summary>
    public int MemoryKiB { get; set; } = 65536;
    public int Iterations { get; set; } = 3;
    public int Parallelism { get; set; } = 1;
}

/// <summary>
/// Argon2id im PHC-Format: <c>$argon2id$v=19$m=65536,t=3,p=1$salt$hash</c>.
/// Die Parameter stehen im Hash, damit spätere Erhöhungen alte Hashes nicht ungültig machen.
/// </summary>
public sealed class PasswordHasher(PasswordHashOptions options)
{
    private const int SaltBytes = 16;
    private const int HashBytes = 32;
    private const string Prefix = "$argon2id$v=19$";

    private readonly Lazy<string> _dummyHash = new(() => new PasswordHasher(options).Hash("dummy-password-for-timing"));

    public string Hash(string password)
    {
        var salt = RandomNumberGenerator.GetBytes(SaltBytes);
        var hash = Derive(password, salt, options.MemoryKiB, options.Iterations, options.Parallelism, HashBytes);
        return $"{Prefix}m={options.MemoryKiB},t={options.Iterations},p={options.Parallelism}$"
            + $"{ToB64(salt)}${ToB64(hash)}";
    }

    public static bool Verify(string password, string encoded)
    {
        if (!TryParse(encoded, out var parameters, out var salt, out var expected))
        {
            return false;
        }
        var actual = Derive(password, salt, parameters.MemoryKiB, parameters.Iterations, parameters.Parallelism, expected.Length);
        return CryptographicOperations.FixedTimeEquals(actual, expected);
    }

    /// <summary>Gleicher Rechenaufwand wie eine echte Prüfung, damit unbekannte Logins nicht am Timing erkennbar sind.</summary>
    public void VerifyDummy(string password) => Verify(password, _dummyHash.Value);

    public bool NeedsRehash(string encoded) =>
        !TryParse(encoded, out var p, out _, out _)
        || p.MemoryKiB != options.MemoryKiB || p.Iterations != options.Iterations || p.Parallelism != options.Parallelism;

    private static byte[] Derive(string password, byte[] salt, int memoryKiB, int iterations, int parallelism, int length)
    {
        using var argon2 = new Argon2id(Encoding.UTF8.GetBytes(password))
        {
            Salt = salt,
            MemorySize = memoryKiB,
            Iterations = iterations,
            DegreeOfParallelism = parallelism,
        };
        return argon2.GetBytes(length);
    }

    private static bool TryParse(string encoded, out PasswordHashOptions parameters, out byte[] salt, out byte[] hash)
    {
        parameters = new PasswordHashOptions();
        salt = [];
        hash = [];
        if (!encoded.StartsWith(Prefix, StringComparison.Ordinal))
        {
            return false;
        }
        var parts = encoded[Prefix.Length..].Split('$');
        if (parts.Length != 3)
        {
            return false;
        }
        foreach (var kv in parts[0].Split(','))
        {
            var pair = kv.Split('=');
            if (pair.Length != 2 || !int.TryParse(pair[1], out var value) || value <= 0)
            {
                return false;
            }
            switch (pair[0])
            {
                case "m": parameters.MemoryKiB = value; break;
                case "t": parameters.Iterations = value; break;
                case "p": parameters.Parallelism = value; break;
                default: return false;
            }
        }
        try
        {
            salt = FromB64(parts[1]);
            hash = FromB64(parts[2]);
        }
        catch (FormatException)
        {
            return false;
        }
        return salt.Length > 0 && hash.Length > 0;
    }

    private static string ToB64(byte[] data) => Convert.ToBase64String(data).TrimEnd('=');

    private static byte[] FromB64(string data) =>
        Convert.FromBase64String(data.PadRight(data.Length + ((4 - (data.Length % 4)) % 4), '='));
}
