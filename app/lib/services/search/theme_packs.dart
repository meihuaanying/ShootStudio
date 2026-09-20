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
];

/// 按 id 查找主题包。
ThemePack? themePackById(String id) {
  for (final ThemePack pack in kThemePacks) {
    if (pack.id == id) return pack;
  }
  return null;
}
