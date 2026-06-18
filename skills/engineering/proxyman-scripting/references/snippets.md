# Proxyman Scripting — Snippet Reference

## HTTP Headers

```js
// Add/update
request.headers["X-Key"] = "value";
delete request.headers["X-Remove"];

response.headers["Content-Type"] = "application/json";
delete response.headers["X-Remove"];
```

## Request Query Params

```js
// Add/update
request.queries["name"] = "Proxyman";

// Delete
delete request.queries["name"];
```

## Change Request Destination

```js
request.scheme = "http";
request.host   = "localhost";
request.port   = 3000;
request.path   = "/v2/data";
request.method = "POST";
```

## Map Remote Patterns

```js
// Production → localhost
request.scheme = "http"; request.host = "localhost"; request.port = 3000;

// Localhost → production
request.scheme = "https"; request.host = "api.example.com"; request.port = 443;

// v1 → v2 path rewrite
request.path = request.path.replace("v1", "v2");
```

## JSON Body

```js
// Request
var body = request.body;        // JS Object when Content-Type: application/json
body["key"] = "value";
request.body = body;

// Response
var body = response.body;
body["key"] = "value";
response.body = body;
```

## URL-Encoded Form Body

```js
var form = request.body;        // JS Object when Content-Type: application/x-www-form-urlencoded
form["key"] = "value";
delete form["remove"];
request.body = form;
```

## Multipart/form-data (macOS 6.6.0+)

```js
function onRequest(context, url, request) {
  if (!request.multipart) return request;
  var parts = request.multipart;

  // Modify a text part
  for (var i = 0; i < parts.length; i++) {
    if (parts[i].name === "text_field") {
      parts[i].body = "updated";
    }
  }

  // Add a new part
  parts.push({ name: "new_field", body: "value" });

  // Remove a part
  parts = parts.filter(p => p.name !== "remove_me");

  request.multipart = parts;
  return request;
}
```

## Map Local File as Body (2.25.0+)

```js
request.bodyFilePath  = "~/Desktop/data.json";
response.bodyFilePath = "~/Desktop/mock.json";
```

## Mock API (run as Mock API mode)

```js
function onResponse(context, url, request, response) {
  response.headers["Content-Type"] = "application/json";
  response.body = { status: "ok", data: [] };
  return response;
}
```

## Multiple Mock Files by URL

```js
const file_v1 = require("@users/mock_v1.json");
const file_v2 = require("@users/mock_v2.json");

function onResponse(context, url, request, response) {
  response.headers["Content-Type"] = "application/json";
  if (url.includes("v1/data"))      response.body = file_v1;
  else if (url.includes("v2/data")) response.body = file_v2;
  return response;
}
```

## Import Files

```js
// JSON (via Import Tool → stored in @users)
const file = require("@users/myfile.json");

// Direct path (2.24.0+)
const file = require("~/Desktop/myfile.json");

// Binary / image
const img = require("@users/screenshot.png");
response.headers["Content-Type"] = "image/png";
response.body = img;

// Text-based (CSS, HTML, JS)
const css = require("@users/main.css");
response.headers["Content-Type"] = "text/css";
response.body = css;
```

## File I/O (macOS 5.4.0+)

```js
// Write (override)
writeToFile(response.body, "~/Desktop/body.json");

// Write (append, 3.6.2+)
writeToFile(response.body, "~/Desktop/log.json", { appendFile: true });

// Check exists
if (isFileExists("~/Desktop/myfile.json")) { ... }

// Read
const text = readFromFile("~/Desktop/myfile.json");     // String for text files
const bin  = readFromFile("~/Desktop/image.png");       // Uint8Array for binary
const obj  = JSON.parse(text);
```

## Abort (Block List behaviour, 3.11.0+)

```js
function onRequest(context, url, request) {
  if (someCondition) { abort(); return; }
  return request;
}
```

## Response Status Code

```js
response.statusCode = 404;
```

## Comment & Colour

```js
request.comment = "Debug flag";
request.color   = "red";   // red, blue, yellow, purple, gray, green

response.comment = "Mocked";
response.color   = "yellow";
```

## CORS Bypass

```js
function onResponse(context, url, request, response) {
  response.headers["Access-Control-Allow-Origin"]  = "*";
  response.headers["Access-Control-Allow-Headers"] = "*";
  response.headers["Access-Control-Allow-Methods"] = "*";
  return response;
}
```

## Sleep / Delay

```js
// macOS
sleep(5000);

// Windows/Linux
await sleep(5000);
```

## URL / URLSearchParams (4.13.0+)

```js
const u = new URL("https://api.example.com/v1?id=123");
console.log(u.hostname, u.pathname, u.searchParams.get("id"));
```

## ArrayBuffer / Uint8Array body

```js
const { btoa } = require("@addons/Base64.js");
const buffer = new ArrayBuffer(256);
const view   = new Uint8Array(buffer);
for (let i = 0; i < view.length; i++) view[i] = i;
response.body = btoa(String.fromCharCode.apply(null, view));
response.headers["Content-Type"] = "application/octet-stream";
```

## GraphQL — Map Local by Query Name

```js
const file = require("@users/user_response.json");

function onRequest(context, url, request) {
  sharedState.queryName = request.body.query.match(/\S+/gi)[1].split("(").shift();
  return request;
}

function onResponse(context, url, request, response) {
  if (sharedState.queryName === "user") {
    response.headers["Content-Type"] = "application/json";
    response.body = file;
  }
  return response;
}
```

## Websocket (macOS 6.2.0+, headers/URL only)

```js
// Redirect WS to production
request.scheme = "wss";
request.host   = "ws.api.example.com";
request.port   = 443;
```

## Regex — URL Parts

```js
const regex = /^(https?):\/\/([^:\/\n]+)(?::(\d+))?([^#\n?]+)(?:\?([^#\n]+))?/;
const [, scheme, host, port, path, query] = url.match(regex);
```
