import Foundation
import SwiftData

/// 数据迁移服务
/// 负责处理数据模型升级时的迁移逻辑
@MainActor
final class DataMigrationService {

    /// 执行所有必要的数据迁移
    /// - Parameter modelContext: SwiftData 模型上下文
    static func performMigrations(modelContext: ModelContext) {
        migrateAccountTypeNormalToGeneral(modelContext: modelContext)
        syncHoldingAccountTypesWithPortfolios(modelContext: modelContext)
    }

    // MARK: - Migration: normal -> general

    /// 将旧的 "normal" 账户类型迁移为 "general"
    /// 这是为了统一账户类型命名
    private static func migrateAccountTypeNormalToGeneral(modelContext: ModelContext) {
        // 迁移 Portfolio
        let portfolioDescriptor = FetchDescriptor<Portfolio>()
        if let portfolios = try? modelContext.fetch(portfolioDescriptor) {
            for portfolio in portfolios {
                if portfolio.accountType == "normal" {
                    portfolio.accountType = AccountType.general.rawValue
                    print("📦 Migrated Portfolio '\(portfolio.name)' from 'normal' to 'general'")
                }
            }
        }

        // 迁移 Holding
        let holdingDescriptor = FetchDescriptor<Holding>()
        if let holdings = try? modelContext.fetch(holdingDescriptor) {
            for holding in holdings {
                if holding.accountType == "normal" {
                    holding.accountType = AccountType.general.rawValue
                    print("📦 Migrated Holding '\(holding.symbol)' from 'normal' to 'general'")
                }
            }
        }

        // 保存更改
        do {
            try modelContext.save()
        } catch {
            print("⚠️ Migration save failed: \(error)")
        }
    }

    // MARK: - Migration: Sync Holding accountType with Portfolio

    /// 同步 Holding 的 accountType 与其 Portfolio 保持一致
    /// 新架构下，Holding 的 accountType 应该从 Portfolio 继承
    private static func syncHoldingAccountTypesWithPortfolios(modelContext: ModelContext) {
        let portfolioDescriptor = FetchDescriptor<Portfolio>()
        guard let portfolios = try? modelContext.fetch(portfolioDescriptor) else { return }

        var updated = 0
        for portfolio in portfolios {
            let portfolioAccountType = portfolio.accountType

            for holding in portfolio.holdings {
                // 如果 holding 的 accountType 与 portfolio 不一致，则同步
                if holding.accountType != portfolioAccountType {
                    let oldType = holding.accountType
                    holding.accountType = portfolioAccountType
                    updated += 1
                    print("📦 Synced Holding '\(holding.symbol)' accountType: '\(oldType)' -> '\(portfolioAccountType)'")
                }
            }
        }

        if updated > 0 {
            do {
                try modelContext.save()
                print("📦 Synced \(updated) holdings with their portfolio account types")
            } catch {
                print("⚠️ Sync save failed: \(error)")
            }
        }
    }
}
