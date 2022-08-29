using System.Diagnostics;
using System.Reflection;
using Microsoft.AspNetCore.Mvc;

namespace BlogBackend.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class CheckController : ControllerBase
    {
        [HttpGet(Name = "GetVersion")]
        public string? Get()
        {
            return FileVersionInfo.GetVersionInfo(Assembly.GetExecutingAssembly().Location).ProductVersion;
        }
    }
}
