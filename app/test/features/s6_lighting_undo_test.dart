import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoot_studio/core/db/database.dart';
import 'package:shoot_studio/core/providers.dart';
import 'package:shoot_studio/features/lighting/lighting_controller.dart';
import 'package:shoot_studio/features/lighting/lighting_models.dart';
import 'package:shoot_studio/features/lighting/lighting_undo.dart';

/// V8/D152 · S6 布光预演重构 — 撤销/重做（契约 ≥20 步）与交互区间折叠。
/// R79：只新增，不改动既有 q6_lighting/q6_engine/q6_still/q6_camera 用例。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LightingUndoStack（纯逻辑）', () {
    LightingSnapshot snap(String label, double x) => LightingSnapshot(
      scene: LightingSceneData(
        id: 's',
        name: '方案',
        devices: <DeviceSpec>[
          DeviceSpec(id: 'l1', kind: 'light', type: 'hard', name: '主灯', x: x),
        ],
      ),
      selectedId: 'l1',
      label: label,
    );

    test('容量默认 64 ≥ 契约要求的 20 步', () {
      expect(LightingUndoStack().capacity, greaterThanOrEqualTo(20));
    });

    test('撤销/重做往返：状态与选中项都还原', () {
      final LightingUndoStack stack = LightingUndoStack();
      final LightingSnapshot before = snap('移动主灯', 0);
      final LightingSnapshot after = snap('移动主灯', 2);
      stack.record(before);
      expect(stack.canUndo, isTrue);
      expect(stack.canRedo, isFalse);
      expect(stack.undoCount, 1);

      final LightingSnapshot? back = stack.undo(after);
      expect(back?.scene.devices.first.x, 0);
      expect(back?.selectedId, 'l1');
      expect(stack.canRedo, isTrue);

      final LightingSnapshot? forward = stack.redo(back!);
      expect(forward?.scene.devices.first.x, 2);
      expect(stack.canRedo, isFalse);
    });

    test('同标签 + 合并窗口内折叠为一步（拖拽 60 帧 = 1 步）', () {
      DateTime now = DateTime(2026, 10, 1);
      final LightingUndoStack stack = LightingUndoStack(clock: () => now);
      for (int i = 0; i < 60; i++) {
        stack.record(snap('移动主灯', i * 0.01));
        now = now.add(const Duration(milliseconds: 16));
      }
      expect(stack.undoCount, 1, reason: '一个拖拽手势只占一步');
    });

    test('超窗口的同标签不折叠（两次独立拖拽 = 两步）', () {
      DateTime now = DateTime(2026, 10, 1);
      final LightingUndoStack stack = LightingUndoStack(clock: () => now);
      stack.record(snap('移动主灯', 0));
      now = now.add(const Duration(seconds: 5));
      stack.record(snap('移动主灯', 1));
      expect(stack.undoCount, 2);
    });

    test('超出容量丢最旧（长会话不无限增长）', () {
      DateTime now = DateTime(2026, 10, 1);
      final LightingUndoStack stack = LightingUndoStack(
        capacity: 3,
        clock: () => now,
      );
      for (int i = 0; i < 6; i++) {
        stack.record(snap('调整 $i', i.toDouble()));
        now = now.add(const Duration(seconds: 5));
      }
      expect(stack.undoCount, 3);
    });

    test('record 后重做栈清空（撤销后再改 = 新分支）', () {
      final LightingUndoStack stack = LightingUndoStack();
      stack.record(snap('a', 0));
      stack.undo(snap('b', 1));
      expect(stack.canRedo, isTrue);
      stack.record(snap('c', 2));
      expect(stack.canRedo, isFalse);
    });

    test('空栈撤销/重做返回 null', () {
      final LightingUndoStack stack = LightingUndoStack();
      expect(stack.undo(snap('x', 0)), isNull);
      expect(stack.redo(snap('x', 0)), isNull);
      expect(stack.canUndo, isFalse);
      expect(stack.canRedo, isFalse);
    });

    test('快照是深拷贝：后续修改不影响已记录的状态', () {
      final LightingSceneData scene = LightingSceneData(
        id: 's',
        name: '方案',
        devices: <DeviceSpec>[
          DeviceSpec(id: 'l1', kind: 'light', type: 'hard', name: '主灯', x: 1),
        ],
      );
      final LightingSnapshot shot = LightingSnapshot.of(scene, 'l1', '移动');
      scene.devices.first.x = 9;
      expect(shot.scene.devices.first.x, 1);
    });
  });

  group('LightingController 撤销/重做接线', () {
    late AppDatabase db;
    late ProviderContainer container;
    late LightingController controller;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: <Override>[databaseProvider.overrideWithValue(db)],
      );
      controller = container.read(lightingControllerProvider.notifier);
      await controller.init();
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('新增灯具 → 撤销 → 重做（设备数量与选中项）', () {
      final int base = container
          .read(lightingControllerProvider)
          .scene
          .lights
          .length;
      controller.addLight(name: '测试灯');
      final String id = container.read(lightingControllerProvider).selectedId!;
      expect(
        container.read(lightingControllerProvider).scene.lights.length,
        base + 1,
      );
      expect(container.read(lightingControllerProvider).canUndo, isTrue);

      expect(controller.undo(), isTrue);
      LightingState state = container.read(lightingControllerProvider);
      expect(state.scene.lights.length, base);
      expect(state.selectedId, isNull);
      expect(state.canRedo, isTrue);
      expect(state.undoSeq, greaterThan(0));

      expect(controller.redo(), isTrue);
      state = container.read(lightingControllerProvider);
      expect(state.scene.lights.length, base + 1);
      expect(state.selectedId, id);
    });

    test('拖拽用 beginInteraction/endInteraction 只占一步', () {
      controller.addLight(name: '拖拽灯');
      final String id = container.read(lightingControllerProvider).selectedId!;
      controller.endInteraction();
      final int stepsBefore = controller.undoStack.undoCount;

      controller.beginInteraction('dev:$id');
      for (int i = 0; i < 30; i++) {
        controller.moveDevice(id, i * 0.1, 0.5);
      }
      controller.endInteraction();
      expect(
        controller.undoStack.undoCount,
        stepsBefore + 1,
        reason: '30 帧拖拽合并成一步',
      );

      expect(controller.undo(), isTrue);
      expect(
        container
            .read(lightingControllerProvider)
            .scene
            .devices
            .firstWhere((DeviceSpec d) => d.id == id)
            .x,
        isNot(closeTo(2.9, 0.001)),
      );
    });

    test('删除灯具可撤销回来', () {
      controller.addLight(name: '待删灯');
      final String id = container.read(lightingControllerProvider).selectedId!;
      controller.removeSelected();
      expect(
        container
            .read(lightingControllerProvider)
            .scene
            .devices
            .any((DeviceSpec d) => d.id == id),
        isFalse,
      );
      controller.undo();
      expect(
        container
            .read(lightingControllerProvider)
            .scene
            .devices
            .any((DeviceSpec d) => d.id == id),
        isTrue,
      );
    });

    test('机位改动可撤销（焦段回到原值）', () {
      final int beforeFocal = container
          .read(lightingControllerProvider)
          .scene
          .camera
          .focal;
      controller.updateCamera((CameraRigData c) => c.focal = 135);
      expect(
        container.read(lightingControllerProvider).scene.camera.focal,
        135,
      );
      controller.undo();
      expect(
        container.read(lightingControllerProvider).scene.camera.focal,
        beforeFocal,
      );
    });

    test('连续 25 步以上都可撤销（契约 ≥20 步）', () {
      for (int i = 0; i < 24; i++) {
        controller.addLight(name: '灯$i');
      }
      expect(controller.undoStack.undoCount, greaterThanOrEqualTo(20));
      for (int i = 0; i < 24; i++) {
        expect(controller.undo(), isTrue, reason: '第 ${i + 1} 步撤销');
      }
    });

    test('无内容时撤销给出提示而不抛异常', () {
      expect(controller.undo(), isFalse);
      expect(
        container.read(lightingControllerProvider).status,
        contains('没有可撤销'),
      );
      expect(controller.redo(), isFalse);
      expect(
        container.read(lightingControllerProvider).status,
        contains('没有可重做'),
      );
    });
  });
}
