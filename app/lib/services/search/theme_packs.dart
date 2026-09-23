import 'search_models.dart';

/// 主题包（D120）：预置摄影主题，含中英关键词与推荐源；AI 可扩展任意主题。
class ThemePack {
  const ThemePack({
    required this.id,
    required this.name,
    required this.description,
    required this.zhTerms,
    required this.enQuery,
    this.domains = const <ImageDomain>{ImageDomain.photo},
    this.sources = const <String>['pexels'],
  });

  final String id;
  final String name;
  final String description;
  final List<String> zhTerms;
  final String enQuery;
  final Set<ImageDomain> domains;
  final List<String> sources;
}

/// 20+ 主题包（逆光人像/伦勃朗光/克莱因蓝/赛博霓虹/黑白纪实…）。
const List<ThemePack> kThemePacks = <ThemePack>[
  ThemePack(
    id: 'backlit-portrait',
    name: '逆光人像',
    description: '轮廓光勾边、发丝透光，适合黄昏与棚内硬光',
    zhTerms: <String>['逆光', '轮廓光', '人像'],
    enQuery: 'backlight portrait rim light',
  ),
  ThemePack(
    id: 'rembrandt',
    name: '伦勃朗光',
    description: '45° 侧上主光，面颊三角光斑',
    zhTerms: <String>['伦勃朗光', '侧光', '暗调'],
    enQuery: 'rembrandt lighting portrait chiaroscuro',
  ),
  ThemePack(
    id: 'butterfly',
    name: '蝴蝶光',
    description: '鼻下蝶形阴影，经典时尚美妆布光',
    zhTerms: <String>['蝴蝶光', '高级感', '人像'],
    enQuery: 'butterfly lighting beauty portrait',
  ),
  ThemePack(
    id: 'high-key',
    name: '高调写真',
    description: '白背景高亮度，干净通透',
    zhTerms: <String>['高调', '柔光', '甜美'],
    enQuery: 'high key photography bright white portrait',
  ),
  ThemePack(
    id: 'low-key',
    name: '低调暗调',
    description: '大面积暗部 + 单灯塑形，电影感强',
    zhTerms: <String>['低调', '暗调', '电影感'],
    enQuery: 'low key photography dark moody portrait',
  ),
  ThemePack(
    id: 'cyber-neon',
    name: '赛博霓虹',
    description: '青橙/洋红色光、雨夜反射',
    zhTerms: <String>['赛博', '霓虹', '雨夜'],
    enQuery: 'cyberpunk neon night portrait',
  ),
  ThemePack(
    id: 'klein-blue',
    name: '克莱因蓝',
    description: '高饱和蓝单色，极简高级',
    zhTerms: <String>['蓝调', '极简', '高级感'],
    enQuery: 'klein blue fashion editorial minimal',
  ),
  ThemePack(
    id: 'bw-documentary',
    name: '黑白纪实',
    description: '街头抓拍、颗粒与层次',
    zhTerms: <String>['黑白', '街拍', '抓拍'],
    enQuery: 'black and white street documentary photography',
  ),
  ThemePack(
    id: 'film-grain',
    name: '胶片复古',
    description: '漏光、颗粒、褪色怀旧',
    zhTerms: <String>['胶片', '复古', '怀旧'],
    enQuery: 'film photography grain vintage analog',
  ),
  ThemePack(
    id: 'chinese-style',
    name: '国风古装',
    description: '汉服/旗袍、园林与柔光',
    zhTerms: <String>['国风', '汉服', '古装'],
    enQuery: 'hanfu chinese traditional portrait garden',
  ),
  ThemePack(
    id: 'jk-school',
    name: '日系校园',
    description: '制服、教室、清新日光',
    zhTerms: <String>['JK', '校园', '元气'],
    enQuery: 'japanese school uniform classroom portrait',
  ),
  ThemePack(
    id: 'wedding',
    name: '婚纱婚礼',
    description: '白纱、逆光、仪式感',
    zhTerms: <String>['婚纱', '婚礼', '浪漫'],
    enQuery: 'wedding dress bride portrait',
  ),
  ThemePack(
    id: 'cosplay',
    name: '二次元 Cos',
    description: '角色扮演、道具与特效光',
    zhTerms: <String>['cosplay', '二次元', '古装'],
    enQuery: 'cosplay costume portrait anime',
  ),
  ThemePack(
    id: 'y2k',
    name: '千禧 Y2K',
    description: '闪光灯直打、亮片与未来感',
    zhTerms: <String>['千禧', '未来感', '撞色'],
    enQuery: 'y2k aesthetic flash photography fashion',
  ),
  ThemePack(
    id: 'rooftop-night',
    name: '天台夜景',
    description: '城市灯海、蓝调时刻',
    zhTerms: <String>['天台', '夜景', '蓝调'],
    enQuery: 'rooftop night city skyline portrait',
  ),
  ThemePack(
    id: 'rainy-street',
    name: '雨夜街头',
    description: '湿地反射、伞与车灯',
    zhTerms: <String>['雨夜', '街道', '倒影'],
    enQuery: 'rainy night street reflection umbrella',
  ),
  ThemePack(
    id: 'studio-fashion',
    name: '棚拍时尚',
    description: '纯色背景 + 硬光造型',
    zhTerms: <String>['棚拍', '时尚', '高级感'],
    enQuery: 'studio fashion editorial hard light',
  ),
  ThemePack(
    id: 'underwater',
    name: '水下摄影',
    description: '水体折射、飘发与气泡',
    zhTerms: <String>['水下', '梦幻', '水花'],
    enQuery: 'underwater fashion portrait bubbles',
  ),
  ThemePack(
    id: 'snow-winter',
    name: '雪景冬日',
    description: '雪地反光板、冷调通透',
    zhTerms: <String>['雪景', '冷色', '冬天'],
    enQuery: 'snow winter portrait cold tones',
  ),
  ThemePack(
    id: 'desert-star',
    name: '沙漠星空',
    description: '银河背景 + 人造补光',
    zhTerms: <String>['沙漠星空', '星空', '银河'],
    enQuery: 'desert night stars milky way portrait',
  ),
  ThemePack(
    id: 'golden-hour',
    name: '黄金时刻',
    description: '日出日落暖调、长影',
    zhTerms: <String>['日落', '黄昏', '暖色'],
    enQuery: 'golden hour sunset warm portrait',
  ),
  ThemePack(
    id: 'silhouette',
    name: '剪影',
    description: '强逆光黑剪影与轮廓',
    zhTerms: <String>['剪影', '逆光', '日落'],
    enQuery: 'silhouette sunset strong backlight',
  ),
  ThemePack(
    id: 'food-still',
    name: '美食静物',
    description: '暗调侧光、质感与蒸汽',
    zhTerms: <String>['美食', '静物', '暗调'],
    enQuery: 'food photography dark moody still life',
  ),
  ThemePack(
    id: 'pet',
    name: '宠物写真',
    description: '自然光抓拍、浅景深',
    zhTerms: <String>['宠物', '猫', '狗'],
    enQuery: 'pet portrait cat dog natural light',
  ),
  ThemePack(
    id: 'cinematic-still',
    name: '影视感剧照',
    description: '电影感打光、叙事氛围（影视剧照参考）',
    zhTerms: <String>['影视感', '剧照', '电影感'],
    enQuery: 'cinematic film still dramatic lighting',
    domains: <ImageDomain>{ImageDomain.film, ImageDomain.photo},
    sources: <String>['tmdb', 'pexels'],
  ),
  ThemePack(
    id: 'editorial-fashion',
    name: '杂志大片',
    description: '时尚编辑大片、造型与硬光',
    zhTerms: <String>['杂志', '大片', '时尚'],
    enQuery: 'editorial fashion magazine photoshoot',
  ),
  ThemePack(
    id: 'painterly',
    name: '画作风格',
    description: '古典油画光、明暗对照与肌理',
    zhTerms: <String>['画作', '油画', '古典'],
    enQuery: 'oil painting classical portrait chiaroscuro',
    domains: <ImageDomain>{ImageDomain.art},
  ),
  ThemePack(
    id: 'new-chinese',
    name: '新中式',
    description: '新中式禅意、留白与器物',
    zhTerms: <String>['新中式', '禅意', '东方'],
    enQuery: 'new chinese style zen minimal oriental',
  ),
  ThemePack(
    id: 'hongkong-retro',
    name: '港风复古',
    description: '90 年代港风、霓虹与胶片色',
    zhTerms: <String>['港风', '复古港', '九龙'],
    enQuery: 'hong kong retro 90s neon film style',
  ),
  ThemePack(
    id: 'japanese-fresh',
    name: '日系清新',
    description: '低对比通透、自然光与生活感',
    zhTerms: <String>['日系', '清新', '通透'],
    enQuery: 'japanese style airy fresh natural light',
  ),
  ThemePack(
    id: 'korean-profile',
    name: '韩系写真',
    description: '柔光氛围、简约造型',
    zhTerms: <String>['韩系', '写真', '氛围感'],
    enQuery: 'korean style mood portrait soft light',
  ),
  ThemePack(
    id: 'analog-portrait',
    name: '复古胶片人像',
    description: '暖调颗粒、怀旧肤色',
    zhTerms: <String>['胶片人像', '暖调', '颗粒感'],
    enQuery: 'analog film portrait warm grain',
  ),
  ThemePack(
    id: 'minimal-white',
    name: '极简白色',
    description: '纯白空间、几何留白',
    zhTerms: <String>['极简白', '留白', '纯色'],
    enQuery: 'minimal white clean studio photography',
  ),
  ThemePack(
    id: 'blue-hour',
    name: '蓝调时刻',
    description: '暮色冷调、城市灯光初上',
    zhTerms: <String>['蓝调时刻', '暮色', '冷调'],
    enQuery: 'blue hour twilight city cool tones',
  ),
  ThemePack(
    id: 'neon-rain',
    name: '霓虹雨夜',
    description: '霓虹倒影、湿街与伞',
    zhTerms: <String>['霓虹雨', '湿街', '倒影'],
    enQuery: 'neon rain night wet street reflections',
  ),
  ThemePack(
    id: 'industrial-ruins',
    name: '工业废墟',
    description: '废墟质感、颓废叙事',
    zhTerms: <String>['废墟', '工业风', '颓废'],
    enQuery: 'industrial ruins abandoned urban portrait',
  ),
  ThemePack(
    id: 'desert-golden',
    name: '沙漠黄金',
    description: '沙丘线条、暖色旷野',
    zhTerms: <String>['沙漠', '沙丘', '旷野'],
    enQuery: 'desert dunes golden sand portrait',
  ),
  ThemePack(
    id: 'forest-mood',
    name: '森系自然',
    description: '森林散射光、绿意氛围',
    zhTerms: <String>['森系', '森林', '绿意'],
    enQuery: 'forest natural light moody green portrait',
  ),
  ThemePack(
    id: 'winter-sun',
    name: '冬日暖阳',
    description: '低角度暖阳、雪地反光',
    zhTerms: <String>['冬日暖阳', '暖冬', '雪地'],
    enQuery: 'winter warm sunlight snow portrait',
  ),
  ThemePack(
    id: 'street-doc',
    name: '街头纪实',
    description: '抓拍瞬间、环境叙事',
    zhTerms: <String>['街头', '纪实', '抓拍'],
    enQuery: 'street documentary candid photography',
  ),
  ThemePack(
    id: 'geometric-arch',
    name: '建筑几何',
    description: '线条、对称与结构感',
    zhTerms: <String>['建筑', '几何', '线条'],
    enQuery: 'architecture geometric lines minimal',
  ),
  ThemePack(
    id: 'shadow-patterns',
    name: '光影条纹',
    description: '百叶窗投影、光斑分割',
    zhTerms: <String>['光影条纹', '百叶窗', '光斑'],
    enQuery: 'shadow patterns blinds light stripes portrait',
  ),
  ThemePack(
    id: 'watercolor-soft',
    name: '水彩柔光',
    description: '低饱和梦幻、柔焦质感',
    zhTerms: <String>['水彩', '柔焦', '梦幻'],
    enQuery: 'watercolor soft dreamy pastel portrait',
  ),
  ThemePack(
    id: 'sci-fi-space',
    name: '科幻太空',
    description: '未来光源、冷色科技感',
    zhTerms: <String>['科幻', '太空', '未来感'],
    enQuery: 'sci-fi space futuristic lighting',
  ),
  ThemePack(
    id: 'gothic-dark',
    name: '暗黑哥特',
    description: '暗部层次、神秘叙事',
    zhTerms: <String>['哥特', '暗黑', '神秘'],
    enQuery: 'gothic dark mysterious portrait',
  ),
  ThemePack(
    id: 'summer-beach',
    name: '夏日海滩',
    description: '阳光水面、度假氛围',
    zhTerms: <String>['海滩', '夏日', '度假'],
    enQuery: 'summer beach sunlight vacation portrait',
  ),
  ThemePack(
    id: 'old-money',
    name: '老钱风',
    description: '低调质感、经典优雅',
    zhTerms: <String>['老钱风', '优雅', '质感'],
    enQuery: 'old money aesthetic elegant classic style',
  ),
  ThemePack(
    id: 'catwalk',
    name: '秀场走秀',
    description: 'T 台动态、闪光灯造型',
    zhTerms: <String>['秀场', '走秀', 'T台'],
    enQuery: 'runway fashion show catwalk',
  ),
];

/// 常用主题（标签行默认展示，D133）。
const List<String> kCommonThemeIds = <String>[
  'backlit-portrait',
  'rembrandt',
  'cyber-neon',
  'bw-documentary',
  'film-grain',
  'golden-hour',
  'studio-fashion',
  'editorial-fashion',
];

/// 常用主题包列表（8 个，标签行用）。
List<ThemePack> commonThemePacks() =>
    kCommonThemeIds.map(themePackById).whereType<ThemePack>().toList();

/// 关键词自动匹配主题包（D133）：命中名称或中文词条取最长匹配。
///
/// 词条需足够「具体」才触发：≥3 字，或占查询长度一半以上
/// （避免「雨夜霓虹 天台」这类组合查询被单个 2 字词条劫持）。
ThemePack? matchThemePack(String text) {
  final String t = text.toLowerCase().trim();
  if (t.isEmpty) return null;
  ThemePack? best;
  int bestScore = 0;
  for (final ThemePack pack in kThemePacks) {
    int score = 0;
    if (t.contains(pack.name.toLowerCase())) {
      score = pack.name.length + 10;
    }
    for (final String term in pack.zhTerms) {
      final String k = term.toLowerCase();
      if (k.isEmpty || !t.contains(k)) continue;
      final bool strong = k.length >= 3 || k.length * 2 >= t.length;
      if (strong && k.length > score) {
        score = k.length;
      }
    }
    if (score > bestScore) {
      bestScore = score;
      best = pack;
    }
  }
  return bestScore >= 2 ? best : null;
}

/// 按 id 查找主题包。
ThemePack? themePackById(String id) {
  for (final ThemePack pack in kThemePacks) {
    if (pack.id == id) return pack;
  }
  return null;
}
