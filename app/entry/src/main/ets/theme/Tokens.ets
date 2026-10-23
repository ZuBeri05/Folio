import { curves } from '@kit.ArkUI';

export class Tokens {
  static readonly bg: string = '#F7F2E4';
  static readonly surface: string = '#D9FFFDF8';
  static readonly surfaceSoft: string = '#B3FFFDF8';
  static readonly ink: string = '#2C251D';
  static readonly inkSoft: string = '#4B4032';
  static readonly muted: string = '#8D7F6C';
  static readonly mutedSoft: string = '#B2A48F';
  static readonly line: string = '#1A5E4B30';
  static readonly lineStrong: string = '#2B5E4B30';
  static readonly yellow: string = '#FFC531';
  static readonly yellowSoft: string = '#FFF3C9';
  static readonly orange: string = '#FF8A2A';
  static readonly coral: string = '#FF6542';
  static readonly blue: string = '#7E9FB5';
  static readonly pink: string = '#D98F87';
  static readonly shadow: string = '#14000000';
  static readonly dim: string = '#660B0806';
  static readonly white: string = '#FFFFFF';
}

/**
 * 动效 token。
 *
 * 三条约束：
 * 1. 时长只用这里定义的 5 个刻度，不再在页面里手填数字。
 * 2. 位移幅度一律走 travel()，按屏宽缩放 —— 手机 360vp 与平板 1200vp 拿到不同的 vp。
 * 3. 弹簧曲线是物理曲线，animateTo 的 duration 对它不生效，调用时不要传 duration。
 */
export class Motion {
  /** 微反馈：按下、勾选 */
  static readonly instant: number = 110;
  /** 轻量状态切换：图标、小控件 */
  static readonly quick: number = 170;
  /** 常规：卡片、面板 */
  static readonly base: number = 260;
  /** 慢速：整块入场 */
  static readonly slow: number = 380;
  /** 页面切换 */
  static readonly page: number = 520;

  /** 入场：快起慢停（decelerate） */
  static decel(): ICurve {
    return curves.cubicBezierCurve(0.05, 0.7, 0.1, 1);
  }

  /** 出场：慢起快走（accelerate），只用于关闭/退场 */
  static accel(): ICurve {
    return curves.cubicBezierCurve(0.3, 0, 1, 1);
  }

  /** 同屏内的平滑过渡 */
  static standard(): ICurve {
    return curves.cubicBezierCurve(0.2, 0, 0, 1);
  }

  /** 弹簧：柔和落位，几乎不过冲。用于列表、面板入场 */
  static settle(): ICurve {
    return curves.interpolatingSpring(0, 1, 180, 26);
  }

  /** 弹簧：脆快，轻微过冲。用于按钮、小元素 */
  static snap(): ICurve {
    return curves.interpolatingSpring(0, 1, 420, 34);
  }

  /** 弹簧：明显回弹。用于"撞击"这类需要冲击感的地方 */
  static bounce(): ICurve {
    return curves.interpolatingSpring(0, 1, 340, 20);
  }

  /** 跟手：拖拽、手势松手后的回位 */
  static follow(): ICurve {
    return curves.responsiveSpringMotion(0.3, 0.85);
  }

  /** 屏宽 → 动效缩放因子。手机约 0.55，平板 1.0 上下 */
  static scale(width: number): number {
    if (!(width > 0)) {
      return 1;
    }
    const s: number = width / 1000;
    return Math.max(0.55, Math.min(1.15, s));
  }

  /** 位移幅度（vp），随屏宽缩放 */
  static travel(base: number, width: number): number {
    const v: number = base * Motion.scale(width);
    return Math.round(v * 10) / 10;
  }

  /** 时长（ms），位移越短时长越短，收敛在 0.86~1.14 倍 */
  static time(base: number, width: number): number {
    const k: number = 0.86 + 0.24 * Motion.scale(width);
    return Math.round(base * k);
  }
}
