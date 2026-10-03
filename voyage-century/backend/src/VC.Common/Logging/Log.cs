using System.Net;
using Microsoft.Extensions.Logging;

namespace VC.Common.Logging;

/// <summary>Quellgenerierte Log-Methoden der gemeinsamen Infrastruktur (keine Allokation, wenn das Level aus ist).</summary>
internal static partial class Log
{
    private static readonly Func<ILogger, string, string, IDisposable?> ServiceScope =
        LoggerMessage.DefineScope<string, string>("service={Service} server={Server}");

    private static readonly Func<ILogger, long, Guid, IDisposable?> SessionScope =
        LoggerMessage.DefineScope<long, Guid>("account={Account} session={Session}");

    public static IDisposable? BeginServiceScope(ILogger logger, string service, string server) => ServiceScope(logger, service, server);

    public static IDisposable? BeginSessionScope(ILogger logger, long accountId, Guid sessionId) => SessionScope(logger, accountId, sessionId);

    [LoggerMessage(EventId = 1000, Level = LogLevel.Information, Message = "HTTP {Method} {Path} -> {Status} in {ElapsedMs} ms")]
    public static partial void HttpRequest(ILogger logger, string method, string? path, int status, long elapsedMs);

    [LoggerMessage(EventId = 1001, Level = LogLevel.Warning, Message = "Interner Aufruf ohne gültigen Service-Key von {Ip} auf {Path}")]
    public static partial void InvalidServiceKey(ILogger logger, IPAddress? ip, string? path);
}
