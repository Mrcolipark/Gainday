# FolioForge - 跨国多资产持仓管理 App 开发计划

## 产品定位

一款精品级 iOS 26 原生资产管理 App。手动输入跨国多券商持仓（日股、A股、港股、美股含盘前盘后、基金、NISA、贵金属、加密货币、现金、债券），自动抓取行情计算每日盈亏，以**日历热力图**可视化展示，支持**精美日历分享图（带二维码）**，配备桌面小组件。全面采用 iOS 26 Liquid Glass 设计语言，追求精良 UI 品质。

---

## 技术栈

| 层 | 技术 |
|---|---|
| UI | SwiftUI + iOS 26 Liquid Glass |
| 数据 | SwiftData + CloudKit (iCloud 同步) |
| 网络 | Swift Concurrency (async/await) + URLSession |
| 小组件 | WidgetKit (Small / Medium / Large) |
| 图表 | Swift Charts |
| 分享图 | ImageRenderer + CoreImage (QR 码生成) |
| 行情 | Yahoo Finance v8 API (免费, 无需 Key) |
| 触觉 | UIImpactFeedbackGenerator / sensoryFeedback |
| 最低版本 | iOS 26.0 |

---

## 行情数据方案

### 主数据源: Yahoo Finance v8 (免费, 无需 API Key)

```
// 日K线数据
GET https://query1.finance.yahoo.com/v8/finance/chart/{symbol}?interval=1d&range=3mo

// 实时报价 (含盘前盘后)
GET https://query1.finance.yahoo.com/v7/finance/quote?symbols={symbol}
  → 返回: regularMarketPrice, preMarketPrice, postMarketPrice, marketState
```

### 各市场 symbol 格式

| 市场 | 格式 | 示例 |
|---|---|---|
| 日股 (TSE) | `{code}.T` | `7203.T` 丰田, `9984.T` 软银 |
| A股 上交所 | `{code}.SS` | `600519.SS` 茅台 |
| A股 深交所 | `{code}.SZ` | `000858.SZ` 五粮液 |
| 港股 | `{code}.HK` | `0700.HK` 腾讯 |
| 美股 | `{code}` | `AAPL`, `TSLA` |
| 黄金 | `GC=F` | 黄金期货 |
| 白银 | `SI=F` | 白银期货 |
| 加密 | `{coin}-USD` | `BTC-USD`, `ETH-USD` |
| 汇率 | `{pair}=X` | `JPYUSD=X`, `CNYUSD=X` |

### 美股盘前盘后 (Extended Hours)

Yahoo Finance `/v7/finance/quote` 返回:
- `marketState`: `"PRE"` / `"REGULAR"` / `"POST"` / `"CLOSED"`
- `preMarketPrice`, `preMarketChange`, `preMarketChangePercent`
- `postMarketPrice`, `postMarketChange`, `postMarketChangePercent`

App 内根据 `marketState` 自动切换显示:
- 盘前: 显示 preMarketPrice + 标记 "盘前"
- 盘中: 显示 regularMarketPrice
- 盘后: 显示 postMarketPrice + 标记 "盘后"
- 休市: 显示 regularMarketPrice + 标记 "收盘"

### 抓取策略

- 前台打开时自动刷新
- 后台 `BGAppRefreshTask` 定期尝试刷新
- 美股盘前盘后时段 (东京时间 22:00~翌日 6:00) 轮询
- 每日收盘后生成 `DailySnapshot` 保存历史盈亏
- 小组件通过 App Group 共享数据

---

## 数据模型 (SwiftData)

```swift
@Model class Portfolio {
    var id: UUID
    var name: String              // "楽天証券", "招商证券"
    var accountType: String       // normal / nisa_tsumitate / nisa_growth
    var baseCurrency: String      // JPY, CNY, USD
    var sortOrder: Int
    var colorTag: String          // 账户标识色: "blue", "orange", ...
    @Relationship(deleteRule: .cascade)
    var holdings: [Holding]
    var createdAt: Date
}

@Model class Holding {
    var id: UUID
    var symbol: String            // "7203.T"
    var name: String              // "トヨタ自動車"
    var assetType: String         // stock / fund / metal / crypto / bond / cash
    var market: String            // JP, CN, US, HK, COMMODITY, CRYPTO
    @Relationship(deleteRule: .cascade)
    var transactions: [Transaction]
    var portfolio: Portfolio?
}

@Model class Transaction {
    var id: UUID
    var type: String              // buy / sell / dividend
    var date: Date
    var quantity: Double
    var price: Double
    var fee: Double
    var currency: String
    var note: String              // 交易备注
    var holding: Holding?
}

@Model class DailySnapshot {
    var id: UUID
    var date: Date                // 年月日 (无时分秒)
    var totalValue: Double        // 当日总市值 (基准货币)
    var totalCost: Double
    var dailyPnL: Double          // 当日盈亏
    var dailyPnLPercent: Double   // 当日盈亏 %
    var cumulativePnL: Double     // 累计盈亏
    // 按资产类型的分项快照 (JSON encoded)
    var breakdownJSON: String
}

@Model class PriceCache {
    var symbol: String
    var date: Date
    var open: Double
    var high: Double
    var low: Double
    var close: Double
    var currency: String
    // 盘前盘后
    var preMarketPrice: Double?
    var postMarketPrice: Double?
    var marketState: String?
}
```

---

## 精良 UI 设计系统

### 设计哲学

> 你不需要会设计，但要用对工具。iOS 26 的 Liquid Glass + SF Symbols + Swift Charts + 系统字体 + 微交互动画 = 开箱即精品。

### 色彩系统

```swift
enum AppColors {
    // 盈亏色 — 使用语义化的系统色，自动适配 Light/Dark
    static let profit = Color(.systemGreen)        // #34C759
    static let loss = Color(.systemRed)            // #FF3B30
    static let neutral = Color(.secondaryLabel)

    // 强调色 — 用于主要操作按钮的 Glass Tint
    static let accent = Color.blue

    // 日历热力图 7 级渐变
    static func pnlColor(percent: Double) -> Color {
        switch percent {
        case ..<(-3):  return .red.opacity(1.0)         // 大亏
        case ..<(-1):  return .red.opacity(0.6)         // 中亏
        case ..<0:     return .red.opacity(0.3)         // 小亏
        case 0:        return .secondary.opacity(0.15)  // 持平 / 无数据
        case ..<1:     return .green.opacity(0.3)       // 小赚
        case ..<3:     return .green.opacity(0.6)       // 中赚
        default:       return .green.opacity(1.0)       // 大赚
        }
    }

    // 账户标识色 (用于区分不同券商)
    static let accountTags: [Color] = [.blue, .orange, .purple, .teal, .pink, .indigo]
}
```

### 排版系统

```swift
// 所有文字使用系统 Dynamic Type，确保辅助功能兼容
// 大数字 (总资产、盈亏金额)
.font(.system(.largeTitle, design: .rounded, weight: .bold))

// 卡片标题
.font(.headline)

// 辅助信息
.font(.subheadline)
.foregroundStyle(.secondary)

// 日历格子内数字
.font(.system(.caption2, design: .rounded, weight: .medium))
.monospacedDigit()  // 等宽数字，对齐更美观
```

### Liquid Glass 使用规范

```swift
// ✅ 导航层元素 — 用 Glass
NavigationBar    → 系统自动 Glass
TabBar           → 系统自动 Glass
浮动操作按钮      → .glassEffect(.regular.interactive())
弹窗/Sheet 操作栏 → .glassEffect()

// ✅ 信息卡片 — 用 Glass + 圆角
VStack { ... }
    .padding()
    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))

// ❌ 内容本身 — 不用 Glass
列表行     → 用普通背景
文字/图表  → 不加 Glass
日历格子   → 用纯色填充，不用 Glass (会视觉混乱)
```

### Liquid Glass API 速查

```swift
// 基础用法
.glassEffect()                                    // 默认: .regular + capsule
.glassEffect(.regular)                            // 标准玻璃
.glassEffect(.clear)                              // 更透明
.glassEffect(.identity)                           // 无效果 (用于辅助功能回退)

// 自定义形状
.glassEffect(.regular, in: .capsule)              // 胶囊 (默认)
.glassEffect(.regular, in: .circle)               // 圆形
.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))  // 圆角矩形
.glassEffect(.regular, in: .rect(cornerRadius: .containerConcentric))  // 自动匹配容器圆角

// 着色 (仅用于传达语义，不用于装饰)
.glassEffect(.regular.tint(.blue))                // 蓝色着色
.glassEffect(.regular.tint(.purple.opacity(0.6))) // 带透明度着色

// 交互式 (用于按钮等可点击元素，iOS only)
.glassEffect(.regular.interactive())              // 添加按压缩放/弹跳/闪光效果

// 容器 (将多个 Glass 元素合并为统一形状)
GlassEffectContainer {
    HStack(spacing: 20) {
        Button("A") { }.glassEffect(.regular.interactive())
        Button("B") { }.glassEffect(.regular.interactive())
    }
}

// 容器间距 (控制元素融合的距离阈值)
GlassEffectContainer(spacing: 40.0) { ... }

// 形态切换动画
@Namespace private var namespace
Button("Toggle") { withAnimation(.bouncy) { isExpanded.toggle() } }
    .glassEffect()
    .glassEffectID("toggle", in: namespace)

// 辅助功能适配
@Environment(\.accessibilityReduceTransparency) var reduceTransparency
.glassEffect(reduceTransparency ? .identity : .regular)
```

### 微交互动画 (让 App 感觉精品级)

```swift
// 1. 卡片点按反馈 (Scale + Haptic)
.scaleEffect(isPressed ? 0.97 : 1.0)
.animation(.snappy(duration: 0.15), value: isPressed)
.sensoryFeedback(.impact(flexibility: .soft), trigger: tapCount)

// 2. 数字变化动画 (盈亏数字平滑过渡)
Text(pnlAmount, format: .currency(code: "JPY"))
    .contentTransition(.numericText(value: pnlAmount))
    .animation(.snappy, value: pnlAmount)

// 3. 列表项出场 (交错弹入)
ForEach(Array(holdings.enumerated()), id: \.element.id) { index, holding in
    HoldingRow(holding: holding)
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .opacity
        ))
        .animation(.spring(response: 0.4, dampingFraction: 0.75)
            .delay(Double(index) * 0.05), value: holdings.count)
}

// 4. 日历月份切换 (左右滑动)
TabView(selection: $currentMonth) { ... }
    .tabViewStyle(.page(indexDisplayMode: .never))

// 5. 盈亏色变化 (渐变过渡)
.foregroundStyle(pnl >= 0 ? AppColors.profit : AppColors.loss)
.animation(.easeInOut(duration: 0.3), value: pnl)

// 6. 下拉刷新
.refreshable { await refreshPrices() }
```

### Glass 卡片组件 (通用)

```swift
struct GlassCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    var body: some View {
        content
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
    }
}

// 使用
GlassCard {
    VStack(alignment: .leading) {
        Text("总资产").font(.headline)
        Text("¥1,234,567")
            .font(.system(.largeTitle, design: .rounded, weight: .bold))
    }
}
```

### SF Symbols 图标对照表

| 功能 | Symbol Name |
|---|---|
| 总览 Tab | `chart.pie.fill` |
| 日历 Tab | `calendar` |
| 持仓 Tab | `list.bullet.rectangle.fill` |
| 分析 Tab | `chart.xyaxis.line` |
| 设置 Tab | `gearshape.fill` |
| 添加交易 | `plus.circle.fill` |
| 买入 | `arrow.down.circle.fill` |
| 卖出 | `arrow.up.circle.fill` |
| 分红 | `banknote.fill` |
| 盈利 | `arrow.up.right` |
| 亏损 | `arrow.down.right` |
| 分享 | `square.and.arrow.up` |
| 刷新 | `arrow.clockwise` |
| 搜索 | `magnifyingglass` |
| 账户 | `building.columns.fill` |
| NISA | `shield.checkered` |
| 贵金属 | `diamond.fill` |
| 加密 | `bitcoinsign.circle.fill` |

---

## 日历分享功能

### 分享卡片设计

用 SwiftUI `ImageRenderer` 渲染精美分享图:

```
┌─────────────────────────────────┐
│                                 │
│    📅 2026年 1月 投资月报          │
│                                 │
│  ┌─ 月历热力图 (7×5 格子) ──────┐ │
│  │ 日 一 二 三 四 五 六          │ │
│  │    🟩 🟥 🟩 🟩 🟩 ⬜        │ │
│  │ ...                         │ │
│  └─────────────────────────────┘ │
│                                 │
│  本月盈亏: +¥32,100 (+2.4%)     │
│  盈利天数: 14 / 亏损天数: 8       │
│  胜率: 63.6%                    │
│                                 │
│  ┌────────┐                     │
│  │ QR Code│ FolioForge          │
│  │        │ App Store 下载       │
│  └────────┘                     │
│                                 │
└─────────────────────────────────┘
```

### 实现方式

```swift
// 1. QR 码生成 (CoreImage)
func generateQRCode(from string: String) -> UIImage? {
    let filter = CIFilter.qrCodeGenerator()
    filter.message = Data(string.utf8)
    filter.correctionLevel = "M"
    guard let output = filter.outputImage else { return nil }
    let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
    return UIImage(ciImage: scaled)
}

// 2. 渲染分享图 (ImageRenderer)
let renderer = ImageRenderer(content: ShareCardView(month: month, snapshots: snapshots))
renderer.scale = UIScreen.main.scale  // Retina 分辨率
if let image = renderer.uiImage {
    // 弹出系统分享面板
}

// 3. 分享
ShareLink(item: image, preview: SharePreview("1月投资月报", image: image))
```

### 分享卡片视觉风格

- 背景: 深色渐变 (LinearGradient 从深灰到黑) — 截图在社交媒体上更醒目
- 日历格子: 圆角矩形 + 盈亏色填充
- 文字: 白色系, `.rounded` 字体
- QR 码: 右下角, 可自定义链接 (App Store 链接或自定义 URL)
- 尺寸: 1080×1920 (Instagram Story) 或 1080×1080 (方形)

---

## App 页面结构 (5 个 Tab)

### Tab 1: 总览 Dashboard
- 总资产 GlassCard (大字金额 + 今日盈亏)
- 今日各市场状态指示 (日股:收盘 / 美股:盘后 / A股:收盘)
- 资产配置环形图 (Swift Charts, 按资产类型着色)
- 各账户资产卡片 (横向滚动, 每个卡片显示账户名+金额+今日盈亏)
- 持仓涨跌幅 Top 5 快速预览

### Tab 2: 日历 Calendar ⭐核心
- **月历热力图**
  - 每个日期格子: 圆角矩形 + 7级盈亏色 + 日期数字
  - 点击日期 → Sheet 弹出当日详情 (各持仓涨跌明细)
  - 左右滑动切换月份 (PageTabViewStyle)
- **月度汇总条**: 本月盈亏 / 盈利天数 / 亏损天数 / 胜率
- **视图切换**: 月视图 ↔ 年度热力图 (Segmented Picker)
- **年度热力图**: GitHub 贡献图风格, 52 列 × 7 行
- **右上角分享按钮** → 生成精美分享图

### Tab 3: 持仓 Portfolio
- 按账户分组 (Section)
- 分组头: GlassCard 样式, 账户名 + 标识色 + 总值 + 今日盈亏
- 持仓行: 股票名/代码 + 持仓数量 + 现价 + 盈亏 + 盈亏%
- 美股行: 根据 marketState 显示盘前/盘后价格 + 闪烁指示
- 右上角 + 号 → 添加交易 Sheet
- 左滑: 编辑 / 删除
- 长按: 快捷操作菜单 (加仓/减仓/查看详情)
- 搜索栏: 快速筛选持仓

### Tab 4: 分析 Analytics
- 时间范围选择器 (1周/1月/3月/6月/1年/全部)
- 累计收益曲线 (折线图, 可叠加基准指数对比)
- 月度盈亏柱状图 (12 个月, 绿涨红跌)
- 各持仓盈亏贡献排行 (水平柱状图)
- 资产配置变化 (面积图, 展示各类资产占比随时间变化)

### Tab 5: 设置 Settings
- 基准货币选择 (JPY / CNY / USD)
- 账户管理 (增删改, 排序)
- iCloud 同步开关
- 数据导入 / 导出 (CSV)
- 外观 (跟随系统 / 始终深色 / 始终浅色)
- 通知设置 (盘前盘后提醒)
- 关于 & 反馈
- App Store 评分引导

---

## 小组件 (WidgetKit)

### Widget 1: 今日盈亏 (Small)
```
┌─────────────────┐
│  Glass 背景       │
│  📈 今日          │
│  +¥12,340       │  ← 大字, 绿/红
│  +1.23%         │
│                  │
│  总资产 ¥1.2M    │  ← 小字
└─────────────────┘
```

### Widget 2: 本周日历 (Medium)
```
┌──────────────────────────────┐
│  Glass 背景                    │
│  1月 第3周              +¥5,200│
│  ┌──┐┌──┐┌──┐┌──┐┌──┐       │
│  │月││火││水││木││金│       │
│  │🟩││🟥││🟩││🟩││⬜│       │
│  └──┘└──┘└──┘└──┘└──┘       │
│  +1.2 -0.5 +0.8 +2.1  --    │
└──────────────────────────────┘
```

### Widget 3: 月历概览 (Large)
```
┌──────────────────────────────┐
│  Glass 背景                    │
│     2026年 1月      +¥32,100  │
│  日 一 二 三 四 五 六          │
│  (7×5 日历格子, 盈亏色填充)     │
│                               │
│  胜率 63.6% | 盈14 亏8 平0    │
└──────────────────────────────┘
```

iOS 26 自动为 Widget 应用 Glass 效果 + accented rendering。

**数据共享:** App Group container + 共享 SwiftData ModelContainer
**刷新策略:** Timeline 按 1 小时间隔预填，交易时段更密集 (每日 40~70 次刷新限额)

---

## 项目结构

```
FolioForge/
├── FolioForgeApp.swift
├── ContentView.swift
│
├── Models/
│   ├── Portfolio.swift
│   ├── Holding.swift
│   ├── Transaction.swift
│   ├── DailySnapshot.swift
│   ├── PriceCache.swift
│   └── Enums.swift                  # AssetType, Market, TransactionType, MarketState
│
├── Services/
│   ├── MarketDataService.swift      # Yahoo Finance API (含盘前盘后)
│   ├── PnLCalculationService.swift  # 盈亏计算引擎
│   ├── CurrencyService.swift        # 汇率转换
│   ├── SnapshotService.swift        # 每日快照生成
│   └── ShareImageService.swift      # 分享图渲染 + QR码
│
├── Views/
│   ├── Dashboard/
│   │   ├── DashboardView.swift
│   │   ├── AssetSummaryCard.swift
│   │   ├── MarketStatusBar.swift    # 各市场开盘状态
│   │   ├── AllocationChart.swift
│   │   └── AccountCarousel.swift    # 账户卡片横向滚动
│   │
│   ├── Calendar/
│   │   ├── PnLCalendarView.swift
│   │   ├── CalendarMonthView.swift  # 单月视图
│   │   ├── CalendarDayCell.swift
│   │   ├── YearHeatmapView.swift
│   │   ├── DayDetailSheet.swift
│   │   ├── MonthStatsBar.swift
│   │   └── ShareCardView.swift      # 分享卡片视图
│   │
│   ├── Portfolio/
│   │   ├── PortfolioListView.swift
│   │   ├── AccountSection.swift
│   │   ├── HoldingRow.swift
│   │   ├── HoldingDetailView.swift
│   │   ├── AddTransactionView.swift
│   │   └── SymbolSearchView.swift
│   │
│   ├── Analytics/
│   │   ├── AnalyticsView.swift
│   │   ├── CumulativeChart.swift
│   │   ├── MonthlyBarChart.swift
│   │   └── RankingChart.swift
│   │
│   └── Settings/
│       ├── SettingsView.swift
│       └── AccountManageView.swift
│
├── Components/
│   ├── GlassCard.swift
│   ├── PnLText.swift                # 盈亏数字 (自动红绿+动画)
│   ├── MarketStateLabel.swift       # "盘前"/"盘后" 标签
│   └── LoadingShimmer.swift         # 加载骨架屏
│
├── DesignSystem/
│   ├── AppColors.swift              # 色彩系统
│   ├── AppFonts.swift               # 排版系统
│   └── Animations.swift             # 微交互动画定义
│
├── Extensions/
│   ├── Date+Extensions.swift
│   ├── Double+Currency.swift
│   └── Color+PnL.swift
│
├── FolioForgeWidget/                 # Widget Extension Target
│   ├── FolioForgeWidgetBundle.swift
│   ├── DailyPnLWidget.swift
│   ├── WeekCalendarWidget.swift
│   ├── MonthCalendarWidget.swift
│   └── WidgetDataProvider.swift
│
└── Resources/
    ├── Assets.xcassets
    └── Localizable.xcstrings        # 中文/日文/英文
```

---

## 开发阶段

### Phase 1: 基础框架 + 数据层
1. 创建 Xcode 项目 (iOS 26, SwiftUI, 含 Widget Extension Target)
2. 配置 App Group + CloudKit Entitlements
3. 定义 SwiftData 模型 (Portfolio, Holding, Transaction, DailySnapshot, PriceCache)
4. 实现 DesignSystem (AppColors, AppFonts, GlassCard 组件)
5. 实现 TabView 主框架 (5 个 Tab 的空壳 + Liquid Glass Tab Bar)
6. 实现账户管理 CRUD (设置页)

### Phase 2: 行情服务 + 持仓管理
7. 实现 MarketDataService (Yahoo Finance v8 历史K线)
8. 实现实时报价 (v7 quote, 含 preMarket/postMarket)
9. 实现 SymbolSearchView (Yahoo Finance search endpoint)
10. 实现 CurrencyService (汇率转换, 多币种折算)
11. 实现持仓列表页 + 添加交易 Sheet
12. 实现 HoldingRow (含美股盘前盘后状态显示)

### Phase 3: 盈亏计算 + 日历 ⭐核心
13. 实现 PnLCalculationService (每日盈亏 = 当日市值 - 前日市值 ± 当日买卖)
14. 实现 SnapshotService (每日快照生成/存储/历史回溯)
15. 实现 CalendarMonthView + CalendarDayCell (月历热力图)
16. 实现月份左右滑动切换
17. 实现 DayDetailSheet (日期详情弹窗)
18. 实现 MonthStatsBar (月度统计)
19. 实现 YearHeatmapView (年度 GitHub 风格热力图)

### Phase 4: 总览 + 分析
20. 实现 DashboardView (总资产卡片 + 今日盈亏)
21. 实现 MarketStatusBar (各市场开盘状态)
22. 实现 AllocationChart (资产配置环形图)
23. 实现 AccountCarousel (账户卡片横向滚动)
24. 实现 CumulativeChart (累计收益折线图)
25. 实现 MonthlyBarChart (月度盈亏柱状图)
26. 实现 RankingChart (持仓盈亏排行)

### Phase 5: 分享功能
27. 实现 ShareCardView (精美分享卡片 SwiftUI 视图)
28. 实现 QR 码生成 (CoreImage CIFilter)
29. 实现 ImageRenderer 渲染 + ShareLink 分享
30. 适配方形 (1080×1080) 和竖版 (1080×1920) 两种分享图

### Phase 6: 微交互 + 精品化
31. 全局应用 Liquid Glass 效果
32. 添加微交互动画 (卡片点按缩放、数字过渡、列表弹入)
33. 添加 Haptic 触觉反馈
34. 添加 LoadingShimmer 骨架屏
35. Light / Dark Mode 全面适配验证
36. 优化 Accessibility (VoiceOver, Dynamic Type)

### Phase 7: 小组件
37. 配置 Widget Extension + App Group 数据共享
38. 实现 WidgetDataProvider (从共享 ModelContainer 读取)
39. 实现 Small Widget (今日盈亏)
40. 实现 Medium Widget (本周日历)
41. 实现 Large Widget (月历概览)
42. 适配 iOS 26 Glass Widget 样式

### Phase 8: 上架准备
43. 多语言: 中文(简/繁) + 日文 + 英文
44. 数据导入/导出 (CSV 格式)
45. App Icon (推荐: 用 AI 生成工具或找设计师做一个)
46. App Store 截图 (Xcode Previews 截取 + Figma 套壳模板)
47. 编写 App Store 描述 (三语)
48. TestFlight 内测
49. 提交 App Store 审核

---

## 验证方式

1. **数据层**: 创建"楽天証券"和"招商证券"两个账户 → 各添加几个持仓 → 确认 SwiftData CRUD 和 iCloud 同步
2. **行情**: `7203.T` (丰田) + `600519.SS` (茅台) + `AAPL` (苹果) + `GC=F` (黄金) → 确认各市场行情正确
3. **美股盘前盘后**: 在美股盘前/盘后时段打开 App → 确认显示 preMarket/postMarket 价格和状态标签
4. **盈亏计算**: 手动验算某日盈亏 → 与 App 计算对比
5. **日历**: 累积一周真实数据 → 验证日历热力图颜色和数值
6. **分享图**: 点击分享 → 检查渲染图的清晰度、排版、QR 码可扫描性
7. **小组件**: 在主屏添加三种尺寸 → 确认数据正确和自动刷新
8. **多设备同步**: iPhone + iPad 同一 iCloud → 确认数据双向同步

---

## 参考资源

- [Apple: Build a SwiftUI app with the new design (WWDC25 Session 323)](https://developer.apple.com/videos/play/wwdc2025/323/)
- [Apple: Applying Liquid Glass to custom views](https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views)
- [Liquid Glass SwiftUI Reference (GitHub)](https://github.com/conorluddy/LiquidGlassReference)
- [iOS 26 WidgetKit Guide](https://dev.to/arshtechpro/wwdc-2025-widgetkit-in-ios-26-a-complete-guide-to-modern-widget-development-1cjp)
- [Micro-Interactions in SwiftUI](https://dev.to/sebastienlato/micro-interactions-in-swiftui-subtle-animations-that-make-apps-feel-premium-2ldn)
- [SwiftYFinance (Swift Yahoo Finance Library)](https://github.com/alexdremov/SwiftYFinance)
- [QRCode Swift Library](https://github.com/dagronf/QRCode)
- [Using SwiftData Transaction History to Update Widgets](https://zekesnider.com/swift-data-transction-history/)
