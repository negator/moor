import 'package:moor/moor.dart';
import 'package:moor_ffi/database.dart';
import 'package:test/test.dart';


void main() {
  test('prepared statements can be used multiple times', () async {
    final opened = Database.memory();
    opened.execute('CREATE TABLE tbl (a TEXT);');

    final stmt = await opened.prepare('INSERT INTO tbl(a) VALUES(?)');
    stmt.execute(['a']);
    stmt.execute(['b']);
    stmt.close();

    final select = await opened.prepare('SELECT * FROM tbl ORDER BY a');
    final result = await select.select();

    expect(result, hasLength(2));
    expect(result.map((row) => row['a']), ['a', 'b']);

    select.close();

    opened.close();
  });

  test('prepared statements cannot be used after close', () async {
    final opened = Database.memory();

    final stmt = await opened.prepare('SELECT ?');
    stmt.close();

    expect(stmt.select, throwsA(anything));

    opened.close();
  });

  test('prepared statements cannot be used after db is closed', () async {
    final opened = Database.memory();
    final stmt = await opened.prepare('SELECT 1');
    opened.close();

    expect(stmt.select, throwsA(anything));
  });

  test('can bind empty blob in prepared statements', () async {
    final opened = Database.memory();
    await opened.execute('CREATE TABLE tbl (x BLOB NOT NULL);');

    final insert = await  opened.prepare('INSERT INTO tbl VALUES (?)');
    insert.execute([Uint8List(0)]);
    insert.close();

    final select = await opened.prepare('SELECT * FROM tbl');
    final result = (await select.select()).single;

    expect(result['x'], <int>[]);

    opened.close();
  }, skip: 'todo figure out why this still fails');
}
