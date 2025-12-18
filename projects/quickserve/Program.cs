var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

app.UseDefaultFiles();   // enables index.html if present
app.UseStaticFiles();    // serves files from wwwroot

// this is what is needed if serving to a docker build on your own machine.
// this will also require privileges 
app.Run("http://0.0.0.0:8675");

// this can only be hit on your machine
//app.Run("http://localhost:8675");

// use this if other machines on the LAN need access
//app.Run("http://<ip-address>:8675");
