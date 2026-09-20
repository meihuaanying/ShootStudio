import '../image_sources.dart' as legacy;
import 'pinyin_data.dart';

export 'pinyin_data.dart' show kPinyinDict;

/// 常见创作者/演员中文名 → 英文检索名（确定性词表，R46 优先于拼音）。
/// 覆盖用户高频检索的导演、演员与画家；AI 可用时仍可扩展任意人名。
const Map<String, String> kNameKeywordMap = <String, String>{
  // 导演
  '诺兰': 'christopher nolan',
  '克里斯托弗诺兰': 'christopher nolan',
  '斯皮尔伯格': 'steven spielberg',
  '卡梅隆': 'james cameron',
  '昆汀': 'quentin tarantino',
  '塔伦蒂诺': 'quentin tarantino',
  '宫崎骏': 'hayao miyazaki',
  '新海诚': 'makoto shinkai',
  '今敏': 'satoshi kon',
  '押井守': 'mamoru oshii',
  '是枝裕和': 'hiro kazu koreeda',
  '王家卫': 'wong kar-wai',
  '张艺谋': 'zhang yimou',
  '陈凯歌': 'chen kaige',
  '李安': 'ang lee',
  '姜文': 'jiang wen',
  '周星驰': 'stephen chow',
  '徐克': 'tsui hark',
  '吴宇森': 'john woo',
  '贾樟柯': 'jia zhangke',
  '侯孝贤': 'hou hsiao-hsien',
  '杨德昌': 'edward yang',
  '黑泽明': 'akira kurosawa',
  '小津安二郎': 'yasujiro ozu',
  '北野武': 'takeshi kitano',
  '韦斯安德森': 'wes anderson',
  '大卫芬奇': 'david fincher',
  '丹尼斯维伦纽瓦': 'denis villeneuve',
  '雷德利斯科特': 'ridley scott',
  '马丁斯科塞斯': 'martin scorsese',
  // 演员
  '莱昂纳多': 'leonardo dicaprio',
  '小李子': 'leonardo dicaprio',
  '汤姆克鲁斯': 'tom cruise',
  '汤姆汉克斯': 'tom hanks',
  '布拉德皮特': 'brad pitt',
  '约翰尼德普': 'johnny depp',
  '斯嘉丽': 'scarlett johansson',
  '寡姐': 'scarlett johansson',
  '艾玛沃森': 'emma watson',
  '周迅': 'zhou xun',
  '章子怡': 'zhang ziyi',
  '梁朝伟': 'tony leung',
  '张国荣': 'leslie cheung',
  '刘德华': 'andy lau',
  '周润发': 'chow yun-fat',
  '成龙': 'jackie chan',
  '李连杰': 'jet li',
  '甄子丹': 'donnie yen',
  '张颂文': 'zhang songwen',
  '易烊千玺': 'jackson yee',
  '王一博': 'wang yibo',
  '肖战': 'xiao zhan',
  // 画家
  '梵高': 'van gogh',
  '莫奈': 'claude monet',
  '伦勃朗': 'rembrandt',
  '毕加索': 'pablo picasso',
  '达芬奇': 'leonardo da vinci',
  '米开朗基罗': 'michelangelo',
  '拉斐尔': 'raphael',
  '马蒂斯': 'henri matisse',
  '塞尚': 'paul cezanne',
  '高更': 'paul gauguin',
  '雷诺阿': 'pierre-auguste renoir',
  '德加': 'edgar degas',
  '克里姆特': 'gustav klimt',
  '蒙克': 'edvard munch',
  '维米尔': 'johannes vermeer',
  '葛饰北斋': 'hokusai',
  '浮世绘': 'ukiyo-e',
  '齐白石': 'qi baishi',
  '张大千': 'zhang daqian',
  '徐悲鸿': 'xu beihong',
  '八大山人': 'bada shanren',
};

/// R46 兜底链：内置人名表 → 内置词表 → 拼音（逐字，未知字丢弃）。
///
/// 绝不把中文原样发往英文源；两级都拿不到可检索词时返回空串，
/// 由调用方给出可执行建议（R45），不得静默失败（D96）。
String translateToEnglish(String input) {
  final String named = _applyNameMap(input);
  if (legacy.hasAsciiQuery(named)) return named;
  final String mapped = legacy.translateSceneToKeywords(input);
  if (legacy.hasAsciiQuery(mapped)) return mapped;
  final String pinyin = toPinyin(input);
  if (legacy.hasAsciiQuery(pinyin)) return pinyin;
  return '';
}

/// 人名表替换（命中后保留原词表结果拼接）。
String _applyNameMap(String input) {
  final List<String> parts = <String>[];
  var rest = input;
  for (final MapEntry<String, String> entry in kNameKeywordMap.entries) {
    if (rest.contains(entry.key)) {
      parts.add(entry.value);
      rest = rest.replaceAll(entry.key, ' ');
    }
  }
  if (parts.isEmpty) return '';
  final String tail = legacy.translateSceneToKeywords(rest);
  if (legacy.hasAsciiQuery(tail)) parts.add(tail);
  return parts.toSet().join(' ');
}

/// 逐字转无声调拼音（空格分隔）；非中文（英文/数字）原样保留。
String toPinyin(String input) {
  final StringBuffer buffer = StringBuffer();
  for (final int rune in input.runes) {
    final String ch = String.fromCharCode(rune);
    if (_isCjk(rune)) {
      final String py = kPinyinDict[ch] ?? '';
      if (py.isNotEmpty) buffer.write('$py ');
    } else if (_isAsciiWord(ch)) {
      buffer.write(ch);
    } else {
      buffer.write(' ');
    }
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// 是否含中文。
bool containsCjk(String text) => RegExp(r'[\u4e00-\u9fff]').hasMatch(text);

/// 是否有可用 ASCII 检索词（>=2 个字母/数字 token）。
bool hasAsciiQuery(String text) => legacy.hasAsciiQuery(text);

bool _isCjk(int rune) => rune >= 0x4e00 && rune <= 0x9fff;

bool _isAsciiWord(String ch) => RegExp(r'[A-Za-z0-9\-]').hasMatch(ch);
