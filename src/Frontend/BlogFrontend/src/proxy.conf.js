const PROXY_CONFIG = [
  {
    context: [
      "/api/weatherforecast",
    ],
    target: "https://localhost:5001",
    secure: false
  }
]

module.exports = PROXY_CONFIG;
