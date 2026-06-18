# Proxyman Scripting — Advanced Reference

## SharedState

Global JS object persisted across `onRequest` / `onResponse` and across different scripts (Proxyman 2.25.0+). Cleared when Proxyman quits or `clearSharedState()` is called.

```js
function onRequest(context, url, request) {
  sharedState.token = request.headers["Authorization"];
  sharedState.count = (sharedState.count ?? 0) + 1;
  return request;
}

function onResponse(context, url, request, response) {
  console.log("token was", sharedState.token);
  console.log("call count", sharedState.count);
  clearSharedState(); // optional reset
  return response;
}
```

## Environment Variables (3.8.0+)

1. Define in `~/.zshrc` or `~/.bashrc`:
   ```sh
   export ACCESS_TOKEN=AAABBBCCC
   ```
2. In Proxyman: More → Environment Variables → Allow all scripts to read env.
3. Access in script with `$` prefix:
   ```js
   async function onRequest(context, url, request) {
     _reloadEnv(); // force reload latest changes (4.15.0+)
     request.headers["Authorization"] = "Bearer " + $ACCESS_TOKEN;
     return request;
   }
   ```

## Async/Await HTTP Requests — macOS (`$http`)

Use `async` on both handler functions when making outbound requests. Requests bypass the Proxyman proxy (won't appear in the traffic list). Timeout: 10 seconds.

```js
async function onResponse(context, url, request, response) {
  // GET
  const out = await $http.get("https://httpbin.proxyman.app/get?id=1");

  // POST JSON
  const out = await $http.post("https://httpbin.proxyman.app/post", {
    body: { user: "Proxyman" },
    headers: { "Content-Type": "application/json" }
  });

  // POST form
  const out = await $http.post("https://httpbin.proxyman.app/post", {
    body: { key1: "value1" },
    headers: { "Content-Type": "application/x-www-form-urlencoded" }
  });

  // PUT / DELETE
  const out = await $http.put("https://httpbin.proxyman.app/put", param);
  const out = await $http.delete("https://httpbin.proxyman.app/delete", param);

  // Output shape: { statusCode, headers, body }
  console.log(out.statusCode, out.body, out.headers);
  return response;
}
```

## Async/Await HTTP Requests — Windows/Linux (`axios`)

```js
async function onResponse(context, url, request, response) {
  try {
    const res = await axios.get("https://httpbin.proxyman.app/get?ID=1");
    console.log(res.data);
  } catch (err) {
    console.error(err);
  }
  return response;
}
```

## Context Object (readonly)

Available as first param in both handlers:

```js
{
  scriptName:        String,
  matchingRule:      String,
  matchingMethod:    String,
  isEnableOnRequest: Bool,
  isEnableOnResponse: Bool,
  filePath:          String,
  flow: {            // 2.16.0+
    id:              String,
    serverPort:      String,
    serverIpAddress: String,
    clientIpAddress: String,
    remoteDeviceName: String,
    remoteDeviceIP:  String,
    clientPort:      String,
    clientName:      String | null,
    clientPath:      String | null,
    mapRemoteOriginalURL: String | null
  }
}
```

## Preserve Host Header

```js
request.preserveHostHeader = true;
```

## URL Encoding

```js
// Default true — Proxyman URL-encodes the final URL
request.isURLEncoding = false; // disable if URL is already encoded
```
