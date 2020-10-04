import 'package:test/test.dart';
import 'package:postgrest/postgrest.dart';

void main() {
  var rootUrl = 'http://localhost:3000';
  var postgrest;

  setUp(() {
    postgrest = PostgrestClient(rootUrl);
  });

  test('basic select table', () async {
    var res = await postgrest.from('users').select().end();
    expect(res.body.length, 4);
  });

  test('stored procedure', () async {
    var res =
        await postgrest.rpc('get_status', {'name_param': 'supabot'}).end();
    expect(res.body, 'ONLINE');
  });

  test('custom headers', () async {
    var postgrest = PostgrestClient(rootUrl, {
      'headers': {'apikey': 'foo'}
    });
    expect(postgrest.from('users').select().headers['apikey'], 'foo');
  });

  test('auth', () async {
    postgrest = PostgrestClient(rootUrl).auth('foo');
    expect(postgrest.from('users').select().headers['Authorization'],
        'Bearer foo');
  });

  test('switch schema', () async {
    var postgrest = PostgrestClient(rootUrl, {'schema': 'personal'});
    var res = await postgrest.from('users').select().end();
    expect(res.body.length, 5);
  });

  test('on_conflict insert', () async {
    var res = await postgrest.from('users').insert(
        {'username': 'dragarcia', 'status': 'OFFLINE'},
        {'upsert': true, 'onConflict': 'username'}).end();
    expect(res.body[0]['status'], 'OFFLINE');
  });

  test('upsert', () async {
    var res = await postgrest.from('messages').insert(
        {'id': 3, 'message': 'foo', 'username': 'supabot', 'channel_id': 2},
        {'upsert': true}).end();
    //{id: 3, message: foo, username: supabot, channel_id: 2}
    expect(res.body[0]['id'], 3);

    var resMsg = await postgrest.from('messages').select().end();
    expect(resMsg.body.length, 3);
  });

  test('bulk insert', () async {
    var res = await postgrest.from('messages').insert([
      {'message': 'foo', 'username': 'supabot', 'channel_id': 2},
      {'message': 'foo', 'username': 'supabot', 'channel_id': 2},
    ]).end();
    expect(res.body.length, 2);
  });

  test('basic update', () async {
    await postgrest
        .from('messages')
        .update({'channel_id': 2})
        .eq('message', 'foo')
        .end();

    var resMsg = await postgrest
        .from('messages')
        .select()
        .filter('message', 'eq', 'foo')
        .end();
    resMsg.body.forEach((rec) => expect(rec['channel_id'], 2));
  });

  test('basic delete', () async {
    await postgrest.from('messages').delete().eq('message', 'foo').end();

    var resMsg = await postgrest
        .from('messages')
        .select()
        .filter('message', 'eq', 'foo')
        .end();
    expect(resMsg.body.length, 0);
  });

  test('missing table', () async {
    var res = await postgrest.from('missing_table').select().end();
    print(res.toJson());
    expect(res.error.code, '404');
  });

  test('connection error', () async {
    var postgrest = PostgrestClient('http://this.url.does.not.exist');
    var res = await postgrest.from('user').select().end();
    print(res.toJson());
    expect(res.error.code, 'SocketException');
  });
}
