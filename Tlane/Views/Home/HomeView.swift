import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @State private var insightsVM = InsightsViewModel()

    private let verde       = Color(red: 0.18, green: 0.47, blue: 0.20)
    private let arena       = Color(red: 0.84, green: 0.76, blue: 0.63)
    private let arenaOscuro = Color(red: 0.72, green: 0.62, blue: 0.48)
    private let fondo       = Color(red: 0.97, green: 0.96, blue: 0.95)
    private let oscuro      = Color(red: 0.18, green: 0.18, blue: 0.18)
    private let rojo        = Color(red: 0.75, green: 0.25, blue: 0.20)

    // MARK: - Animaciones
    @State private var animarCaja      = false
    @State private var animarBotones   = false
    @State private var animarHistorial = false
    @State private var animarHeader    = false
    @State private var pulsarCaja      = false

    // MARK: - @Query reactivos
    @Query private var todaysSales: [Sale]
    @Query(sort: \Sale.date, order: .reverse) private var allSales: [Sale]

    init() {
        let start = Calendar.current.startOfDay(for: .now)
        _todaysSales = Query(
            filter: #Predicate<Sale> { $0.date >= start },
            sort: [SortDescriptor(\Sale.date, order: .reverse)]
        )
    }

    // MARK: - Derivados computados
    private var cajaChica: Decimal {
        todaysSales.reduce(Decimal(0)) { $0 + $1.amount }
    }

    private var ultimasVentas: [Sale] { todaysSales }

    private var salesSummaryForAdvisor: String {
        let total = cajaChica.formatted(.currency(code: "MXN"))
        let count = todaysSales.count
        let byCategory = Dictionary(grouping: todaysSales.flatMap(\.items), by: \.productName)
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { "\($0.key) (\($0.value))" }
            .joined(separator: ", ")
        return """
        Ventas de hoy: \(count) operaciones, total \(total).
        Productos más vendidos: \(byCategory.isEmpty ? "ninguno aún" : byCategory).
        """
    }

    // MARK: - Estado local UI
    @State private var mostrarTodasVentas = false
    @State private var mostrarChatBot     = false
    @State private var mostrarPagar       = false
    @State private var mostrarCobrar      = false
    @State private var mostrarCajaGrande  = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            fondo.ignoresSafeArea()

            // Decoración de fondo
            GeometryReader { geo in
                ZStack {
                    Circle()
                        .fill(verde.opacity(0.06))
                        .frame(width: 320, height: 320)
                        .offset(x: geo.size.width * 0.5, y: -60)
                        .blur(radius: 40)
                    Circle()
                        .fill(arena.opacity(0.18))
                        .frame(width: 220, height: 220)
                        .offset(x: -40, y: geo.size.height * 0.6)
                        .blur(radius: 30)
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    cajaChicaSection
                        .opacity(animarCaja ? 1 : 0)
                        .offset(y: animarCaja ? 0 : 28)

                    botonesSection
                        .opacity(animarBotones ? 1 : 0)
                        .offset(y: animarBotones ? 0 : 28)

                    ultimasVentasSection
                        .opacity(animarHistorial ? 1 : 0)
                        .offset(y: animarHistorial ? 0 : 28)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .padding(.bottom, 100)
            }

            if mostrarChatBot { chatBotPopup }
            chatBotButton
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: CajaView()) {
                    Image(systemName: "person.circle.fill")
                        .font(.title2)
                        .foregroundStyle(oscuro)
                        .padding(8)
                        .glassEffect(in: Circle())
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.05)) {
                animarCaja = true
            }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.18)) {
                animarBotones = true
            }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.32)) {
                animarHistorial = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                    pulsarCaja = true
                }
            }
        }
        .sheet(isPresented: $mostrarCajaGrande) { CajaGrandeView() }
        .sheet(isPresented: $mostrarCobrar) {
            CobrarSheetView(onVentaRegistrada: { _, _ in })
        }
        .sheet(isPresented: $mostrarPagar) { PagarSheetView() }
    }

    // MARK: - Caja Chica

    private var cajaChicaSection: some View {
        ZStack(alignment: .bottomTrailing) {

            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [verde, verde.opacity(0.78)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: verde.opacity(0.35), radius: 18, x: 0, y: 8)

            Circle()
                .fill(Color.white.opacity(0.07))
                .frame(width: 140, height: 140)
                .offset(x: 30, y: 30)
                .scaleEffect(pulsarCaja ? 1.08 : 1.0)

            Circle()
                .fill(Color.white.opacity(0.04))
                .frame(width: 90, height: 90)
                .offset(x: 60, y: -10)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Caja del día", systemImage: "banknote")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.75))
                    Spacer()
                    Text(Date.now.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.55))
                }

                Text(cajaChica.formatted(.currency(code: "MXN")))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.4), value: cajaChica)

                HStack(spacing: 16) {
                    statChip(
                        icon: "arrow.down.circle.fill",
                        label: "\(todaysSales.filter { $0.amount > 0 }.count) cobros"
                    )
                    statChip(
                        icon: "arrow.up.circle.fill",
                        label: "\(todaysSales.filter { $0.amount < 0 }.count) pagos"
                    )
                }
                .padding(.top, 2)
            }
            .padding(20)
        }
        .frame(height: 160)
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                mostrarCajaGrande = true
            }
        }
    }

    private func statChip(icon: String, label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption2.weight(.bold))
            Text(label)
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(.white.opacity(0.85))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.white.opacity(0.15), in: Capsule())
    }

    // MARK: - Botones

    private var botonesSection: some View {
        HStack(spacing: 10) {

            // Caja Grande
            Button { mostrarCajaGrande = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar.fill")
                        .font(.body.weight(.semibold))
                    Text("Caja Grande")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    LinearGradient(
                        colors: [arenaOscuro, arenaOscuro.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 16)
                )
                .shadow(color: arenaOscuro.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .scaleEffect(animarBotones ? 1 : 0.88)
            .animation(.spring(response: 0.45, dampingFraction: 0.65).delay(0.18), value: animarBotones)

            // Cobrar
            Button { mostrarCobrar = true } label: {
                VStack(spacing: 3) {
                    Image(systemName: "arrow.down")
                        .font(.title3.weight(.bold))
                    Text("Cobrar")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(.white)
                .frame(width: 72, height: 52)
                .background(
                    LinearGradient(
                        colors: [verde, verde.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    in: RoundedRectangle(cornerRadius: 16)
                )
                .shadow(color: verde.opacity(0.35), radius: 8, x: 0, y: 4)
            }
            .scaleEffect(animarBotones ? 1 : 0.88)
            .animation(.spring(response: 0.45, dampingFraction: 0.65).delay(0.26), value: animarBotones)

            // Pagar
            Button { mostrarPagar = true } label: {
                VStack(spacing: 3) {
                    Image(systemName: "arrow.up")
                        .font(.title3.weight(.bold))
                    Text("Pagar")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(.white)
                .frame(width: 72, height: 52)
                .background(
                    LinearGradient(
                        colors: [rojo, rojo.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    in: RoundedRectangle(cornerRadius: 16)
                )
                .shadow(color: rojo.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .scaleEffect(animarBotones ? 1 : 0.88)
            .animation(.spring(response: 0.45, dampingFraction: 0.65).delay(0.34), value: animarBotones)
        }
    }

    // MARK: - Historial

    private var ultimasVentasSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Historial")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(oscuro)
                Spacer()
                if !ultimasVentas.isEmpty {
                    Text("\(ultimasVentas.count) movimientos")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(oscuro.opacity(0.4))
                }
            }

            if ultimasVentas.isEmpty {
                emptyVentasRow
            } else {
                VStack(spacing: 8) {
                    let visibles = mostrarTodasVentas
                        ? ultimasVentas
                        : Array(ultimasVentas.prefix(3))

                    ForEach(Array(visibles.enumerated()), id: \.element.id) { index, sale in
                        ventaRow(sale: sale)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                            .animation(
                                .spring(response: 0.45, dampingFraction: 0.8)
                                    .delay(Double(index) * 0.06),
                                value: animarHistorial
                            )
                    }

                    if ultimasVentas.count > 3 {
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                mostrarTodasVentas.toggle()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(mostrarTodasVentas ? "Ver menos" : "Ver todos")
                                    .font(.subheadline.weight(.semibold))
                                Image(systemName: mostrarTodasVentas ? "chevron.up" : "chevron.down")
                                    .font(.caption.weight(.bold))
                            }
                            .foregroundStyle(verde)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(verde.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }
            }
        }
    }

    private var emptyVentasRow: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.title2)
                .foregroundStyle(arena)
            Text("Aún no hay movimientos hoy")
                .font(.subheadline)
                .foregroundStyle(oscuro.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(arena.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(arena.opacity(0.3), lineWidth: 1)
        )
    }

    private func ventaRow(sale: Sale) -> some View {
        let esCobro = sale.amount > 0
        let color: Color = esCobro ? verde : rojo

        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.1))
                    .frame(width: 42, height: 42)
                Image(systemName: esCobro
                      ? sale.paymentMethod.systemImage
                      : "arrow.up.circle.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                if !sale.items.isEmpty {
                    Text(sale.items.map { $0.productName }.joined(separator: ", "))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(oscuro)
                        .lineLimit(1)
                } else {
                    Text(esCobro ? "Cobro" : "Pago")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(oscuro)
                }
                Text(sale.paymentMethod.rawValue)
                    .font(.caption)
                    .foregroundStyle(oscuro.opacity(0.4))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text((esCobro ? "+" : "-") + abs(sale.amount).formatted(.currency(code: "MXN")))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(color)
                Text(sale.date.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(oscuro.opacity(0.35))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: oscuro.opacity(0.05), radius: 6, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(arena.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - ChatBot

    private var chatBotPopup: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(verde.opacity(0.12))
                        .frame(width: 34, height: 34)
                    Image(systemName: "sparkles")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(verde)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Asistente Tlane")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(oscuro)
                    Text("Con IA · Solo Apple")
                        .font(.caption2)
                        .foregroundStyle(oscuro.opacity(0.4))
                }
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        mostrarChatBot = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(arena)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider().overlay(arena.opacity(0.35))

            ConsejeroCardView(viewModel: insightsVM)
                .padding(10)
        }
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(fondo)
                .shadow(color: oscuro.opacity(0.14), radius: 24, x: 0, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(arena.opacity(0.35), lineWidth: 1)
        )
        .frame(width: 310)
        .padding(.trailing, 18)
        .padding(.bottom, 96)
        .transition(.asymmetric(
            insertion: .scale(scale: 0.88, anchor: .bottomTrailing)
                .combined(with: .opacity),
            removal: .scale(scale: 0.88, anchor: .bottomTrailing)
                .combined(with: .opacity)
        ))
    }

    private var chatBotButton: some View {
        Button {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                mostrarChatBot.toggle()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [verde, verde.opacity(0.82)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 58, height: 58)
                    .shadow(color: verde.opacity(0.45), radius: 14, x: 0, y: 6)

                Image(systemName: mostrarChatBot ? "xmark" : "sparkles")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(mostrarChatBot ? 90 : 0))
                    .animation(.spring(response: 0.35, dampingFraction: 0.65), value: mostrarChatBot)
            }
        }
        .padding(.trailing, 20)
        .padding(.bottom, 24)
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
    .modelContainer(AppContainer.preview)
}
