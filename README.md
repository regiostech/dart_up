# dart\_up
**For a managed/hosted solution (truly "serverless"), check out
https://dart-up.regios.dev!**

Web application container for Dart servers, akin to PM/2 (Node.js).
Runs applications in isolates in the same VM, with `.packages` files
used to provide dependencies. Also supports `lambdas`, which are lightweight
executables run on-demand (and kept alive for an amount of time), instead of
long-lived daemons.

`dart_up` is completely open-source, and aims to make Dart server deployment
much simpler. It's essentially a Dart-specific "serverless" container (except,
if you're self-hosting, you'll obviously need to provision a server).

## Installation
To install the standalone server:

```bash
$ pub global activate dart_up
```

# Usage
After installing `dart_up` on your server, deploying a Dart app
is as simple as running `dart_up push <file>`, which creates an
app snapshot, and pushes that, along with your `pubspec.yaml`, to the
`dart_up` daemon. Your application will be spawned in a new isolate,
and auto-restarted on crashes/errors.

### Create a Lambda

For example, consider the following `hello_lambda.dart`:

```dart
import 'dart:isolate';
import 'package:dart_up/lambda.dart';

main(_, SendPort sp) {
  return runLambda(
    sp, (req) => Response.text('Hello, lambda world!'));
}
```

Assuming you have a running `dart_up` daemon, all you need to
do is `push` an application snapshot:

```bash
$ dart_up push --name hello --lambda example/hello_lambda.dart
Building .dart_tool/dart_up/example/hello_lambda.dill... 2.8s
 • hello - dead
```

Lambdas are `dead` by default. To trigger a lambda, visit `/:name`:
```bash
$ curl http://localhost:2374/hello; echo
Hello, lambda world!
```

### Create a Daemon
If the `--lambda` flag is not passed, then a *daemon* will created.
The given application will be started immediately, and also
started whenever `dart_up` is rebooted. By default, when the
application exits (either with success, or an error), it will
be re-spawned. This functionality can be disabled by passing the
`--no-auto-restart` flag.

Consider this example:

```dart
import 'package:angel_framework/angel_framework.dart';
import 'package:angel_framework/http.dart';

main() async {
  var app = Angel(), http = AngelHttp(app);
  app.fallback((req, res) => 'Hello from dart_up!');
  await http.startServer('127.0.0.1', 3001);
  print('dart_up_example listening at ${http.uri}');
}
```

### Application Management
The following commands are available for `dart_up` management
(Note: this document may not be up-to-date, especially if new
commands are added in the codebase):

```
$ dart_up --help
Dart Web application container.

Usage: dart_up <command> [arguments]

Global options:
-h, --help    Print this usage information.

Available commands:
  help     Display help information for dart_up.
  kill     Kills a running application.
  list     Lists the status of all active applications within the dart_up instance.
  push     Builds an app snapshot, and pushes it to a dart_up server.
  remove   Kills, and removes an application from the list.
  serve    Launch an HTTP server that manages other Dart applications.
  start    Restarts a dead/inactive process.

Run "dart_up help <command>" for more information about a command.
```

`dart_up push example/my_server.dart` will cause `dart_up` to
manage an instance of this application, restarting it if it
ever crashes.

### Password Authentication
`dart_up` supports `bcrypt`-hashed passwords, and uses `Basic` authentication
to ensure that external clients have access to the daemon. `dart_up` can also
be configured to even required passwords for requests from `localhost`.

```bash
# Set a password. Obviously, be smart about file permissions. Even though
# the passwords are strongly-hashed, the *usernames* are plain text.
$ dart_up password my_username
✔ Password [hidden] ‥ ***********
Successfully edited file .dart_tool/dart_up/passwords.

# Always require Basic authentication, even for localhost.
# Otherwise, it'll only be required for external clients.
$ dart_up serve --require-password

# Disregard `x-forwarded-for` header, i.e. if you're not using nginx `proxy_pass`.
$ dart_up serve --require-password --no-x-forwarded-for

# Any so-called "client command," like `list`, `push`, etc., takes a `--basic-auth`/`-B` option.
# This way, you'll be prompted for a username and password.
$ dart_up list -B
✔ Username ‥ my_username
✔ Password [hidden] ‥ *****
 • hello - dead
```

# Deploying `dart_up`
You more than likely don't want the `dart_up` daemon to face
the Web. In fact, you might not even want it to be accessible
to other processes on the server (in which case you should
configure it for password authentication).

That being said, if the `dart_up` daemon goes down, then logically,
all of the applications it's running will become inaccessible.
Therefore, you should be sure that in the case `dart_up` dies,
it is immediately restarted. On Ubuntu, using `systemd` is the best
way to do this.

These instructions are pretty abstract, though, because how you
deploy `dart_up` is up to you. The simplest way is to just
have a single daemon, and trust all applications running in the
VM (i.e. if only your organization is using the server). In a
multi-tenant situation, though, running all clients' programs in
the same memory space is a recipe for disaster. A better solution
is to create users for each client, give each client one
separate `dart_up` process, and use Unix permissions to enforce
access control and security.