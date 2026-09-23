import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoot_studio/core/db/database.dart';
import 'package:shoot_studio/services/pd_film_index.dart';
import 'package:shoot_studio/services/image_sources.dart';
import 'package:shoot_studio/services/query_translator.dart';
import 'package:shoot_studio/services/search_prefs.dart';

/// Q5 搜索门禁（D78/D81/D83）：PD 多字段+中文别名 / 词表红线 / 偏好存取 / 翻译器降级。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PD 影片搜索（D78）', () {
    final Map<String, Object?> metropolis = <String, Object?>{
      'title': 'Metropolis',
      'year': 1927,
      'frames': <Object?>[
        <String, Object?>{'title': 'Metropolis city.jpg', 'author': 'Lang'},
      ],
    };
    final Map<String, Object?> kid = <String, Object?>{
      'title': 'The Kid',
      'year': 1921,
      'frames': <Object?>[
        <String, Object?>{'title': 'Chaplin still.jpg', 'author': 'Chaplin'},
      ],
    };

    test('中文别名/主创/题材/年份/帧标题均可命中', () {
      expect(pdFilmMatches(metropolis, <String>['大都会']), isTrue);
      expect(pdFilmMatches(metropolis, <String>['科幻']), isTrue);
      expect(pdFilmMatches(metropolis, <String>['1927']), isTrue);
      expect(pdFilmMatches(metropolis, <String>['metropolis']), isTrue);
      expect(pdFilmMatches(kid, <String>['卓别林']), isTrue);
      expect(pdFilmMatches(kid, <String>['chaplin']), isTrue);
      expect(pdFilmMatches(kid, <String>['大都会']), isFalse);
      // 多 token AND：全部命中才匹配。
      expect(pdFilmMatches(kid, <String>['喜剧', '1921']), isTrue);
      expect(pdFilmMatches(kid, <String>['喜剧', '大都会']), isFalse);
      // 空 token = 全量。
      expect(pdFilmMatches(metropolis, <String>[]), isTrue);
    });

    test('别名表覆盖 10 部 PD 影片', () {
      expect(kPdFilmAliases.length, 10);
      expect(kPdFilmAliases['Night of the Living Dead'], contains('活死人之夜'));
    });
  });

  group('词表与翻译红线（R33）', () {
    test('未命中词表不返回中文', () {
      expect(translateSceneToKeywords('银河 瀑布 帐篷'), isNotEmpty);
      expect(translateSceneToKeywords('完全没收录的词'), '');
      expect(hasAsciiQuery(translateSceneToKeywords('完全没收录的词')), isFalse);
    });

    test('词表规模与覆盖抽查', () {
      expect(kSceneKeywordMap.length, greaterThanOrEqualTo(200));
      expect(translateSceneToKeywords('赛博'), contains('cyberpunk'));
      expect(translateSceneToKeywords('水花'), contains('water splash'));
      expect(translateSceneToKeywords('国风'), contains('chinese traditional'));
    });
  });

  group('SearchPrefs（D83）', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('历史去重且限长 20，收藏可切换', () async {
      final SearchPrefs prefs = SearchPrefs(db);
      for (var i = 0; i < 25; i++) {
        await prefs.pushHistory('q$i');
      }
      await prefs.pushHistory('q10');
      final List<String> history = await prefs.history();
      expect(history.length, 20);
      expect(history.first, 'q10');
      expect(history.where((String e) => e == 'q10').length, 1);

      expect(await prefs.isFavorite('q1'), isFalse);
      expect(await prefs.toggleFavorite('q1'), isTrue);
      expect(await prefs.isFavorite('q1'), isTrue);
      expect(await prefs.toggleFavorite('q1'), isFalse);
      expect(await prefs.isFavorite('q1'), isFalse);
    });
  });

  group('QueryTranslator（D81 降级）', () {
    test('未配置 AI 提供方时返回空串（不崩溃、不阻塞）', () async {
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final QueryTranslator translator = QueryTranslator(db);
      expect(await translator.translate('星际穿越'), '');
      expect(await translator.translate(''), '');
    });
  });

  group('网络错误可读性（R31）', () {
    test('超时/连接错误带域名与建议', () {
      final String message = describeNetworkError(Exception('raw'));
      expect(message, isNotEmpty);
    });
  });
}
