import Foundation

/// つみたてNISA対象商品验证服务
/// 用于检查投资信託是否属于つみたてNISA対象商品
actor TsumitateEligibleFundsService {
    static let shared = TsumitateEligibleFundsService()

    private init() {}

    // MARK: - Known Eligible Funds

    /// 已知的つみたてNISA対象商品代码
    /// 这些是金融庁认定的可在つみたて投資枠中购买的投资信託
    /// 完整列表参考: https://www.fsa.go.jp/policy/nisa2/about/tsumitate/target/index.html
    static let knownEligibleFunds: Set<String> = [
        // eMAXIS Slim 系列 (三菱UFJアセット) - 最受欢迎的低成本指数基金
        "0331418A",  // eMAXIS Slim 米国株式(S&P500)
        "03311187",  // eMAXIS Slim 全世界株式(オール・カントリー)
        "03311172",  // eMAXIS Slim 先進国株式インデックス
        "0331117C",  // eMAXIS Slim 国内株式(TOPIX)
        "0331418B",  // eMAXIS Slim 新興国株式インデックス
        "03311179",  // eMAXIS Slim バランス(8資産均等型)
        "0331117A",  // eMAXIS Slim 国内株式(日経平均)
        "03311174",  // eMAXIS Slim 先進国債券インデックス
        "0331118A",  // eMAXIS Slim 国内債券インデックス

        // SBI・V シリーズ (SBIアセット)
        "9C311125",  // SBI・V・S&P500インデックス・ファンド
        "9C31121A",  // SBI・V・全米株式インデックス・ファンド
        "9C311226",  // SBI・V・全世界株式インデックス・ファンド
        "9C311217",  // SBI・V・先進国株式インデックス・ファンド

        // 楽天・インデックスシリーズ (楽天投信投資顧問)
        "89311199",  // 楽天・全米株式インデックス・ファンド (楽天VTI)
        "8931119A",  // 楽天・全世界株式インデックス・ファンド (楽天VT)
        "89311207",  // 楽天・S&P500インデックス・ファンド

        // ニッセイ・インデックスシリーズ (ニッセイアセット)
        "9I311179",  // ニッセイ外国株式インデックスファンド
        "9I31117A",  // ニッセイTOPIXインデックスファンド
        "9I311186",  // ニッセイ日経225インデックスファンド
        "9I311191",  // ニッセイ・インデックスバランスファンド(4資産均等型)

        // たわらノーロードシリーズ (アセマネOne)
        "29311164",  // たわらノーロード 先進国株式
        "29311165",  // たわらノーロード 日経225
        "29311166",  // たわらノーロード TOPIX
        "29311168",  // たわらノーロード 全世界株式
        "29311170",  // たわらノーロード バランス(8資産均等型)

        // iFree シリーズ (大和アセット)
        "04311172",  // iFree S&P500インデックス
        "04311176",  // iFree 日経225インデックス
        "04311174",  // iFree TOPIXインデックス
        "04311179",  // iFree 外国株式インデックス(為替ヘッジなし)

        // Smart-i シリーズ (りそなアセット)
        "53311119",  // Smart-i 先進国株式インデックス
        "53311120",  // Smart-i TOPIXインデックス
        "53311123",  // Smart-i 8資産バランス(安定成長型)

        // 野村インデックスファンド・シリーズ (野村アセット)
        "01311159",  // 野村インデックスファンド・日経225
        "01311157",  // 野村インデックスファンド・TOPIX
        "01311163",  // 野村インデックスファンド・外国株式

        // 三井住友・DCつみたてNISAシリーズ
        "79311144",  // 三井住友・DCつみたてNISA・日本株インデックスファンド
        "79311148",  // 三井住友・DCつみたてNISA・全海外株インデックスファンド

        // その他の人気ファンド
        "47311074",  // セゾン・グローバルバランスファンド
        "47311081",  // セゾン資産形成の達人ファンド
        "96311073",  // ひふみプラス
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
