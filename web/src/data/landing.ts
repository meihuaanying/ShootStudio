/**
 * V8/S10 · D157：首页与功能页共用文案。
 *
 * 单一来源：页面上所有眉题、标题、说明都从这里取，避免多处改口径。
 * `shot` 字段对应 `web/public/shots/<shot>.png`（真实产品静帧，禁止占位图 R82）。
 */

export interface Step {
  /** 步骤编号 1..4 */
  no: string;
  title: string;
  /** 参考来源（转化来源的诚实标注） */
  tool: string;
  desc: string;
}

export interface Card {
  title: string;
  desc: string;
  /** web/public/shots/ 下的短名（不含扩展名） */
  shot: string;
}

export const steps: Step[] = [
  {
    no: '1',
    title: '画面参考',
    tool: 'FILMGRAB 转化',
    desc: '按主题抓取真实画报帧，保留纵横比与来源许可；还能反向搜图、把参考收进画板。',
  },
  {
    no: '2',
    title: '布光预演',
    tool: 'Set.a.light 转化',
    desc: '把参考图的光位关系转成可编辑的灯位方案，拖拽调整即见即所得。',
  },
  {
    no: '3',
    title: '动作摆姿',
    tool: 'posemaniacs 转化',
    desc: '姿势库大图瀑布流配骨架叠加；导入照片后自动识别关节点，拖拽即可校正。',
  },
  {
    no: '4',
    title: '一键成案',
    tool: 'AI 策划助手',
    desc: '按杂志内页排版生成成案阅读视图，确认后写入策划画布，长图 / PDF / .sspak 导出。',
  },
];

export const cards: Card[] = [
  {
    title: '画面参考库',
    desc: '13 路来源与检索管线（NetRouter）不动，结果按原图比例瀑布流呈现。',
    shot: 'refs',
  },
  {
    title: '布光预演室',
    desc: '左清单 / 中画布 / 右检查器三栏，光位、器材与色温在同一屏内闭环调整。',
    shot: 'lighting',
  },
  {
    title: '动作摆姿库',
    desc: '10 类姿势 120 条，大图配分类眉题，详情走半屏抽屉可直接送入布光。',
    shot: 'poses',
  },
  {
    title: '策划案阅读视图',
    desc: '衬线刊头 + 眉题分节 + 图卡分镜 + 读数预算表，像杂志内页一样读自己的方案。',
    shot: 'plan',
  },
  {
    title: 'AI 策划助手',
    desc: '描述 → 生成中（可取消）→ 阅读三态收敛，失败自动换商，取消的草稿不可写入。',
    shot: 'ai',
  },
  {
    title: '导出与分享',
    desc: '长图 / PDF / .sspak 三格式，长图与 PDF 都带页眉页脚与来源许可附录页。',
    shot: 'export',
  },
  {
    title: '资源库',
    desc: '模特、服装、道具、场景、器材五大资源库，设备库覆盖六类 100%。',
    shot: 'library',
  },
  {
    title: '器材与选型',
    desc: '器材浏览器按类目检索，参数与产品图并排，产品图版权归原品牌仅供选型参考。',
    shot: 'gear',
  },
];
