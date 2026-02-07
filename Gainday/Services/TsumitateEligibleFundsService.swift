import Foundation

/// つみたてNISA対象商品验证服务
/// 用于检查投资信託是否属于つみたてNISA対象商品
actor TsumitateEligibleFundsService {
    static let shared = TsumitateEligibleFundsService()

    private init() {}

    // MARK: - Known Eligible Funds

    /// 已知的つみたてNISA対象商品代码
    /// 金融庁认定的可在つみたて投資枠中购买的投資信託
    /// 参考: https://www.fsa.go.jp/policy/nisa2/about/tsumitate/target/index.html
    /// 注意: 不在此列表中的基金仍可通过代码直接添加（会显示警告但不阻止）
    static let knownEligibleFunds: Set<String> = [

        // ── eMAXIS Slim (三菱UFJアセット) ──
        "0331418A",  // eMAXIS Slim 米国株式(S&P500)
        "03311187",  // eMAXIS Slim 全世界株式(オール・カントリー)
        "03316183",  // eMAXIS Slim 全世界株式(除く日本)
        "03311172",  // eMAXIS Slim 先進国株式インデックス
        "0331117C",  // eMAXIS Slim 国内株式(TOPIX)
        "0331117A",  // eMAXIS Slim 国内株式(日経平均)
        "0331418B",  // eMAXIS Slim 新興国株式インデックス
        "03311179",  // eMAXIS Slim バランス(8資産均等型)
        "03311174",  // eMAXIS Slim 先進国債券インデックス
        "0331118A",  // eMAXIS Slim 国内債券インデックス

        // ── SBI・V シリーズ (SBIアセット) ──
        "9C311125",  // SBI・V・S&P500インデックス・ファンド
        "9C31121A",  // SBI・V・全米株式インデックス・ファンド
        "9C311226",  // SBI・V・全世界株式インデックス・ファンド
        "9C311217",  // SBI・V・先進国株式インデックス・ファンド

        // ── 楽天 (楽天投信投資顧問) ──
        "89311199",  // 楽天・全米株式インデックス・ファンド (楽天VTI)
        "8931119A",  // 楽天・全世界株式インデックス・ファンド (楽天VT)
        "89311207",  // 楽天・S&P500インデックス・ファンド
        "9I31123A",  // 楽天・プラス・オールカントリー株式
        "9I31223A",  // 楽天・プラス・S&P500
        "9I314241",  // 楽天・プラス・NASDAQ-100

        // ── ニッセイ (ニッセイアセット) ──
        "9I311179",  // ニッセイ外国株式インデックスファンド
        "9I31117A",  // ニッセイTOPIXインデックスファンド
        "9I311186",  // ニッセイ日経225インデックスファンド
        "9I311191",  // ニッセイ・インデックスバランスファンド(4資産均等型)

        // ── たわらノーロード (アセマネOne) ──
        "29311164",  // たわらノーロード 先進国株式
        "29311165",  // たわらノーロード 日経225
        "29311166",  // たわらノーロード TOPIX
        "29311168",  // たわらノーロード 全世界株式
        "29311170",  // たわらノーロード バランス(8資産均等型)

        // ── iFree / iFreeNEXT (大和アセット) ──
        "04311181",  // iFreeNEXT FANG+インデックス
        "04317188",  // iFreeNEXT NASDAQ100インデックス
        "04314233",  // iFreeNEXT インド株インデックス
        "04311172",  // iFree S&P500インデックス
        "04311176",  // iFree 日経225インデックス
        "04311174",  // iFree TOPIXインデックス
        "04311179",  // iFree 外国株式インデックス(為替ヘッジなし)

        // ── Smart-i (りそなアセット) ──
        "53311119",  // Smart-i 先進国株式インデックス
        "53311120",  // Smart-i TOPIXインデックス
        "53311123",  // Smart-i 8資産バランス(安定成長型)

        // ── はじめてのNISA (野村アセット) ──
        "01312237",  // はじめてのNISA・全世界株式(オール・カントリー)
        "01311237",  // はじめてのNISA・米国株式(S&P500)
        "01313237",  // はじめてのNISA・日本株式(日経225)

        // ── 野村インデックスファンド (野村アセット) ──
        "01311159",  // 野村インデックスファンド・日経225
        "01311157",  // 野村インデックスファンド・TOPIX
        "01311163",  // 野村インデックスファンド・外国株式

        // ── Tracers (日興アセット) ──
        "02312234",  // Tracers MSCIオール・カントリー・インデックス
        "0231122A",  // Tracers S&P500配当貴族インデックス

        // ── 三井住友・DC (三井住友DSアセット) ──
        "79311144",  // 三井住友・DCつみたてNISA・日本株インデックスファンド
        "79311148",  // 三井住友・DCつみたてNISA・全海外株インデックスファンド

        // ── SOMPO (SOMPOアセット) ──
        "4531121C",  // SOMPO123 先進国株式

        // ── 年金積立 (日興アセット) ──
        "0231Q01A",  // 年金積立 Jグロース

        // ── ひふみ (レオス) ──
        "96311073",  // ひふみプラス

        // ── セゾン ──
        "47311074",  // セゾン・グローバルバランスファンド
        "47311081",  // セゾン資産形成の達人ファンド

        // ── コモンズ ──
        "6431117C",  // コモンズ30ファンド
    ]

    // MARK: - Public Methods

    /// 检查基金代码是否为つみたてNISA対象商品
    /// - Parameter code: 8桁の投信コード
    /// - Returns: 是否为対象商品
    func isEligible(code: String) -> Bool {
        let normalizedCode = code.uppercased()
            .replacingOccurrences(of: ".T", with: "")
            .replacingOccurrences(of: ".JP", with: "")
        return Self.knownEligibleFunds.contains(normalizedCode)
    }

    /// 检查多个基金代码的eligibility
    /// - Parameter codes: 基金代码数组
    /// - Returns: [代码: 是否eligible] 字典
    func checkEligibility(codes: [String]) -> [String: Bool] {
        var result: [String: Bool] = [:]
        for code in codes {
            result[code] = isEligible(code: code)
        }
        return result
    }

    /// 从列表中筛选出eligible的基金
    /// - Parameter codes: 基金代码数组
    /// - Returns: 仅包含eligible基金的数组
    func filterEligible(codes: [String]) -> [String] {
        codes.filter { isEligible(code: $0) }
    }
}

// MARK: - Extension for JapanFundService

extension JapanFundService.FundSearchResult {
    /// 是否为つみたてNISA対象商品
    var isTsumitateEligible: Bool {
        TsumitateEligibleFundsService.knownEligibleFunds.contains(code.uppercased())
    }
}
