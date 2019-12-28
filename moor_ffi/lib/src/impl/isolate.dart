part of 'database.dart';

// Support for running potentially long running sqlite operations in another Isolate (thread)

// Aglomeration of arguments for all possible sqlite operations
// sqlite specific arguments are passed in as Pointer addresses, and
// dereferenced in the isolate prior to invoking sqlite. This allows for
// efficient message passing from the main isolate.
class Arguments {
  Operation operation;
  SendPort sender;

  int dbOut; // Pointer<types.Database>
  int sqlPtr; // Pointer<types.Database>
  int stmtOut; // Pointer<Pointer<types.Statement>>
  int statement; // Pointer<types.Statement>
  int errorOut; // Pointer<Pointer<CBlob>>

  Arguments(this.operation,
      {this.sender,
      this.dbOut,
      this.sqlPtr,
      this.errorOut,
      this.statement,
      this.stmtOut});
}

// Supported operations to be run on isolate
enum Operation {sqlite3_prepare_v2, sqlite3_exec, sqlite3_step}

class DatabaseIsolate {
  Isolate _isolate;
  SendPort _sendPort;
  bool _isInitialized = false;

  // Ensure the isolate is initialized
  Future<void> _ensureIsolateInitialized() async {
    if (_isInitialized) {
      return;
    }
    final recvPort = ReceivePort();
    _isolate = await Isolate.spawn(_isolateCallback, recvPort.sendPort);

    _sendPort = (await recvPort.first) as SendPort;

    _isInitialized = true;
  }

  // Helper method to execute the isolate.
// Accepts an [Arguments] object, returns the result code (in a future)
  Future<int> run(Arguments args) async {
    if (!_isInitialized) {
      await _ensureIsolateInitialized();
    }

    final port = ReceivePort();
    args.sender = port.sendPort;
    _sendPort.send(args);
    return (await port.first) as int;
  }

  // Kill the running isolate if needed
  void shutdown() {
    if (!_isInitialized) {
      return;
    }
    _isolate.kill(priority: Isolate.immediate);
    _isolate = null;
    _sendPort = null;
    _isInitialized = false;
  }
}

// Top-level Isolate callback. Accepts and sends send ports for communications.
// Then listens for [Arguments] to determine which sqlite function to
// invoke, and sends back the result code.
// Only 3 sqlite functions are implemented: sqlite3_prepare_v2, sqlite3_exec,
// and sqlite3_step. Since these could potentially take longer than 2 ms to
// complete.
void _isolateCallback(SendPort sendPort) {
  final recvPort = ReceivePort();
  sendPort.send(recvPort.sendPort);

  recvPort.listen((data) {
    final args = data as Arguments;
    var result = 0;
    switch (args.operation) {
      case Operation.sqlite3_prepare_v2:
        {
          result = bindings.sqlite3_prepare_v2(
              Pointer.fromAddress(args.dbOut),
              Pointer.fromAddress(args.sqlPtr),
              -1,
              Pointer.fromAddress(args.stmtOut),
              nullPtr());
          break;
        }
      case Operation.sqlite3_exec:
        {
          result = bindings.sqlite3_exec(
              Pointer.fromAddress(args.dbOut),
              Pointer.fromAddress(args.sqlPtr),
              nullPtr(),
              nullPtr(),
              Pointer.fromAddress(args.errorOut));
          break;
        }
      case Operation.sqlite3_step:
        {
          result = bindings.sqlite3_step(Pointer.fromAddress(args.statement));
          break;
        }
    }
    args.sender.send(result);
  });
}
