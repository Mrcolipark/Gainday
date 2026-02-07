# GainDay 盈历

A beautiful iOS stock portfolio tracker app inspired by Apple's Stocks app design.

![iOS 18.5+](https://img.shields.io/badge/iOS-18.5+-blue.svg)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange.svg)
![SwiftUI](https://img.shields.io/badge/SwiftUI-5.0-green.svg)
![SwiftData](https://img.shields.io/badge/SwiftData-1.0-purple.svg)

## Features

### Portfolio Management
- **Multi-Account Support**: Manage multiple brokerage accounts (楽天証券, SBI証券, etc.)
- **Multi-Market Support**: Track stocks from JP, US, HK, CN markets
- **Transaction Tracking**: Record buy/sell/dividend transactions with detailed history
- **Real-time Quotes**: Live market data via Yahoo Finance API

### Three View Modes
- **Basic Mode**: Clean watchlist view with price and change badges
- **Details Mode**: Horizontally scrollable table with P/E, Market Cap, Volume, 52-week range
- **Holdings Mode**: Expandable rows showing positions with inline transaction management

### P&L Calendar
- **Heatmap Visualization**: Color-coded daily P&L performance
- **Month/Year Views**: Switch between monthly calendar and yearly heatmap
- **Statistics**: Win rate, profit days, average daily return
- **Share Cards**: Generate beautiful shareable monthly reports

### Markets Tab
- **Global Indices**: S&P 500, Nikkei 225, Hang Seng, Shanghai Composite
- **Market Status**: Real-time market state indicators (Pre-market, Regular, After-hours)
- **Movers**: Top gainers, losers, and most active stocks from your portfolio

### Design
- **iPhone Stocks App Style**: Pure black OLED-friendly background with high contrast
- **iOS 26 Liquid Glass**: Native glass effects when available, graceful fallback
- **Colored Badges**: Green/red percentage badges for quick P&L scanning
- **Compact Number Formatting**: Large numbers displayed as 万/亿 (10K/100M) units

## Screenshots

| Home | Calendar | Markets |
|------|----------|---------|
| Basic/Details/Holdings modes | Monthly heatmap | Global indices |

## Tech Stack

- **SwiftUI** - Modern declarative UI framework
- **SwiftData** - Persistence layer for portfolios, holdings, transactions
- **Swift Charts** - Native charting for P&L visualization
- **Async/Await** - Modern concurrency for API calls
- **WidgetKit** - Home screen widgets for quick P&L glance

## Architecture

```
Gainday/
├── Models/           # SwiftData models (Portfolio, Holding, Transaction)
├── Views/
│   ├── Home/         # Main dashboard with portfolio sections
│   ├── Calendar/     # P&L calendar heatmap
│   ├── Markets/      # Market indices and movers
│   ├── News/         # Financial news (placeholder)
│   ├── Portfolio/    # Holding rows, detail views, transaction forms
│   └── Settings/     # Account management, preferences
├── Services/
│   ├── MarketDataService    # Yahoo Finance API integration
│   ├── PnLCalculationService # Portfolio P&L calculations
│   ├── SnapshotService      # Daily snapshot management
│   └── ExchangeRateService  # Currency conversion
├── Components/       # Reusable UI components
├── DesignSystem/     # AppColors, AppFonts, Animations
└── Extensions/       # Double+Currency, Date extensions
```

## Requirements

- iOS 18.5+
- Xcode 16.0+
- Swift 5.9+

## Installation

1. Clone the repository
```bash
git clone https://github.com/Mrcolipark/Gainday.git
```

2. Open `Gainday.xcodeproj` in Xcode

3. Build and run on simulator or device

## Configuration

### Base Currency
Settings > 基准货币 > Select JPY/USD/CNY/HKD

### Accounts
Settings > 账户管理 > Add accounts with custom colors and types

### Theme
The app uses a dark theme optimized for OLED displays. Light mode support is planned.

## API

Market data is fetched from Yahoo Finance API (unofficial). No API key required.

Supported markets:
- 🇯🇵 Japan (TSE) - `.T` suffix
- 🇺🇸 US (NYSE/NASDAQ)
- 🇭🇰 Hong Kong (HKEX) - `.HK` suffix
- 🇨🇳 China (SSE/SZSE) - `.SS`/`.SZ` suffix
- 🇯🇵 Japan Mutual Funds

## Widgets

- **Daily P&L Widget**: Shows today's portfolio performance
- **Week Calendar Widget**: 7-day P&L heatmap
- **Month Calendar Widget**: Monthly P&L heatmap

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Design inspired by Apple's Stocks app
- Market data from Yahoo Finance
- Icons from SF Symbols

---

For investors who love beautiful apps
