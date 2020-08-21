# Use libcurl Library

* Status: accepted
* Deciders: Nathan Fiedler
* Date: 2020-08-20

## Context

The authentication integration in Helix Core server is implemented using extensions. The library of functions available to extensions is limited to HTTP/S calls using `libcurl`, and not much else. For instance, parsing XML is not available without writing your own parser. As such, the heavy-lifting of the integration is handled by an external authentication service. To connect to this service, the extension would use HTTP/S.

## Decision

The only real option is to use `libcurl` to connect to the service from the extension. Other possibilities that were explored by the architect at the time included web sockets and public key cryptography. However, web sockets are complicated to build in Lua, and unnecessary when we can just use HTTP calls with client certificates. The use of SSL certificates also removes any benefit of public key cryptography, which is not available in Lua without building OpenSSL into the server.

## Consequence

The extension has been using `libcurl` since the beginning, and this has worked well for the most part. One minor issue with `libcurl` is that it tends to report errors rather poorly, so some errors are difficult to debug.
