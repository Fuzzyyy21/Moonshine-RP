using VC.GameData;

var builder = WebApplication.CreateBuilder(args);
GameDataApp.ConfigureServices(builder);
var app = builder.Build();
GameDataApp.Configure(app);
await app.RunAsync();
