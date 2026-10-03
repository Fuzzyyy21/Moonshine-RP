using VC.Auth;

var builder = WebApplication.CreateBuilder(args);
AuthApp.ConfigureServices(builder);
var app = builder.Build();
AuthApp.Configure(app);
await app.RunAsync();
