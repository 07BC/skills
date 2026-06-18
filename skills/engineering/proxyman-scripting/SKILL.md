---
name: proxyman-scripting
description: >
  Write and edit Proxyman JS scripts to intercept and modify HTTP/HTTPS requests and responses.
  Use when the user wants to: write a Proxyman script, modify request/response headers, body, URL, or status code,
  mock an API response, map a remote endpoint, inject auth tokens, redirect traffic, bypass CORS,
  use built-in addons (Base64, MD5, UUID, JWT, AES, GZip), read/write local files, use sharedState or
  environment variables, make outbound HTTP calls from a script, or install npm packages for use in Proxyman scripting.
  Triggers on: "write a Proxyman script", "intercept this request", "mock this API", "redirect production to localhost",
  "inject a header", "proxyman scripting", "onRequest", "onResponse", "Proxyman script".
---

# Proxyman Scripting

Proxyman scripts are JavaScript files with two optional exported functions. Always `return request` / `return response` at the end.

## Script Skeleton

```js
function onRequest(context, url, request) {
  // modify request here
  return request;
}

function onResponse(context, url, request, response) {
  // modify response here
  return response;
}
```

Use `async function` on both handlers when calling `await` inside (e.g. `$http`, `sleep`, file I/O).

## Request Object

```
{
  method:              String          // "GET", "POST", …
  scheme:              String          // "http" | "https"
  host:                String          // "api.example.com"
  port:                Int             // 443
  path:                String          // "/v1/users"
  queries:             { [key]: Any }  // query params
  headers:             { [key]: Any }  // request headers
  body:                Object|String|Uint8Array  // depends on Content-Type (see below)
  rawBody:             Readonly String|Uint8Array
  bodyFilePath:        String?         // set to map a local file as body (2.25.0+)
  preserveHostHeader:  Bool
  isURLEncoding:       Bool            // default true
  comment:             String?
  color:               String?         // "red"|"blue"|"yellow"|"purple"|"gray"|"green"
}
```

**`request.body` type by Content-Type:**
- `application/json` → JS Object
- `application/x-www-form-urlencoded` → JS Object
- text types (`text/html`, `application/js`, …) → String
- binary (`application/octet-stream`, `image/*`, …) → Uint8Array

If `body` is wrong type (bad Content-Type mismatch), use `rawBody` and parse manually.

## Response Object

```
{
  statusCode:   Int
  httpVersion:  String (readonly)
  statusPhrase: String (readonly)
  headers:      { [key]: Any }
  body:         Object|String|Uint8Array  // same Content-Type rules as request
  rawBody:      Readonly String|Uint8Array
  bodyFilePath: String?
  comment:      String?
  color:        String?
}
```

## Importing Addons and Files

```js
// Built-in addon
const { uuidv4 }                  = require("@addons/UUID.js");
const { btoa, atob }              = require("@addons/Base64.js");
const { md5 }                     = require("@addons/MD5.js");
const { jwtDecode }               = require("@addons/JWTDecode.js");
const { gzip, ungzip }            = require("@addons/Pako.js");
const { encryptAES, decryptAES }  = require("@addons/CryptoJS.js");

// User file (imported via More → Import, stored in @users)
const mock = require("@users/response.json");

// Direct path (2.24.0+)
const data = require("~/Desktop/data.json");

// Custom user addon
const { myFunc } = require("@users/MyAddon.js");
```

## Common Patterns (quick reference)

```js
// Add header
request.headers["X-Token"] = $ACCESS_TOKEN;

// Change destination (map production → localhost)
request.scheme = "http"; request.host = "localhost"; request.port = 3000;

// Modify JSON body
var body = response.body; body["flag"] = true; response.body = body;

// Mock response from file
response.bodyFilePath = "~/Desktop/mock.json";
response.headers["Content-Type"] = "application/json";

// Abort request
abort(); return;

// Share state between request/response
sharedState.userId = request.body["id"];
```

## Reference Files

Load these when the task needs detail beyond the quick reference above:

- **[snippets.md](references/snippets.md)** — full code examples for every common pattern (headers, body, map remote, file I/O, CORS, sleep, ArrayBuffer, GraphQL, WebSocket, regex, etc.)
- **[addons-and-libraries.md](references/addons-and-libraries.md)** — complete addon list with import syntax, custom addon authoring, npm package installation
- **[advanced.md](references/advanced.md)** — sharedState, environment variables, outbound `$http` / axios requests, context object schema, host/encoding flags

## Key Rules

- Always `return request` / `return response` — missing return drops the traffic.
- Use `async function` on both handlers when using `await`.
- `rawBody` is readonly; parse it manually if `body` has wrong type.
- `$http` outbound calls bypass Proxyman proxy and have a 10-second timeout.
- Addons folder is overwritten on updates — put custom addons in `@users`, not `@addons`.
- npm packages (6.10.0+) must be CommonJS-compatible; Node.js built-ins (`fs`, `path`, `crypto`) are not available.
