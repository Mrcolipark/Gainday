import SwiftUI
import WidgetKit

/// 语言管理器 - 管理应用语言切换
@Observable
final class LanguageManager {
    static let shared = LanguageManager()

    /// App Group identifier for sharing data between main app and widgets
    private static let appGroupIdentifier = "group.com.gainday.shared"

    /// Shared UserDefaults for App Group
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: Self.appGroupIdentifier)
    }

    /// 当前语言设置: "system", "zh-Hans", "zh-Hant", "en", "ja"
    var language: String {
        didSet {
            UserDefaults.standard.set(language, forKey: "appLanguage")
            // Also save to shared UserDefaults for widgets
            sharedDefaults?.set(language, forKey: "appLanguage")
            applyLanguage()
            // Reload widgets to reflect language change
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// 返回对应的 Locale，nil 表示跟随系统
    var locale: Locale? {
        switch language {
        case "zh-Hans": return Locale(identifier: "zh-Hans")
        case "zh-Hant": return Locale(identifier: "zh-Hant")
        case "en": return Locale(identifier: "en")
        case "ja": return Locale(identifier: "ja")
        default: return nil  // 跟随系统
        }
    }

    /// 当前语言显示名称
    var displayName: String {
        switch language {
        case "zh-Hans": return "简体中文"
        case "zh-Hant": return "繁體中文"
        case "en": return "English"
        case "ja": return "日本語"
        default: return "跟随系统"
        }
    }

    /// 当前实际使用的语言代码
    var effectiveLanguage: String {
        if language == "system" {
            let preferred = Locale.preferredLanguages.first ?? "en"
            if preferred.hasPrefix("zh-Hans") || preferred.hasPrefix("zh-CN") {
                return "zh-Hans"
            } else if preferred.hasPrefix("zh-Hant") || preferred.hasPrefix("zh-TW") || preferred.hasPrefix("zh-HK") {
                return "zh-Hant"
            } else if preferred.hasPrefix("ja") {
                return "ja"
            } else {
                return "en"
            }
        }
        return language
    }

    private init() {
        let savedLanguage = UserDefaults.standard.string(forKey: "appLanguage") ?? "system"
        self.language = savedLanguage
        // Sync to shared UserDefaults for widgets
        UserDefaults(suiteName: Self.appGroupIdentifier)?.set(savedLanguage, forKey: "appLanguage")
    }

    func applyLanguage() {
        // 强制刷新 UI
        NotificationCenter.default.post(name: .languageDidChange, object: nil)
    }

    /// 获取本地化字符串
    func localized(_ key: String) -> String {
        return Self.strings[key]?[effectiveLanguage] ?? key
    }

    // MARK: - 翻译字典

    private static let strings: [String: [String: String]] = [
        // Tab Bar
        "首页": ["zh-Hans": "首页", "zh-Hant": "首頁", "en": "Home", "ja": "ホーム"],
        "日历": ["zh-Hans": "日历", "zh-Hant": "日曆", "en": "Calendar", "ja": "カレンダー"],
        "市场": ["zh-Hans": "市场", "zh-Hant": "市場", "en": "Markets", "ja": "マーケット"],
        "资讯": ["zh-Hans": "资讯", "zh-Hant": "資訊", "en": "News", "ja": "ニュース"],

        // Settings
        "设置": ["zh-Hans": "设置", "zh-Hant": "設定", "en": "Settings", "ja": "設定"],
        "完成": ["zh-Hans": "完成", "zh-Hant": "完成", "en": "Done", "ja": "完了"],
        "外观": ["zh-Hans": "外观", "zh-Hant": "外觀", "en": "Appearance", "ja": "外観"],
        "主题": ["zh-Hans": "主题", "zh-Hant": "主題", "en": "Theme", "ja": "テーマ"],
        "语言": ["zh-Hans": "语言", "zh-Hant": "語言", "en": "Language", "ja": "言語"],
        "跟随系统": ["zh-Hans": "跟随系统", "zh-Hant": "跟隨系統", "en": "System", "ja": "システム"],
        "浅色": ["zh-Hans": "浅色", "zh-Hant": "淺色", "en": "Light", "ja": "ライト"],
        "深色": ["zh-Hans": "深色", "zh-Hant": "深色", "en": "Dark", "ja": "ダーク"],

        // Settings - Currency
        "基准货币": ["zh-Hans": "基准货币", "zh-Hant": "基準貨幣", "en": "Base Currency", "ja": "基準通貨"],

        // Settings - Accounts
        "账户管理": ["zh-Hans": "账户管理", "zh-Hant": "帳戶管理", "en": "Accounts", "ja": "口座管理"],
        "添加账户": ["zh-Hans": "添加账户", "zh-Hant": "新增帳戶", "en": "Add Account", "ja": "口座を追加"],
        "持仓": ["zh-Hans": "持仓", "zh-Hant": "持倉", "en": "Holdings", "ja": "保有"],
        "账户名称": ["zh-Hans": "账户名称", "zh-Hant": "帳戶名稱", "en": "Account Name", "ja": "口座名"],
        "账户类型": ["zh-Hans": "账户类型", "zh-Hant": "帳戶類型", "en": "Account Type", "ja": "口座タイプ"],
        "标识颜色": ["zh-Hans": "标识颜色", "zh-Hant": "標識顏色", "en": "Tag Color", "ja": "タグカラー"],
        "保存账户": ["zh-Hans": "保存账户", "zh-Hant": "儲存帳戶", "en": "Save Account", "ja": "口座を保存"],
        "删除账户": ["zh-Hans": "删除账户", "zh-Hant": "刪除帳戶", "en": "Delete Account", "ja": "口座を削除"],
        "将永久删除该账户及所有数据": ["zh-Hans": "将永久删除该账户及所有数据", "zh-Hant": "將永久刪除該帳戶及所有資料", "en": "This will permanently delete the account and all data", "ja": "このアカウントとすべてのデータが永久に削除されます"],
        "危险操作": ["zh-Hans": "危险操作", "zh-Hant": "危險操作", "en": "Danger Zone", "ja": "危険な操作"],
        "暂无持仓": ["zh-Hans": "暂无持仓", "zh-Hant": "暫無持倉", "en": "No Holdings", "ja": "保有なし"],
        "暂无标的": ["zh-Hans": "暂无标的", "zh-Hant": "暫無標的", "en": "No Watchlist", "ja": "ウォッチリストなし"],
        "添加持仓": ["zh-Hans": "添加持仓", "zh-Hant": "新增持倉", "en": "Add Holding", "ja": "保有を追加"],
        "在主页添加标的后会显示在这里": ["zh-Hans": "在主页添加标的后会显示在这里", "zh-Hant": "在首頁新增標的後會顯示在這裡", "en": "Add holdings from the home page", "ja": "ホームで銘柄を追加すると表示されます"],
        "笔交易": ["zh-Hans": "笔交易", "zh-Hant": "筆交易", "en": "transactions", "ja": "件の取引"],
        "账户信息": ["zh-Hans": "账户信息", "zh-Hant": "帳戶資訊", "en": "Account Info", "ja": "口座情報"],
        "如: 楽天証券、富途牛牛": ["zh-Hans": "如: 楽天証券、富途牛牛", "zh-Hant": "如: 楽天証券、富途牛牛", "en": "e.g. Rakuten, Futu", "ja": "例: 楽天証券、SBI証券"],
        "GainDay 盈历": ["zh-Hans": "GainDay 盈历", "zh-Hant": "GainDay 盈曆", "en": "GainDay", "ja": "GainDay"],

        // Settings - Sync
        "数据同步": ["zh-Hans": "数据同步", "zh-Hant": "資料同步", "en": "Data Sync", "ja": "データ同期"],
        "iCloud 同步": ["zh-Hans": "iCloud 同步", "zh-Hant": "iCloud 同步", "en": "iCloud Sync", "ja": "iCloud 同期"],

        // Settings - Data
        "数据管理": ["zh-Hans": "数据管理", "zh-Hant": "資料管理", "en": "Data Management", "ja": "データ管理"],
        "导出数据 (CSV)": ["zh-Hans": "导出数据 (CSV)", "zh-Hant": "匯出資料 (CSV)", "en": "Export Data (CSV)", "ja": "データをエクスポート (CSV)"],
        "导入数据 (CSV)": ["zh-Hans": "导入数据 (CSV)", "zh-Hant": "匯入資料 (CSV)", "en": "Import Data (CSV)", "ja": "データをインポート (CSV)"],
        "导入完成": ["zh-Hans": "导入完成", "zh-Hant": "匯入完成", "en": "Import Complete", "ja": "インポート完了"],
        "确认删除": ["zh-Hans": "确认删除", "zh-Hant": "確認刪除", "en": "Confirm Delete", "ja": "削除確認"],

        // Settings - About
        "关于": ["zh-Hans": "关于", "zh-Hant": "關於", "en": "About", "ja": "このアプリについて"],
        "App 名称": ["zh-Hans": "App 名称", "zh-Hant": "App 名稱", "en": "App Name", "ja": "アプリ名"],
        "版本": ["zh-Hans": "版本", "zh-Hant": "版本", "en": "Version", "ja": "バージョン"],
        "反馈与建议": ["zh-Hans": "反馈与建议", "zh-Hant": "回饋與建議", "en": "Feedback", "ja": "フィードバック"],
        "开发者选项": ["zh-Hans": "开发者选项", "zh-Hant": "開發者選項", "en": "Developer Options", "ja": "開発者オプション"],

        // Home
        "盈历": ["zh-Hans": "盈历", "zh-Hant": "盈曆", "en": "GainDay", "ja": "GainDay"],
        "投资组合": ["zh-Hans": "投资组合", "zh-Hant": "投資組合", "en": "Portfolio", "ja": "ポートフォリオ"],
        "今日": ["zh-Hans": "今日", "zh-Hant": "今日", "en": "Today", "ja": "今日"],
        "总盈亏": ["zh-Hans": "总盈亏", "zh-Hant": "總盈虧", "en": "Total P&L", "ja": "総損益"],
        "开始您的投资之旅": ["zh-Hans": "开始您的投资之旅", "zh-Hant": "開始您的投資之旅", "en": "Start Your Investment Journey", "ja": "投資の旅を始めましょう"],
        "在设置中添加您的第一个账户": ["zh-Hans": "在设置中添加您的第一个账户", "zh-Hant": "在設定中新增您的第一個帳戶", "en": "Add your first account in Settings", "ja": "設定で最初の口座を追加してください"],
        "月度盈亏": ["zh-Hans": "月度盈亏", "zh-Hant": "月度盈虧", "en": "Monthly P&L", "ja": "月間損益"],
        "累计盈亏": ["zh-Hans": "累计盈亏", "zh-Hant": "累計盈虧", "en": "Cumulative P&L", "ja": "累計損益"],

        // Calendar
        "月视图": ["zh-Hans": "月视图", "zh-Hant": "月檢視", "en": "Month", "ja": "月表示"],
        "年视图": ["zh-Hans": "年视图", "zh-Hant": "年檢視", "en": "Year", "ja": "年表示"],
        "全部": ["zh-Hans": "全部", "zh-Hant": "全部", "en": "All", "ja": "すべて"],
        "月度收益": ["zh-Hans": "月度收益", "zh-Hant": "月度收益", "en": "Monthly Return", "ja": "月間リターン"],
        "月度汇总": ["zh-Hans": "月度汇总", "zh-Hant": "月度匯總", "en": "Monthly Summary", "ja": "月間サマリー"],
        "分享": ["zh-Hans": "分享", "zh-Hant": "分享", "en": "Share", "ja": "共有"],
        "分享月报": ["zh-Hans": "分享月报", "zh-Hant": "分享月報", "en": "Share Monthly Report", "ja": "月次レポートを共有"],
        "年度统计": ["zh-Hans": "年度统计", "zh-Hant": "年度統計", "en": "Annual Stats", "ja": "年間統計"],
        "年度收益": ["zh-Hans": "年度收益", "zh-Hant": "年度收益", "en": "Annual Return", "ja": "年間リターン"],
        "投资热力图": ["zh-Hans": "投资热力图", "zh-Hant": "投資熱力圖", "en": "Heatmap", "ja": "ヒートマップ"],
        "亏损": ["zh-Hans": "亏损", "zh-Hant": "虧損", "en": "Loss", "ja": "損失"],
        "盈利": ["zh-Hans": "盈利", "zh-Hant": "盈利", "en": "Profit", "ja": "利益"],
        "无数据": ["zh-Hans": "无数据", "zh-Hant": "無資料", "en": "No Data", "ja": "データなし"],

        // Day Detail
        "当日盈亏": ["zh-Hans": "当日盈亏", "zh-Hant": "當日盈虧", "en": "Daily P&L", "ja": "当日損益"],
        "持仓价值": ["zh-Hans": "持仓价值", "zh-Hant": "持倉價值", "en": "Market Value", "ja": "評価額"],
        "持仓成本": ["zh-Hans": "持仓成本", "zh-Hant": "持倉成本", "en": "Cost Basis", "ja": "取得コスト"],
        "收益率": ["zh-Hans": "收益率", "zh-Hant": "收益率", "en": "Return", "ja": "リターン"],
        "累计": ["zh-Hans": "累计", "zh-Hant": "累計", "en": "Cumulative", "ja": "累計"],
        "与前一日对比": ["zh-Hans": "与前一日对比", "zh-Hant": "與前一日對比", "en": "vs Previous Day", "ja": "前日比"],
        "价值变化": ["zh-Hans": "价值变化", "zh-Hant": "價值變化", "en": "Value Change", "ja": "評価額変動"],
        "盈亏变化": ["zh-Hans": "盈亏变化", "zh-Hant": "盈虧變化", "en": "P&L Change", "ja": "損益変動"],
        "近7日趋势": ["zh-Hans": "近7日趋势", "zh-Hant": "近7日趨勢", "en": "7-Day Trend", "ja": "7日間推移"],
        "周盈亏": ["zh-Hans": "周盈亏", "zh-Hant": "週盈虧", "en": "Weekly P&L", "ja": "週間損益"],
        "当日波动最大": ["zh-Hans": "当日波动最大", "zh-Hant": "當日波動最大", "en": "Top Movers", "ja": "当日の変動トップ"],
        "账户明细": ["zh-Hans": "账户明细", "zh-Hant": "帳戶明細", "en": "Account Details", "ja": "口座明細"],
        "暂无账户数据": ["zh-Hans": "暂无账户数据", "zh-Hant": "暫無帳戶資料", "en": "No Account Data", "ja": "口座データなし"],
        "该日无数据": ["zh-Hans": "该日无数据", "zh-Hant": "該日無資料", "en": "No Data for This Day", "ja": "この日のデータなし"],
        "持仓数据在交易日收盘后自动生成": ["zh-Hans": "持仓数据在交易日收盘后自动生成", "zh-Hant": "持倉資料在交易日收盤後自動生成", "en": "Data is generated after market close", "ja": "データは取引終了後に自動生成されます"],

        // Markets
        "市场状态": ["zh-Hans": "市场状态", "zh-Hant": "市場狀態", "en": "Market Status", "ja": "市場ステータス"],
        "盘前": ["zh-Hans": "盘前", "zh-Hant": "盤前", "en": "Pre", "ja": "プレ"],
        "交易中": ["zh-Hans": "交易中", "zh-Hant": "交易中", "en": "Open", "ja": "取引中"],
        "盘后": ["zh-Hans": "盘后", "zh-Hant": "盤後", "en": "Post", "ja": "アフター"],
        "收盘": ["zh-Hans": "收盘", "zh-Hant": "收盤", "en": "Closed", "ja": "終了"],

        // Market Abbreviations
        "美": ["zh-Hans": "美", "zh-Hant": "美", "en": "US", "ja": "米"],
        "中": ["zh-Hans": "中", "zh-Hant": "中", "en": "CN", "ja": "中"],
        "港": ["zh-Hans": "港", "zh-Hant": "港", "en": "HK", "ja": "港"],
        "日": ["zh-Hans": "日", "zh-Hant": "日", "en": "JP", "ja": "日"],
        "搜索标的": ["zh-Hans": "搜索标的", "zh-Hant": "搜尋標的", "en": "Search", "ja": "検索"],
        "添加标的": ["zh-Hans": "添加标的", "zh-Hant": "新增標的", "en": "Add Symbol", "ja": "銘柄を追加"],
        "涨幅榜": ["zh-Hans": "涨幅榜", "zh-Hant": "漲幅榜", "en": "Gainers", "ja": "上昇率"],
        "跌幅榜": ["zh-Hans": "跌幅榜", "zh-Hant": "跌幅榜", "en": "Losers", "ja": "下落率"],
        "成交额": ["zh-Hans": "成交额", "zh-Hant": "成交額", "en": "Volume", "ja": "出来高"],
        "全球指数": ["zh-Hans": "全球指数", "zh-Hant": "全球指數", "en": "Global Indices", "ja": "グローバル指数"],
        "板块热力图": ["zh-Hans": "板块热力图", "zh-Hant": "板塊熱力圖", "en": "Sectors", "ja": "セクター"],

        // Sector Names - US
        "科技": ["zh-Hans": "科技", "zh-Hant": "科技", "en": "Tech", "ja": "テック"],
        "金融": ["zh-Hans": "金融", "zh-Hant": "金融", "en": "Finance", "ja": "金融"],
        "医疗": ["zh-Hans": "医疗", "zh-Hant": "醫療", "en": "Health", "ja": "医療"],
        "能源": ["zh-Hans": "能源", "zh-Hant": "能源", "en": "Energy", "ja": "エネ"],
        "消费": ["zh-Hans": "消费", "zh-Hant": "消費", "en": "Consumer", "ja": "消費"],
        "工业": ["zh-Hans": "工业", "zh-Hant": "工業", "en": "Industrial", "ja": "工業"],
        "材料": ["zh-Hans": "材料", "zh-Hant": "材料", "en": "Materials", "ja": "素材"],
        "地产": ["zh-Hans": "地产", "zh-Hant": "地產", "en": "Real Estate", "ja": "不動産"],
        "通讯": ["zh-Hans": "通讯", "zh-Hant": "通訊", "en": "Telecom", "ja": "通信"],
        "公用": ["zh-Hans": "公用", "zh-Hant": "公用", "en": "Utilities", "ja": "公益"],
        "必需品": ["zh-Hans": "必需品", "zh-Hant": "必需品", "en": "Staples", "ja": "生活"],

        // Sector Names - China
        "半导体": ["zh-Hans": "半导体", "zh-Hant": "半導體", "en": "Semicon", "ja": "半導体"],
        "军工": ["zh-Hans": "军工", "zh-Hant": "軍工", "en": "Defense", "ja": "防衛"],
        "银行": ["zh-Hans": "银行", "zh-Hant": "銀行", "en": "Banks", "ja": "銀行"],
        "券商": ["zh-Hans": "券商", "zh-Hant": "券商", "en": "Brokers", "ja": "証券"],
        "医药": ["zh-Hans": "医药", "zh-Hant": "醫藥", "en": "Pharma", "ja": "製薬"],
        "证券": ["zh-Hans": "证券", "zh-Hant": "證券", "en": "Securities", "ja": "証券"],
        "新能车": ["zh-Hans": "新能车", "zh-Hant": "新能車", "en": "EV", "ja": "EV"],
        "新能源": ["zh-Hans": "新能源", "zh-Hant": "新能源", "en": "Clean Energy", "ja": "新エネ"],
        "有色": ["zh-Hans": "有色", "zh-Hant": "有色", "en": "Metals", "ja": "非鉄"],
        "白酒": ["zh-Hans": "白酒", "zh-Hant": "白酒", "en": "Liquor", "ja": "白酒"],
        "光伏": ["zh-Hans": "光伏", "zh-Hant": "光伏", "en": "Solar", "ja": "太陽光"],

        // Sector Names - HK
        "盈富": ["zh-Hans": "盈富", "zh-Hant": "盈富", "en": "Tracker", "ja": "盈富"],
        "恒中企": ["zh-Hans": "恒中企", "zh-Hant": "恆中企", "en": "H-Shares", "ja": "H株"],
        "恒科技": ["zh-Hans": "恒科技", "zh-Hant": "恆科技", "en": "HSI Tech", "ja": "科技"],
        "南方科技": ["zh-Hans": "南方科技", "zh-Hant": "南方科技", "en": "CSI Tech", "ja": "南方"],
        "A50": ["zh-Hans": "A50", "zh-Hant": "A50", "en": "A50", "ja": "A50"],
        "华夏300": ["zh-Hans": "华夏300", "zh-Hant": "華夏300", "en": "CSI 300", "ja": "CSI300"],

        // Sector Names - Japan
        "食品": ["zh-Hans": "食品", "zh-Hant": "食品", "en": "Food", "ja": "食品"],
        "建筑": ["zh-Hans": "建筑", "zh-Hant": "建築", "en": "Construct", "ja": "建設"],
        "汽车": ["zh-Hans": "汽车", "zh-Hant": "汽車", "en": "Auto", "ja": "自動車"],
        "运输": ["zh-Hans": "运输", "zh-Hant": "運輸", "en": "Transport", "ja": "運輸"],
        "商社": ["zh-Hans": "商社", "zh-Hant": "商社", "en": "Trading", "ja": "商社"],
        "零售": ["zh-Hans": "零售", "zh-Hant": "零售", "en": "Retail", "ja": "小売"],
        "电力": ["zh-Hans": "电力", "zh-Hant": "電力", "en": "Power", "ja": "電力"],

        "市场热门": ["zh-Hans": "市场热门", "zh-Hant": "市場熱門", "en": "Market Movers", "ja": "注目銘柄"],
        "开盘": ["zh-Hans": "开盘", "zh-Hant": "開盤", "en": "Open", "ja": "始値"],
        "昨收": ["zh-Hans": "昨收", "zh-Hant": "昨收", "en": "Prev Close", "ja": "前日終値"],
        "最高": ["zh-Hans": "最高", "zh-Hant": "最高", "en": "High", "ja": "高値"],
        "最低": ["zh-Hans": "最低", "zh-Hant": "最低", "en": "Low", "ja": "安値"],
        "成交量": ["zh-Hans": "成交量", "zh-Hant": "成交量", "en": "Volume", "ja": "出来高"],
        "市值": ["zh-Hans": "市值", "zh-Hant": "市值", "en": "Market Cap", "ja": "時価総額"],
        "市盈率 (TTM)": ["zh-Hans": "市盈率 (TTM)", "zh-Hant": "市盈率 (TTM)", "en": "P/E (TTM)", "ja": "PER (TTM)"],
        "每股收益": ["zh-Hans": "每股收益", "zh-Hant": "每股收益", "en": "EPS", "ja": "EPS"],
        "股息率": ["zh-Hans": "股息率", "zh-Hant": "股息率", "en": "Dividend Yield", "ja": "配当利回り"],
        "52周最高": ["zh-Hans": "52周最高", "zh-Hant": "52週最高", "en": "52W High", "ja": "52週高値"],
        "52周最低": ["zh-Hans": "52周最低", "zh-Hant": "52週最低", "en": "52W Low", "ja": "52週安値"],
        "暂无图表数据": ["zh-Hans": "暂无图表数据", "zh-Hant": "暫無圖表資料", "en": "No Chart Data", "ja": "チャートデータなし"],

        // News
        "市场快讯": ["zh-Hans": "市场快讯", "zh-Hant": "市場快訊", "en": "Market Flash", "ja": "マーケット速報"],
        "热门新闻": ["zh-Hans": "热门新闻", "zh-Hant": "熱門新聞", "en": "Top News", "ja": "トップニュース"],
        "美股": ["zh-Hans": "美股", "zh-Hant": "美股", "en": "US", "ja": "米国"],
        "A股": ["zh-Hans": "A股", "zh-Hant": "A股", "en": "China", "ja": "中国"],
        "港股": ["zh-Hans": "港股", "zh-Hant": "港股", "en": "HK", "ja": "香港"],
        "日股": ["zh-Hans": "日股", "zh-Hant": "日股", "en": "Japan", "ja": "日本"],
        "加载中": ["zh-Hans": "加载中", "zh-Hant": "載入中", "en": "Loading", "ja": "読み込み中"],
        "实时": ["zh-Hans": "实时", "zh-Hant": "即時", "en": "Live", "ja": "リアルタイム"],
        "财经要闻": ["zh-Hans": "财经要闻", "zh-Hant": "財經要聞", "en": "Financial News", "ja": "金融ニュース"],
        "更多来源": ["zh-Hans": "更多来源", "zh-Hant": "更多來源", "en": "More Sources", "ja": "その他のソース"],
        "阅读全文": ["zh-Hans": "阅读全文", "zh-Hant": "閱讀全文", "en": "Read More", "ja": "続きを読む"],

        // Transactions
        "添加交易": ["zh-Hans": "添加交易", "zh-Hant": "新增交易", "en": "Add Transaction", "ja": "取引を追加"],
        "选择账户": ["zh-Hans": "选择账户", "zh-Hant": "選擇帳戶", "en": "Select Account", "ja": "口座を選択"],
        "交易类型": ["zh-Hans": "交易类型", "zh-Hant": "交易類型", "en": "Transaction Type", "ja": "取引タイプ"],
        "买入": ["zh-Hans": "买入", "zh-Hant": "買入", "en": "Buy", "ja": "買い"],
        "卖出": ["zh-Hans": "卖出", "zh-Hant": "賣出", "en": "Sell", "ja": "売り"],
        "分红": ["zh-Hans": "分红", "zh-Hant": "分紅", "en": "Dividend", "ja": "配当"],
        "标的信息": ["zh-Hans": "标的信息", "zh-Hant": "標的資訊", "en": "Symbol Info", "ja": "銘柄情報"],
        "投资详情": ["zh-Hans": "投资详情", "zh-Hant": "投資詳情", "en": "Investment Details", "ja": "投資詳細"],
        "交易详情": ["zh-Hans": "交易详情", "zh-Hant": "交易詳情", "en": "Transaction Details", "ja": "取引詳細"],
        "汇总": ["zh-Hans": "汇总", "zh-Hant": "匯總", "en": "Summary", "ja": "サマリー"],
        "保存交易": ["zh-Hans": "保存交易", "zh-Hant": "儲存交易", "en": "Save Transaction", "ja": "取引を保存"],

        // Components
        "上涨": ["zh-Hans": "上涨", "zh-Hant": "上漲", "en": "Up", "ja": "上昇"],
        "下跌": ["zh-Hans": "下跌", "zh-Hant": "下跌", "en": "Down", "ja": "下落"],
        "横盘": ["zh-Hans": "横盘", "zh-Hant": "橫盤", "en": "Flat", "ja": "横ばい"],
        "加载失败": ["zh-Hans": "加载失败", "zh-Hant": "載入失敗", "en": "Load Failed", "ja": "読み込み失敗"],
        "重试": ["zh-Hans": "重试", "zh-Hant": "重試", "en": "Retry", "ja": "再試行"],

        // Common
        "取消": ["zh-Hans": "取消", "zh-Hant": "取消", "en": "Cancel", "ja": "キャンセル"],
        "确定": ["zh-Hans": "确定", "zh-Hant": "確定", "en": "OK", "ja": "OK"],
        "删除": ["zh-Hans": "删除", "zh-Hant": "刪除", "en": "Delete", "ja": "削除"],
        "保存": ["zh-Hans": "保存", "zh-Hant": "儲存", "en": "Save", "ja": "保存"],
        "编辑": ["zh-Hans": "编辑", "zh-Hant": "編輯", "en": "Edit", "ja": "編集"],
        "更多": ["zh-Hans": "更多", "zh-Hant": "更多", "en": "More", "ja": "もっと見る"],

        // Holding Detail
        "概览": ["zh-Hans": "概览", "zh-Hant": "概覽", "en": "Summary", "ja": "概要"],
        "交易记录": ["zh-Hans": "交易记录", "zh-Hant": "交易紀錄", "en": "Transactions", "ja": "取引履歴"],
        "市盈率": ["zh-Hans": "市盈率", "zh-Hant": "市盈率", "en": "P/E", "ja": "PER"],

        // Month Stats
        "胜率": ["zh-Hans": "胜率", "zh-Hant": "勝率", "en": "Win Rate", "ja": "勝率"],
        "日均": ["zh-Hans": "日均", "zh-Hant": "日均", "en": "Daily Avg", "ja": "日平均"],
        "天": ["zh-Hans": "天", "zh-Hant": "天", "en": " days", "ja": "日"],

        // Year Heatmap / Stats
        "年度": ["zh-Hans": "年度", "zh-Hant": "年度", "en": "Annual", "ja": "年度"],
        "盈利天数": ["zh-Hans": "盈利天数", "zh-Hant": "盈利天數", "en": "Profit Days", "ja": "利益日数"],
        "亏损天数": ["zh-Hans": "亏损天数", "zh-Hant": "虧損天數", "en": "Loss Days", "ja": "損失日数"],
        "交易天数": ["zh-Hans": "交易天数", "zh-Hant": "交易天數", "en": "Trading Days", "ja": "取引日数"],
        "最大盈利": ["zh-Hans": "最大盈利", "zh-Hant": "最大盈利", "en": "Max Profit", "ja": "最大利益"],
        "最大亏损": ["zh-Hans": "最大亏损", "zh-Hant": "最大虧損", "en": "Max Loss", "ja": "最大損失"],

        // Weekday Labels (note: "日" for Sunday conflicts with Market Abbreviation "日" for Japan - use "周日" instead)
        "周日": ["zh-Hans": "日", "zh-Hant": "日", "en": "S", "ja": "日"],
        "一": ["zh-Hans": "一", "zh-Hant": "一", "en": "M", "ja": "月"],
        "二": ["zh-Hans": "二", "zh-Hant": "二", "en": "T", "ja": "火"],
        "三": ["zh-Hans": "三", "zh-Hant": "三", "en": "W", "ja": "水"],
        "四": ["zh-Hans": "四", "zh-Hant": "四", "en": "T", "ja": "木"],
        "五": ["zh-Hans": "五", "zh-Hant": "五", "en": "F", "ja": "金"],
        "六": ["zh-Hans": "六", "zh-Hant": "六", "en": "S", "ja": "土"],

        // Month Labels
        "1月": ["zh-Hans": "1月", "zh-Hant": "1月", "en": "Jan", "ja": "1月"],
        "2月": ["zh-Hans": "2月", "zh-Hant": "2月", "en": "Feb", "ja": "2月"],
        "3月": ["zh-Hans": "3月", "zh-Hant": "3月", "en": "Mar", "ja": "3月"],
        "4月": ["zh-Hans": "4月", "zh-Hant": "4月", "en": "Apr", "ja": "4月"],
        "5月": ["zh-Hans": "5月", "zh-Hant": "5月", "en": "May", "ja": "5月"],
        "6月": ["zh-Hans": "6月", "zh-Hant": "6月", "en": "Jun", "ja": "6月"],
        "7月": ["zh-Hans": "7月", "zh-Hant": "7月", "en": "Jul", "ja": "7月"],
        "8月": ["zh-Hans": "8月", "zh-Hant": "8月", "en": "Aug", "ja": "8月"],
        "9月": ["zh-Hans": "9月", "zh-Hant": "9月", "en": "Sep", "ja": "9月"],
        "10月": ["zh-Hans": "10月", "zh-Hant": "10月", "en": "Oct", "ja": "10月"],
        "11月": ["zh-Hans": "11月", "zh-Hant": "11月", "en": "Nov", "ja": "11月"],
        "12月": ["zh-Hans": "12月", "zh-Hant": "12月", "en": "Dec", "ja": "12月"],

        // Share Card
        "投资月报": ["zh-Hans": "投资月报", "zh-Hant": "投資月報", "en": "Monthly Report", "ja": "月次レポート"],
        "投资年报": ["zh-Hans": "投资年报", "zh-Hant": "投資年報", "en": "Annual Report", "ja": "年次レポート"],
        "本月盈亏": ["zh-Hans": "本月盈亏", "zh-Hant": "本月盈虧", "en": "Monthly P&L", "ja": "月間損益"],
        "年度盈亏": ["zh-Hans": "年度盈亏", "zh-Hant": "年度盈虧", "en": "Annual P&L", "ja": "年間損益"],
        "交易统计": ["zh-Hans": "交易统计", "zh-Hant": "交易統計", "en": "Trading Stats", "ja": "取引統計"],
        "上半年": ["zh-Hans": "上半年", "zh-Hant": "上半年", "en": "H1", "ja": "上半期"],
        "下半年": ["zh-Hans": "下半年", "zh-Hant": "下半年", "en": "H2", "ja": "下半期"],
        "盈历 - 投资日历": ["zh-Hans": "盈历 - 投资日历", "zh-Hant": "盈曆 - 投資日曆", "en": "GainDay - Investment Calendar", "ja": "GainDay - 投資カレンダー"],

        // Expandable Holding Row / Inline Form
        "删除交易？": ["zh-Hans": "删除交易？", "zh-Hant": "刪除交易？", "en": "Delete Transaction?", "ja": "取引を削除しますか？"],
        "此操作无法撤销。": ["zh-Hans": "此操作无法撤销。", "zh-Hant": "此操作無法撤銷。", "en": "This action cannot be undone.", "ja": "この操作は取り消せません。"],
        "暂无交易记录": ["zh-Hans": "暂无交易记录", "zh-Hant": "暫無交易紀錄", "en": "No Transactions", "ja": "取引履歴なし"],
        "编辑交易": ["zh-Hans": "编辑交易", "zh-Hant": "編輯交易", "en": "Edit Transaction", "ja": "取引を編集"],
        "添加": ["zh-Hans": "添加", "zh-Hant": "新增", "en": "Add", "ja": "追加"],
        "日期": ["zh-Hans": "日期", "zh-Hant": "日期", "en": "Date", "ja": "日付"],
        "数量": ["zh-Hans": "数量", "zh-Hant": "數量", "en": "Quantity", "ja": "数量"],
        "价格": ["zh-Hans": "价格", "zh-Hant": "價格", "en": "Price", "ja": "価格"],
        "手续费": ["zh-Hans": "手续费", "zh-Hant": "手續費", "en": "Fee", "ja": "手数料"],
        "总计": ["zh-Hans": "总计", "zh-Hant": "總計", "en": "Total", "ja": "合計"],
        "清空": ["zh-Hans": "清空", "zh-Hant": "清空", "en": "Clear", "ja": "クリア"],
        "更新": ["zh-Hans": "更新", "zh-Hant": "更新", "en": "Update", "ja": "更新"],
        "错误": ["zh-Hans": "错误", "zh-Hant": "錯誤", "en": "Error", "ja": "エラー"],
        "股": ["zh-Hans": "股", "zh-Hant": "股", "en": " shares", "ja": "株"],

        // Holding Row
        "52周高": ["zh-Hans": "52周高", "zh-Hant": "52週高", "en": "52W High", "ja": "52週高値"],
        "现价": ["zh-Hans": "现价", "zh-Hant": "現價", "en": "Price", "ja": "現在値"],
        "成本": ["zh-Hans": "成本", "zh-Hant": "成本", "en": "Cost", "ja": "コスト"],
        "盈亏": ["zh-Hans": "盈亏", "zh-Hant": "盈虧", "en": "P&L", "ja": "損益"],

        // Holding Details Table
        "股票": ["zh-Hans": "股票", "zh-Hant": "股票", "en": "Symbol", "ja": "銘柄"],
        "涨跌": ["zh-Hans": "涨跌", "zh-Hant": "漲跌", "en": "Change", "ja": "変動"],
        "涨跌%": ["zh-Hans": "涨跌%", "zh-Hant": "漲跌%", "en": "Chg%", "ja": "変動%"],
        "P/E": ["zh-Hans": "P/E", "zh-Hant": "P/E", "en": "P/E", "ja": "PER"],
        "EPS": ["zh-Hans": "EPS", "zh-Hant": "EPS", "en": "EPS", "ja": "EPS"],

        // Symbol Search
        "股票/ETF": ["zh-Hans": "股票/ETF", "zh-Hant": "股票/ETF", "en": "Stocks/ETF", "ja": "株式/ETF"],
        "日本投信": ["zh-Hans": "日本投信", "zh-Hant": "日本投信", "en": "JP Funds", "ja": "投資信託"],
        "输入代码或名称": ["zh-Hans": "输入代码或名称", "zh-Hant": "輸入代碼或名稱", "en": "Enter symbol or name", "ja": "コードまたは名前を入力"],
        "输入基金代码或名称": ["zh-Hans": "输入基金代码或名称", "zh-Hant": "輸入基金代碼或名稱", "en": "Enter fund code or name", "ja": "ファンドコードまたは名前を入力"],
        "搜索中...": ["zh-Hans": "搜索中...", "zh-Hant": "搜尋中...", "en": "Searching...", "ja": "検索中..."],
        "搜索结果": ["zh-Hans": "搜索结果", "zh-Hant": "搜尋結果", "en": "Search Results", "ja": "検索結果"],
        "未找到相关标的": ["zh-Hans": "未找到相关标的", "zh-Hant": "未找到相關標的", "en": "No results found", "ja": "該当する銘柄が見つかりません"],
        "请尝试其他关键词": ["zh-Hans": "请尝试其他关键词", "zh-Hant": "請嘗試其他關鍵字", "en": "Try other keywords", "ja": "他のキーワードをお試しください"],
        "输入代码或名称开始搜索": ["zh-Hans": "输入代码或名称开始搜索", "zh-Hant": "輸入代碼或名稱開始搜尋", "en": "Enter symbol or name to search", "ja": "検索するコードまたは名前を入力"],
        "支持美股、日股、港股、A股等": ["zh-Hans": "支持美股、日股、港股、A股等", "zh-Hant": "支援美股、日股、港股、A股等", "en": "Supports US, JP, HK, CN stocks", "ja": "米国、日本、香港、中国株に対応"],
        "人气基金": ["zh-Hans": "人气基金", "zh-Hant": "人氣基金", "en": "Popular Funds", "ja": "人気ファンド"],

        // Add to Watchlist
        "搜索股票代码或名称": ["zh-Hans": "搜索股票代码或名称", "zh-Hant": "搜尋股票代碼或名稱", "en": "Search symbol or name", "ja": "銘柄コードまたは名前を検索"],
        "热门标的": ["zh-Hans": "热门标的", "zh-Hant": "熱門標的", "en": "Trending", "ja": "トレンド"],
        "加载热门标的...": ["zh-Hans": "加载热门标的...", "zh-Hant": "載入熱門標的...", "en": "Loading trending...", "ja": "トレンドを読み込み中..."],
        "暂无热门标的": ["zh-Hans": "暂无热门标的", "zh-Hant": "暫無熱門標的", "en": "No trending stocks", "ja": "トレンド銘柄なし"],

        // Additional UI Strings
        "只持仓": ["zh-Hans": "只持仓", "zh-Hant": "個持倉", "en": "holdings", "ja": "保有"],
        "资产类型": ["zh-Hans": "资产类型", "zh-Hant": "資產類型", "en": "Asset Type", "ja": "資産タイプ"],
        "累计股息": ["zh-Hans": "累计股息", "zh-Hant": "累計股息", "en": "Total Dividends", "ja": "累計配当"],
        "总收益": ["zh-Hans": "总收益", "zh-Hant": "總收益", "en": "Total Return", "ja": "総収益"],
        "累计收益": ["zh-Hans": "累计收益", "zh-Hant": "累計收益", "en": "Cumulative Return", "ja": "累計収益"],
        "持仓盈亏排行": ["zh-Hans": "持仓盈亏排行", "zh-Hant": "持倉盈虧排行", "en": "Holdings Ranking", "ja": "保有損益ランキング"],
        "暂无数据": ["zh-Hans": "暂无数据", "zh-Hant": "暫無資料", "en": "No Data", "ja": "データなし"],
        "请先在设置中创建账户，然后添加交易": ["zh-Hans": "请先在设置中创建账户，然后添加交易", "zh-Hant": "請先在設定中建立帳戶，然後新增交易", "en": "Create an account in Settings first, then add transactions", "ja": "設定で口座を作成してから取引を追加してください"],
        "无匹配结果": ["zh-Hans": "无匹配结果", "zh-Hant": "無匹配結果", "en": "No matches", "ja": "一致なし"],
        "盈": ["zh-Hans": "盈", "zh-Hant": "盈", "en": "W", "ja": "勝"],
        "亏": ["zh-Hans": "亏", "zh-Hant": "虧", "en": "L", "ja": "負"],

        // Delete Confirmations
        "确定要删除吗": ["zh-Hans": "确定要删除吗？", "zh-Hant": "確定要刪除嗎？", "en": "Are you sure?", "ja": "本当に削除しますか？"],
        "该账户下的所有持仓和交易记录都将被永久删除，此操作无法恢复。": ["zh-Hans": "该账户下的所有持仓和交易记录都将被永久删除，此操作无法恢复。", "zh-Hant": "該帳戶下的所有持倉和交易記錄都將被永久刪除，此操作無法恢復。", "en": "All holdings and transactions will be permanently deleted. This action cannot be undone.", "ja": "すべての保有と取引記録が永久に削除されます。この操作は取り消せません。"],
        "该持仓的所有交易记录都将被永久删除。": ["zh-Hans": "该持仓的所有交易记录都将被永久删除。", "zh-Hant": "該持倉的所有交易記錄都將被永久刪除。", "en": "All transactions will be permanently deleted.", "ja": "すべての取引記録が永久に削除されます。"],

        // Import Result
        "成功导入": ["zh-Hans": "成功导入", "zh-Hant": "成功匯入", "en": "Successfully imported", "ja": "インポート成功"],
        "账户": ["zh-Hans": "账户", "zh-Hant": "帳戶", "en": "accounts", "ja": "口座"],
        "个": ["zh-Hans": "个", "zh-Hant": "個", "en": "", "ja": ""],
        "笔": ["zh-Hans": "笔", "zh-Hant": "筆", "en": "", "ja": "件"],

        // Holding Detail - Position
        "持有数量": ["zh-Hans": "持有数量", "zh-Hant": "持有數量", "en": "Shares Held", "ja": "保有数量"],
        "平均成本": ["zh-Hans": "平均成本", "zh-Hant": "平均成本", "en": "Avg Cost", "ja": "平均取得価格"],
        "总成本": ["zh-Hans": "总成本", "zh-Hant": "總成本", "en": "Total Cost", "ja": "取得総額"],
        "未实现盈亏": ["zh-Hans": "未实现盈亏", "zh-Hant": "未實現盈虧", "en": "Unrealized P&L", "ja": "含み損益"],
        "已实现盈亏": ["zh-Hans": "已实现盈亏", "zh-Hant": "已實現盈虧", "en": "Realized P&L", "ja": "実現損益"],
        "未实现": ["zh-Hans": "未实现", "zh-Hant": "未實現", "en": "Unrealized", "ja": "含み"],
        "已实现": ["zh-Hans": "已实现", "zh-Hant": "已實現", "en": "Realized", "ja": "実現"],
        "股息": ["zh-Hans": "股息", "zh-Hant": "股息", "en": "Dividends", "ja": "配当"],

        // Day Detail - Streak
        "连盈": ["zh-Hans": "连盈", "zh-Hant": "連盈", "en": "Win streak:", "ja": "連勝:"],
        "连亏": ["zh-Hans": "连亏", "zh-Hant": "連虧", "en": "Loss streak:", "ja": "連敗:"],

        // Add Transaction Form
        "代码": ["zh-Hans": "代码", "zh-Hant": "代碼", "en": "Symbol", "ja": "コード"],
        "名称": ["zh-Hans": "名称", "zh-Hant": "名稱", "en": "Name", "ja": "名称"],
        "标的名称": ["zh-Hans": "标的名称", "zh-Hant": "標的名稱", "en": "Symbol Name", "ja": "銘柄名"],
        "搜索持仓": ["zh-Hans": "搜索持仓", "zh-Hant": "搜尋持倉", "en": "Search Holdings", "ja": "保有検索"],
        "加仓": ["zh-Hans": "加仓", "zh-Hant": "加倉", "en": "Add More", "ja": "追加購入"],
        "详情": ["zh-Hans": "详情", "zh-Hant": "詳情", "en": "Details", "ja": "詳細"],
        "时间范围": ["zh-Hans": "时间范围", "zh-Hant": "時間範圍", "en": "Time Range", "ja": "期間"],
        "分析": ["zh-Hans": "分析", "zh-Hant": "分析", "en": "Analytics", "ja": "分析"],
        "加载中...": ["zh-Hans": "加载中...", "zh-Hant": "載入中...", "en": "Loading...", "ja": "読み込み中..."],
        "账户已删除": ["zh-Hans": "账户已删除", "zh-Hant": "帳戶已刪除", "en": "Account deleted", "ja": "口座を削除しました"],
        "条记录导入失败": ["zh-Hans": "条记录导入失败", "zh-Hant": "條記錄匯入失敗", "en": " records failed to import", "ja": "件のインポートに失敗"],

        // Add Transaction Form - Mutual Fund
        "定额": ["zh-Hans": "定额", "zh-Hant": "定額", "en": "Fixed Amount", "ja": "定額"],
        "定量": ["zh-Hans": "定量", "zh-Hant": "定量", "en": "Fixed Qty", "ja": "定量"],
        "投资金额": ["zh-Hans": "投资金额", "zh-Hant": "投資金額", "en": "Amount", "ja": "投資額"],
        "基准价格": ["zh-Hans": "基准价格", "zh-Hant": "基準價格", "en": "NAV", "ja": "基準価格"],
        "口数": ["zh-Hans": "口数", "zh-Hant": "口數", "en": "Units", "ja": "口数"],
        "口": ["zh-Hans": "口", "zh-Hant": "口", "en": " units", "ja": "口"],
        "円": ["zh-Hans": "円", "zh-Hant": "円", "en": "JPY", "ja": "円"],
        "备注": ["zh-Hans": "备注", "zh-Hant": "備註", "en": "Note", "ja": "メモ"],
        "可选": ["zh-Hans": "可选", "zh-Hant": "可選", "en": "Optional", "ja": "任意"],
        "取得口数": ["zh-Hans": "取得口数", "zh-Hant": "取得口數", "en": "Units Acquired", "ja": "取得口数"],
        "总金额": ["zh-Hans": "总金额", "zh-Hant": "總金額", "en": "Total Amount", "ja": "総額"],

        // Add Transaction Form - Validation
        "交易日期不能是未来日期": ["zh-Hans": "交易日期不能是未来日期", "zh-Hant": "交易日期不能是未來日期", "en": "Date cannot be in the future", "ja": "未来の日付は指定できません"],
        "投资金额至少100円": ["zh-Hans": "投资金额至少100円", "zh-Hant": "投資金額至少100円", "en": "Minimum amount is ¥100", "ja": "最低投資額は100円です"],
        "投资金额超出范围": ["zh-Hans": "投资金额超出范围", "zh-Hant": "投資金額超出範圍", "en": "Amount out of range", "ja": "投資額が範囲外です"],
        "价格超出合理范围": ["zh-Hans": "价格超出合理范围", "zh-Hant": "價格超出合理範圍", "en": "Price out of range", "ja": "価格が範囲外です"],

        // Asset Types (股票 already defined above at line 363)
        "基金": ["zh-Hans": "基金", "zh-Hant": "基金", "en": "Fund", "ja": "投信"],
        "贵金属": ["zh-Hans": "贵金属", "zh-Hant": "貴金屬", "en": "Metal", "ja": "貴金属"],
        "加密货币": ["zh-Hans": "加密货币", "zh-Hant": "加密貨幣", "en": "Crypto", "ja": "暗号資産"],
        "债券": ["zh-Hans": "债券", "zh-Hant": "債券", "en": "Bond", "ja": "債券"],
        "现金": ["zh-Hans": "现金", "zh-Hant": "現金", "en": "Cash", "ja": "現金"],

        // Markets (日本投信 already defined above at line 371)
        "日本股票": ["zh-Hans": "日本股票", "zh-Hant": "日本股票", "en": "Japan", "ja": "日本株"],
        "中国A股": ["zh-Hans": "中国A股", "zh-Hant": "中國A股", "en": "China", "ja": "中国A株"],
        "美国": ["zh-Hans": "美国", "zh-Hant": "美國", "en": "US", "ja": "米国"],
        "香港": ["zh-Hans": "香港", "zh-Hant": "香港", "en": "HK", "ja": "香港"],
        "大宗商品": ["zh-Hans": "大宗商品", "zh-Hant": "大宗商品", "en": "Commodity", "ja": "商品"],

        // Account Types
        "普通账户": ["zh-Hans": "普通账户", "zh-Hant": "普通帳戶", "en": "Standard", "ja": "特定口座"],

        // Base Currency
        "日元 (JPY)": ["zh-Hans": "日元 (JPY)", "zh-Hant": "日元 (JPY)", "en": "JPY (¥)", "ja": "円 (JPY)"],
        "人民币 (CNY)": ["zh-Hans": "人民币 (CNY)", "zh-Hant": "人民幣 (CNY)", "en": "CNY (¥)", "ja": "人民元 (CNY)"],
        "美元 (USD)": ["zh-Hans": "美元 (USD)", "zh-Hant": "美元 (USD)", "en": "USD ($)", "ja": "ドル (USD)"],
        "港元 (HKD)": ["zh-Hans": "港元 (HKD)", "zh-Hant": "港元 (HKD)", "en": "HKD (HK$)", "ja": "香港ドル (HKD)"],

        // Portfolio Display Modes
        "列表": ["zh-Hans": "列表", "zh-Hant": "列表", "en": "List", "ja": "一覧"],
        // Note: "详情" already defined above in Add Transaction Form section

        // Placeholders
        "如 0331418A": ["zh-Hans": "如 0331418A", "zh-Hant": "如 0331418A", "en": "e.g. 0331418A", "ja": "例: 0331418A"],
        "如 7203.T": ["zh-Hans": "如 7203.T", "zh-Hant": "如 7203.T", "en": "e.g. 7203.T", "ja": "例: 7203.T"],
    ]
}

// MARK: - Notification
extension Notification.Name {
    static let languageDidChange = Notification.Name("languageDidChange")
}

// MARK: - String Extension for Localization
extension String {
    var localized: String {
        LanguageManager.shared.localized(self)
    }
}
