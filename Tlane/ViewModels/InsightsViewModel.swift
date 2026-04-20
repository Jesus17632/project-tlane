import Foundation
import SwiftData

@Observable
@MainActor
final class InsightsViewModel {
    var insight: SalesInsight?
    var isLoading: Bool = false
    var errorMessage: String?
    var usedFallback: Bool = false

    /// Último resumen de contexto enviado al modelo.
    /// Expuesto para que ChatViewModel pueda reutilizarlo.
    private(set) var lastContext: String = ""

    /// Hash del último contexto para evitar regenerar cuando los datos no cambiaron.
    private var lastContextHash: Int = 0

    private let session = ConsejeroSession()

    // MARK: - Generar si hace falta

    func generateIfNeeded(context: ModelContext) async {
        let summary = AppContextBuilder.build(context: context)
        let newHash = summary.hashValue

        // Solo regenera si es la primera vez o si los datos cambiaron
        guard insight == nil || newHash != lastContextHash else { return }
        guard !isLoading else { return }

        await generateInsight(context: context, prebuiltSummary: summary, hash: newHash)
    }

    func generateInsight(context: ModelContext) async {
        let summary = AppContextBuilder.build(context: context)
        await generateInsight(context: context, prebuiltSummary: summary, hash: summary.hashValue)
    }

    // MARK: - Generación interna

    private func generateInsight(
        context: ModelContext,
        prebuiltSummary: String,
        hash: Int
    ) async {
        print("🚀 generateInsight llamado")
        isLoading = true
        errorMessage = nil
        lastContext = prebuiltSummary

        do {
            await session.resetSession()
            let result = try await session.generateInsight(salesSummary: prebuiltSummary)
            print("🎉 Modelo respondió: \(result.mainAdvice)")
            insight = result
            lastContextHash = hash
            usedFallback = false
        } catch ConsejeroError.notAvailable(let reason) {
            print("❌ No disponible: \(reason)")
            errorMessage = reason
            usedFallback = true
        } catch ConsejeroError.refusal {
            print("❌ Refusal")
            errorMessage = "No pude generar un consejo ahora. Revisa tus ventas del día."
            usedFallback = true
        } catch {
            print("❌ Error genérico: \(error)")
            errorMessage = "Hubo un problema generando el consejo."
            usedFallback = true
        }

        isLoading = false
    }
}
