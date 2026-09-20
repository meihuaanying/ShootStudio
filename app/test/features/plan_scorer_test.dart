import 'package:flutter_test/flutter_test.dart';
import 'package:shoot_studio/features/ai/plan_scorer.dart';
import 'package:shoot_studio/features/planner/planner_models.dart';

PlanModuleData _module(
  String id,
  PlanModuleType type,
  String title,
  Map<String, Object?> data,
) => PlanModuleData(id: id, type: type, title: title, data: data);

List<PlanModuleData> _goodPlan() => <PlanModuleData>[
  _module('m1', PlanModuleType.theme, '拍摄主题', <String, Object?>{
    'text':
        '雨夜赛博朋克正片，霓虹与湿地反光为主基调。冷主光塑造轮廓，'
        '品红与青色点缀环境；服化道对齐角色设定，突出神态与配色一致性。',
  }),
  _module('m2', PlanModuleType.crew, '人员分工', <String, Object?>{
    'rows': <Object?>[
      <String, Object?>{'role': '摄影师', 'who': 'A', 'time': '10:00'},
      <String, Object?>{'role': '妆造', 'who': 'B', 'time': '08:30'},
    ],
  }),
  _module('m3', PlanModuleType.budget, '预算表', <String, Object?>{
    'rows': <Object?>[
      <String, Object?>{'item': '场地', 'price': 400, 'note': ''},
      <String, Object?>{'item': '妆造', 'price': 500, 'note': ''},
    ],
  }),
  _module('m4', PlanModuleType.poses, '姿势清单', <String, Object?>{
    'poses': <Object?>[
      <String, Object?>{'name': '侧身回眸', 'lens': '35mm', 'cameraPosition': '腰位'},
      <String, Object?>{'name': '撑墙', 'lens': '50mm', 'cameraPosition': '胸口'},
      <String, Object?>{'name': '蹲姿', 'lens': '85mm', 'cameraPosition': '低机位'},
    ],
  }),
  _module('m5', PlanModuleType.sun, '日照时间', <String, Object?>{
    'place': '上海',
    'date': '2026-09-12',
    'lat': 31.23,
    'lon': 121.47,
  }),
];

void main() {
  test('空列表：结构不合法且总分为 0', () {
    final PlanScore score = PlanScorer.score(<PlanModuleData>[]);
    expect(score.structureOk, isFalse);
    expect(score.total, 0);
    expect(score.needsRetry, isTrue);
  });

  test('高质量稿：总分 ≥ 80 且无需重试', () {
    final PlanScore score = PlanScorer.score(_goodPlan());
    expect(score.structureOk, isTrue);
    expect(score.total, greaterThanOrEqualTo(80));
    expect(score.needsRetry, isFalse);
    expect(score.shortcomings, isEmpty);
  });

  test('细节缺失：低分并给出短板清单', () {
    final List<PlanModuleData> poor = <PlanModuleData>[
      _module('m1', PlanModuleType.theme, '拍摄主题', <String, Object?>{
        'text': '夜景',
      }),
      _module('m2', PlanModuleType.crew, '人员分工', <String, Object?>{
        'rows': <Object?>[
          <String, Object?>{'role': '摄影师', 'who': '', 'time': ''},
        ],
      }),
      _module('m3', PlanModuleType.budget, '预算表', <String, Object?>{
        'rows': <Object?>[
          <String, Object?>{'item': '场地', 'price': 0, 'note': ''},
        ],
      }),
    ];
    final PlanScore score = PlanScorer.score(poor);
    expect(score.structureOk, isTrue);
    expect(score.total, lessThan(80));
    expect(score.needsRetry, isTrue);
    expect(score.shortcomings.length, greaterThanOrEqualTo(3));
  });

  test('引用一致性：绑定不存在的资源会拉低一致性分', () {
    final List<PlanModuleData> modules = _goodPlan()
      ..add(
        _module('m6', PlanModuleType.model, '模特绑定', <String, Object?>{
          'ids': <String>['missing-1', 'missing-2'],
        }),
      );
    final PlanScore score = PlanScorer.score(
      modules,
      knownResourceIds: <String>{'real-1'},
    );
    expect(score.consistencyScore, lessThan(100));
    expect(score.shortcomings.any((String s) => s.contains('模特绑定')), isTrue);
  });

  test('引用存在：一致性 100', () {
    final List<PlanModuleData> modules = _goodPlan()
      ..add(
        _module('m6', PlanModuleType.model, '模特绑定', <String, Object?>{
          'ids': <String>['real-1'],
        }),
      );
    final PlanScore score = PlanScorer.score(
      modules,
      knownResourceIds: <String>{'real-1'},
    );
    expect(score.consistencyScore, 100);
  });
}
