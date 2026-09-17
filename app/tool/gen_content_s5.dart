// 内容包生成器 · S5：预算价格区间（F9）与城市库（F10）。
// 运行：dart run tool/gen_content_s5.dart
import 'dart:convert';
import 'dart:io';

void _writeJson(String path, Object data) {
  final File file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));
  stdout.writeln('written $path');
}

List<Map<String, Object?>> _cities() {
  const List<List<Object>> rows = [
    <Object>['北京', 39.90, 116.40, '一线'],
    <Object>['上海', 31.23, 121.47, '一线'],
    <Object>['广州', 23.13, 113.26, '一线'],
    <Object>['深圳', 22.54, 114.06, '一线'],
    <Object>['成都', 30.57, 104.07, '新一线'],
    <Object>['杭州', 30.27, 120.16, '新一线'],
    <Object>['重庆', 29.56, 106.55, '新一线'],
    <Object>['武汉', 30.59, 114.31, '新一线'],
    <Object>['西安', 34.34, 108.94, '新一线'],
    <Object>['苏州', 31.30, 120.58, '新一线'],
    <Object>['天津', 39.13, 117.20, '新一线'],
    <Object>['南京', 32.06, 118.80, '新一线'],
    <Object>['郑州', 34.75, 113.63, '新一线'],
    <Object>['长沙', 28.23, 112.94, '新一线'],
    <Object>['东莞', 23.02, 113.75, '新一线'],
    <Object>['沈阳', 41.80, 123.43, '新一线'],
    <Object>['青岛', 36.07, 120.38, '新一线'],
    <Object>['合肥', 31.82, 117.23, '新一线'],
    <Object>['佛山', 23.02, 113.12, '新一线'],
    <Object>['宁波', 29.87, 121.55, '新一线'],
    <Object>['昆明', 24.88, 102.83, '二线'],
    <Object>['福州', 26.07, 119.30, '二线'],
    <Object>['无锡', 31.49, 120.31, '二线'],
    <Object>['厦门', 24.48, 118.09, '二线'],
    <Object>['哈尔滨', 45.80, 126.53, '二线'],
    <Object>['长春', 43.82, 125.32, '二线'],
    <Object>['南昌', 28.68, 115.86, '二线'],
    <Object>['济南', 36.65, 117.12, '二线'],
    <Object>['大连', 38.91, 121.61, '二线'],
    <Object>['贵阳', 26.65, 106.63, '二线'],
    <Object>['温州', 27.99, 120.70, '二线'],
    <Object>['石家庄', 38.04, 114.51, '二线'],
    <Object>['泉州', 24.87, 118.68, '二线'],
    <Object>['南宁', 22.82, 108.32, '二线'],
    <Object>['金华', 29.08, 119.65, '二线'],
    <Object>['常州', 31.81, 119.97, '二线'],
    <Object>['珠海', 22.27, 113.58, '二线'],
    <Object>['惠州', 23.11, 114.42, '二线'],
    <Object>['嘉兴', 30.75, 120.76, '二线'],
    <Object>['南通', 31.98, 120.89, '二线'],
    <Object>['中山', 22.52, 113.39, '二线'],
    <Object>['保定', 38.87, 115.46, '二线'],
    <Object>['兰州', 36.06, 103.83, '二线'],
    <Object>['台州', 28.66, 121.42, '二线'],
    <Object>['徐州', 34.26, 117.19, '二线'],
    <Object>['太原', 37.87, 112.55, '二线'],
    <Object>['绍兴', 30.00, 120.58, '二线'],
    <Object>['烟台', 37.46, 121.45, '二线'],
    <Object>['廊坊', 39.52, 116.70, '二线'],
    <Object>['海口', 20.04, 110.32, '三线'],
    <Object>['三亚', 18.25, 109.51, '三线'],
    <Object>['乌鲁木齐', 43.83, 87.62, '三线'],
    <Object>['呼和浩特', 40.84, 111.75, '三线'],
    <Object>['银川', 38.49, 106.23, '三线'],
    <Object>['西宁', 36.62, 101.78, '三线'],
    <Object>['拉萨', 29.65, 91.14, '三线'],
    <Object>['桂林', 25.27, 110.29, '三线'],
    <Object>['丽江', 26.86, 100.23, '三线'],
    <Object>['大理', 25.61, 100.27, '三线'],
    <Object>['敦煌', 40.14, 94.66, '三线'],
    <Object>['张家界', 29.12, 110.48, '三线'],
    <Object>['秦皇岛', 39.94, 119.60, '三线'],
    <Object>['威海', 37.51, 122.12, '三线'],
    <Object>['北海', 21.48, 109.12, '三线'],
    <Object>['景德镇', 29.27, 117.18, '三线'],
    <Object>['洛阳', 34.62, 112.45, '三线'],
    <Object>['开封', 34.80, 114.31, '三线'],
    <Object>['平遥', 37.19, 112.18, '三线'],
    <Object>['婺源', 29.25, 117.86, '三线'],
    <Object>['青岛崂山', 36.16, 120.47, '三线'],
    <Object>['稻城', 29.04, 100.30, '三线'],
    <Object>['阿坝', 31.90, 102.22, '三线'],
    <Object>['呼伦贝尔', 49.21, 119.77, '三线'],
  ];
  return rows
      .map((List<Object> row) => <String, Object?>{
            'name': row[0],
            'lat': row[1],
            'lon': row[2],
            'tier': row[3],
          })
      .toList();
}

List<Map<String, Object?>> _budgetItems() {
  const List<List<Object>> rows = [
    ['studio', '棚时（小时）', 150, 600, '含基础灯位与背景纸'],
    ['outdoor', '外景场地（小时）', 100, 400, '含景区门票/备案费用'],
    ['makeup', '妆造（次）', 200, 800, '角色妆/古风妆按复杂度浮动'],
    ['makeup_day', '跟妆（天）', 400, 1500, '含全程补妆'],
    ['model', '模特（天）', 300, 2000, '互勉为 0'],
    ['costume', '服装租赁（套）', 100, 500, '定制成本另计'],
    ['props', '道具采购（项）', 20, 300, '烟饼/花束/灯笼等'],
    ['transport', '交通（天）', 50, 300, '市区打车/油费'],
    ['meal', '餐饮（人/天）', 30, 120, '含模特与团队'],
    ['assistant', '摄影助理（天）', 200, 600, '灯光/场务'],
    ['retouch', '后期精修（张）', 20, 100, '按精修难度'],
    ['print', '打印物料（项）', 50, 300, '展架/相册/证书'],
  ];
  return rows
      .map((List<Object> row) => <String, Object?>{
            'key': row[0],
            'label': row[1],
            'min': row[2],
            'max': row[3],
            'note': row[4],
          })
      .toList();
}

void main() {
  final cities = _cities();
  _writeJson('assets/content/cities/cities.json', <String, Object?>{
    'version': 1,
    'note': '常用拍摄城市坐标（近似值，可在线搜索修正）',
    'multipliers': <String, Object?>{
      '一线': 1.4,
      '新一线': 1.15,
      '二线': 1.0,
      '三线': 0.8
    },
    'cities': cities,
  });
  _writeJson('assets/content/budget/budget_refs.json', <String, Object?>{
    'version': 1,
    'note': '预算参考区间（人民币，按城市档位乘系数）',
    'items': _budgetItems(),
  });
  stdout
      .writeln('cities=${cities.length} budgetItems=${_budgetItems().length}');
}
