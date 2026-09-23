/// PD 公有领域影片索引（D78）：中文别名 / 主创 / 题材检索。
/// V7/D132：画面参考极简后从 refs_page 拆出为独立服务，q5 门禁继续覆盖。
/// PD 影片中文别名 / 主创 / 题材（D78：支持中文检索；键为英文原片名）。
const Map<String, List<String>> kPdFilmAliases = <String, List<String>>{
  'Nosferatu': <String>['诺斯费拉图', '吸血鬼', '恐怖', '默片', '茂瑙', 'Murnau'],
  'The Kid': <String>['寻子遇仙记', '弃儿的故事', '小孩', '卓别林', 'Chaplin', '喜剧'],
  'Sherlock Jr.': <String>['福尔摩斯二世', '小福尔摩斯', '基顿', 'Keaton', '喜剧'],
  'Battleship Potemkin': <String>[
    '战舰波将金号',
    '波将金号',
    '爱森斯坦',
    'Eisenstein',
    '蒙太奇',
  ],
  'The General': <String>['将军号', '基顿', 'Keaton', '喜剧', '火车'],
  'Metropolis': <String>['大都会', '科幻', '弗里茨朗', 'Fritz Lang', '未来都市'],
  'The Cabinet of Dr. Caligari': <String>['卡里加里博士的小屋', '卡里加里', '恐怖', '表现主义'],
  'A Trip to the Moon': <String>['月球旅行记', '月球漫游', '梅里爱', 'Méliès', '科幻'],
  'His Girl Friday': <String>['女友礼拜五', '小报妙冤家', '喜剧', '新闻'],
  'Night of the Living Dead': <String>['活死人之夜', '丧尸', '罗梅罗', 'Romero', '恐怖'],
};

/// PD 影片搜索（D78）：多字段 + 中文别名 + 空格分词 token 匹配。
bool pdFilmMatches(Map<String, Object?> film, List<String> tokens) {
  if (tokens.isEmpty) return true;
  final String title = '${film['title'] ?? ''}'.toLowerCase();
  final String year = '${film['year'] ?? ''}';
  final List<String> aliases = kPdFilmAliases['${film['title']}'] ?? <String>[];
  final String haystack = <String>[
    title,
    year,
    ...aliases,
    for (final Object? f in film['frames'] as List<Object?>? ?? <Object?>[])
      if (f is Map) '${f['title'] ?? ''} ${f['author'] ?? ''}',
  ].join(' ').toLowerCase();
  return tokens.every((String t) => haystack.contains(t));
}
