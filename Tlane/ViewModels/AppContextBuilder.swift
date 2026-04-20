import Foundation
import SwiftData

struct AppContextBuilder {

    static func build(context: ModelContext) -> String {
        let sales    = fetchSales(context: context)
        let products = fetchProducts(context: context)

        print("🔍 DEBUG AppContextBuilder:")
        print("   Sales fetched: \(sales.count)")
        print("   Products fetched: \(products.count)")

        let now      = Date.now
        let calendar = Calendar.current
        let hour     = calendar.component(.hour, from: now)
        let weekday  = calendar.component(.weekday, from: now)
        let isWeekend = weekday == 1 || weekday == 7

        // Períodos
        let todaySales        = sales.filter { calendar.isDateInToday($0.date) }
        let yesterdaySales    = sales.filter { calendar.isDateInYesterday($0.date) }
        let thisWeekSales     = sales.filter { isThisWeek($0.date, calendar: calendar, now: now) }
        let lastWeekSales     = sales.filter { isLastWeek($0.date, calendar: calendar, now: now) }
        let monthSales        = sales.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }

        let todayTotal        = total(of: todaySales)
        let yesterdayTotal    = total(of: yesterdaySales)
        let weekTotal         = total(of: thisWeekSales)
        let lastWeekTotal     = total(of: lastWeekSales)
        let monthTotal        = total(of: monthSales)

        // Tendencias
        let dayTrend          = trendDescription(current: todayTotal,  previous: yesterdayTotal,  label: "ayer")
        let weekTrend         = trendDescription(current: weekTotal,   previous: lastWeekTotal,   label: "semana pasada")

        // Inventario
        let activeProds       = products.filter { $0.currentStock > 0 }
        let soldOutProds      = products.filter { $0.isSold }
        let lowStockProds     = products.filter { $0.currentStock == 1 && !$0.isUniqueItem }

        // Métodos de pago hoy
        let cashCount         = todaySales.filter { $0.paymentMethod == .cash    }.count
        let digitalCount      = todaySales.filter { $0.paymentMethod == .digital }.count

        // Top productos semana
        let topProducts       = topSellingProducts(from: thisWeekSales, products: products)

        // Hora pico (última semana)
        let peakHour          = peakHourDescription(from: thisWeekSales + lastWeekSales)

        let result = """
        === CONTEXTO DEL NEGOCIO ===
        Fecha: \(formattedDate(now)) · \(hour):00 hrs · \(isWeekend ? "Fin de semana" : "Entre semana")

        --- Ventas de hoy ---
        Ingresos: $\(todayTotal.formatted()) MXN en \(todaySales.filter { $0.amount > 0 }.count) cobros
        Gastos:   $\(abs(total(of: todaySales.filter { $0.amount < 0 })).formatted()) MXN en \(todaySales.filter { $0.amount < 0 }.count) pagos
        Métodos:  \(cashCount) efectivo · \(digitalCount) digital
        Tendencia vs ayer: \(dayTrend)

        --- Semana actual ---
        Total: $\(weekTotal.formatted()) MXN en \(thisWeekSales.count) operaciones
        Tendencia vs semana pasada: \(weekTrend)
        \(peakHour.isEmpty ? "" : "Hora pico reciente: \(peakHour)")

        --- Mes en curso ---
        Total: $\(monthTotal.formatted()) MXN en \(monthSales.count) operaciones

        --- Inventario ---
        Productos activos (con stock): \(activeProds.count)
        Productos agotados: \(soldOutProds.count)
        \(lowStockProds.isEmpty ? "Sin alertas de stock." : "⚠️ Stock crítico (1 unidad): \(lowStockProds.map(\.name).joined(separator: ", "))")

        --- Top 5 productos esta semana (por ingreso) ---
        \(topProducts.isEmpty ? "Sin ventas esta semana aún." : topProducts)

        --- Catálogo disponible por categoría ---
        \(categorySummary(products: activeProds))
        === FIN DE CONTEXTO ===
        """

        print("📊 CONTEXTO COMPLETO:\n\(result)")
        return result
    }

    // MARK: - Fetch

    private static func fetchSales(context: ModelContext) -> [Sale] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
        let descriptor = FetchDescriptor<Sale>(
            predicate: #Predicate { $0.date >= cutoff },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private static func fetchProducts(context: ModelContext) -> [Product] {
        let descriptor = FetchDescriptor<Product>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Cálculos

    private static func total(of sales: [Sale]) -> Decimal {
        sales.reduce(Decimal(0)) { $0 + $1.amount }
    }

    /// Descripción de tendencia comparando dos períodos.
    private static func trendDescription(current: Decimal, previous: Decimal, label: String) -> String {
        guard previous > 0 else {
            return current > 0 ? "Primera venta del período ✅" : "Sin datos comparables"
        }
        let diff = current - previous
        let pct  = (diff / previous * 100).rounded(scale: 0)
        let sign = diff >= 0 ? "+" : ""
        let emoji = diff > 0 ? "📈" : (diff < 0 ? "📉" : "➡️")
        return "\(sign)\(pct)% vs \(label) \(emoji)"
    }

    private static func isThisWeek(_ date: Date, calendar: Calendar, now: Date) -> Bool {
        calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear)
    }

    private static func isLastWeek(_ date: Date, calendar: Calendar, now: Date) -> Bool {
        guard let lastWeekDate = calendar.date(byAdding: .weekOfYear, value: -1, to: now) else {
            return false
        }
        return calendar.isDate(date, equalTo: lastWeekDate, toGranularity: .weekOfYear)
    }

    /// Hora pico: franja de 1 hora con más ventas en el período dado.
    private static func peakHourDescription(from sales: [Sale]) -> String {
        guard !sales.isEmpty else { return "" }
        let calendar = Calendar.current
        var hourCounts = [Int: Int]()
        for sale in sales where sale.amount > 0 {
            let h = calendar.component(.hour, from: sale.date)
            hourCounts[h, default: 0] += 1
        }
        guard let peak = hourCounts.max(by: { $0.value < $1.value }) else { return "" }
        return "\(peak.key):00–\(peak.key + 1):00 hrs (\(peak.value) ventas)"
    }

    private static func topSellingProducts(from sales: [Sale], products: [Product]) -> String {
        var counts: [UUID: (name: String, qty: Int, revenue: Decimal)] = [:]
        for sale in sales {
            for item in sale.items {
                if var entry = counts[item.productId] {
                    entry.qty     += item.quantity
                    entry.revenue += item.priceAtSale * Decimal(item.quantity)
                    counts[item.productId] = entry
                } else {
                    counts[item.productId] = (item.productName, item.quantity, item.priceAtSale)
                }
            }
        }
        return counts.values
            .sorted { $0.revenue > $1.revenue }
            .prefix(5)
            .enumerated()
            .map { i, p in "\(i + 1). \(p.name) — \(p.qty) uds · $\(p.revenue.formatted()) MXN" }
            .joined(separator: "\n")
    }

    private static func categorySummary(products: [Product]) -> String {
        let grouped = Dictionary(grouping: products, by: \.category)
        return grouped
            .sorted { $0.key < $1.key }
            .map { cat, prods in "\(cat): \(prods.count) producto\(prods.count == 1 ? "" : "s")" }
            .joined(separator: " · ")
    }

    private static func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_MX")
        f.dateStyle = .medium
        return f.string(from: date)
    }
}

// MARK: - Decimal helpers

private extension Decimal {
    func rounded(scale: Int) -> Decimal {
        var result = Decimal()
        var mutable = self
        NSDecimalRound(&result, &mutable, scale, .plain)
        return result
    }
}
