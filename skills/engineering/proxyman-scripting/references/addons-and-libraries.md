# Proxyman — Addons & Libraries Reference

All addons are imported via `require("@addons/<Name>.js")`.

## Built-in Addons

| Addon | Import | Description |
|---|---|---|
| Base64.js | `const { atob, btoa } = require("@addons/Base64.js")` | Base64 encode/decode |
| MD5.js | `const { md5 } = require("@addons/MD5.js")` | MD5 hash |
| SHA1.js | `const { sha1 } = require("@addons/SHA1.js")` | SHA-1 hash |
| SHA256.js | `const { sha256 } = require("@addons/SHA256.js")` | SHA-256 hash |
| SHA512.js | `const { sha512 } = require("@addons/SHA512.js")` | SHA-512 hash |
| UUID.js | `const { uuidv4 } = require("@addons/UUID.js")` | Generate UUID v4 |
| Pako.js | `const { gzip, ungzip, deflate, inflate } = require("@addons/Pako.js")` | GZip / Deflate |
| CryptoJS.js | `const { encryptAES, decryptAES, encryptDES, decryptDES } = require("@addons/CryptoJS.js")` | AES / DES crypto |
| JWTDecode.js | `const { jwtDecode } = require("@addons/JWTDecode.js")` | Decode JWT |
| FormatJSON.js | `const { formatJSON } = require("@addons/FormatJSON.js")` | Beautify JSON string |
| BeautifyJSON.js | — | JSON obj → pretty string |
| UglifyJSON.js | — | JSON obj → minified string |
| FormatXML.js | — | Beautify XML |
| FormatCSS.js | — | Beautify CSS |
| MinifyCSS.js | — | Minify CSS |
| MinifyJSON.js | — | Minify JSON |
| MinifyXML.js | — | Minify XML |
| JsonToQuery.js | — | JSON obj → query string |
| QueryToJson.js | — | Query string → JSON obj |
| JSONValidator.js | — | Validate JSON string |
| DecodeURI.js | — | Percent-decode string |
| EncodeURI.js | — | Percent-encode string |
| CamelCase.js | — | Convert to camelCase |
| KebabCase.js | — | Convert to kebab-case |
| SnakeCase.js | — | Convert to snake_case |
| DateToTimestamp.js | — | Date string → timestamp |
| DateToUTC.js | — | Date string → UTC string |
| Hex2rgb.js | — | #000000 → RGB string |

> Addons folder is overwritten on Proxyman updates — never edit files there. Copy to `~/Library/Application Support/com.proxyman.NSProxy/users/` to customise.

## Built-in Libraries (lower-level)

Located at `~/Library/Application Support/com.proxyman.NSProxy/addons/libs/`.
Import with `require("@libs/<name>.js")`.

| Library | Description |
|---|---|
| base64.js | Basic Base64 encode/decode |
| atob.js / btoa.js | `window.atob` / `window.btoa` |
| hashes.js | MD5, RIPEMD-160, SHA1/256/512, HMAC |
| lodash.js | Text transforms and utilities |
| vkBeautify.js | Pretty-print/minify XML, JSON, CSS, SQL |
| crypto-js.min.js | DES, AES, Rabbit (CryptoJS v3.3.0) |

## Writing Custom Addons

1. Create `~/Library/Application Support/com.proxyman.NSProxy/users/MyAddon.js`
2. Use the metadata block and export your functions:

```js
/**
    {
        "name": "My Addon",
        "description": "Description",
        "author": "Jamie"
    }
**/

const { md5 } = require("@addons/MD5.js");

const myFunc = () => md5("hello");
exports.myFunc = myFunc;
```

3. Import in a script:

```js
const { myFunc } = require("@users/MyAddon.js");
```

## npm Packages (macOS 6.10.0+)

Install into Proxyman's Application Support folder — uses JavaScriptCore, **not** Node.js:

```sh
cd "$HOME/Library/Application Support/com.proxyman.NSProxy"
npm install --prefix . <package> --ignore-scripts --no-audit --no-fund
```

Then require by package name:

```js
const dayjs = require("dayjs");
```

**Supported**: pure-JS CommonJS packages (dayjs, lodash, validator, slugify, js-base64, he, …)  
**Not supported**: packages using `fs`, `path`, `crypto`, `http`, native `.node` add-ons, ESM-only packages.

Installed packages land in `~/Library/Application Support/com.proxyman.NSProxy/node_modules`.
