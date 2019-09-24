# dart\_up
Documentation coming soon.

Web application container for Dart servers, akin to PM/2 (Node.js).
Runs applications in isolates in the same VM, with `.packages` files
used to provide dependencies.

## Usage
After installing `dart_up` on your server, deploying a Dart app
is as simple as running `dart_up push <file>`, which creates an
app snapshot, and pushes that, along with your `pubspec.yaml`, to the
`dart_up` daemon. Your application will be spawned in a new isolate,
and auto-restarted on crashes/errors.
