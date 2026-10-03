using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using VC.Common.Logging;
using VC.Common.Sessions;

namespace VC.Common.Security;

/// <summary>Schützt interne Endpunkte: nur Zonen-Server mit gültigem <c>X-Service-Key</c>.</summary>
public sealed class ServiceKeyFilter(IOptions<ServiceKeyOptions> options, ILogger<ServiceKeyFilter> log) : IEndpointFilter
{
    public const string Header = "X-Service-Key";

    private readonly byte[][] _keys = options.Value.Keys.Select(Encoding.UTF8.GetBytes).ToArray();

    public async ValueTask<object?> InvokeAsync(EndpointFilterInvocationContext context, EndpointFilterDelegate next)
    {
        var http = context.HttpContext;
        var presented = Encoding.UTF8.GetBytes(http.Request.Headers[Header].ToString());
        var valid = false;
        foreach (var key in _keys)
        {
            // Alle Schlüssel prüfen, damit die Laufzeit nicht verrät, welcher passt.
            valid |= CryptographicOperations.FixedTimeEquals(presented, key);
        }
        if (!valid)
        {
            Log.InvalidServiceKey(log, http.Connection.RemoteIpAddress, http.Request.Path.Value);
            return Results.Problem(statusCode: StatusCodes.Status401Unauthorized, title: "Service-Key fehlt oder ist ungültig");
        }
        return await next(context);
    }
}

/// <summary>Verlangt <c>Authorization: Bearer &lt;ticket&gt;</c> und legt die Session in <see cref="HttpContext.Items"/> ab.</summary>
public sealed class SessionFilter(SessionStore sessions, ILogger<SessionFilter> log) : IEndpointFilter
{
    private const string ItemKey = "vc.session";

    public static SessionInfo Get(HttpContext http) =>
        (SessionInfo)(http.Items[ItemKey] ?? throw new InvalidOperationException("SessionFilter fehlt am Endpunkt"));

    public async ValueTask<object?> InvokeAsync(EndpointFilterInvocationContext context, EndpointFilterDelegate next)
    {
        var http = context.HttpContext;
        var header = http.Request.Headers.Authorization.ToString();
        const string scheme = "Bearer ";
        var session = header.StartsWith(scheme, StringComparison.OrdinalIgnoreCase)
            ? await sessions.ValidateAsync(header[scheme.Length..].Trim(), http.RequestAborted)
            : null;
        if (session is null)
        {
            return Results.Problem(statusCode: StatusCodes.Status401Unauthorized, title: "Ticket fehlt, ist abgelaufen oder widerrufen");
        }
        http.Items[ItemKey] = session;
        using (Log.BeginSessionScope(log, session.AccountId, session.SessionId))
        {
            return await next(context);
        }
    }
}
