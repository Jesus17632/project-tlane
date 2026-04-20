import FoundationModels
import Foundation

enum ConsejeroError: Error {
    case notAvailable(reason: String)
    case refusal
    case generationFailed(Error)
}

actor ConsejeroSession {
    private var session: LanguageModelSession?

    // MARK: - Availability

    struct AvailabilityStatus {
        let isAvailable: Bool
        let reason: String?
    }

    func checkAvailability() -> AvailabilityStatus {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            return AvailabilityStatus(isAvailable: true, reason: nil)

        case .unavailable(let unavailableReason):
            let message: String
            switch unavailableReason {
            case .appleIntelligenceNotEnabled:
                message = "Apple Intelligence no está activado en este dispositivo."
            case .deviceNotEligible:
                message = "Este dispositivo no soporta Apple Intelligence."
            case .modelNotReady:
                message = "El modelo aún se está descargando. Intenta en unos minutos."
            @unknown default:
                message = "Apple Intelligence no está disponible."
            }
            return AvailabilityStatus(isAvailable: false, reason: message)
        }
    }

    // MARK: - Generación de consejo

    func generateInsight(salesSummary: String) async throws -> SalesInsight {
        let status = checkAvailability()
        guard status.isAvailable else {
            throw ConsejeroError.notAvailable(reason: status.reason ?? "No disponible")
        }

        let instructions = """
        Eres un consejero de negocios experto para comerciantes de tianguis, mercados \
        y ferias artesanales de México. Tu trabajo es analizar los datos reales del \
        negocio y dar recomendaciones concretas, accionables y basadas en evidencia.

        REGLAS IMPORTANTES:
        - Siempre cita cifras o nombres de productos específicos del contexto.
        - Si las ventas bajaron vs ayer o la semana pasada, dilo claramente y sugiere qué hacer.
        - Si hay productos con stock crítico, prioriza esa alerta.
        - Si las ventas van bien, refuerza qué está funcionando y cómo aprovecharlo más.
        - Si no hay ventas aún hoy, da consejos de exhibición, precio o atención al cliente.
        - Habla como un amigo de confianza con experiencia en negocios, en español mexicano.
        - NUNCA inventes datos que no estén en el resumen proporcionado.
        """

        let prompt = """
        Analiza el siguiente resumen del negocio y genera un consejo personalizado:

        \(salesSummary)

        Genera el consejo siguiendo estas prioridades:
        1. Si hay alertas de stock crítico → alertMessage debe mencionarlo
        2. Si la tendencia es negativa → explica qué puede estar pasando
        3. Si hay un producto estrella → sugiere cómo potenciarlo
        4. Si es fin de semana o hora pico → aprovéchalo en la sugerencia
        5. Si hay mezcla de efectivo/digital → comenta si hay oportunidad de mejorar
        """

        if session == nil {
            session = LanguageModelSession(instructions: instructions)
        }
        guard let session else {
            throw ConsejeroError.notAvailable(reason: "No se pudo crear la sesión")
        }

        do {
            let response = try await session.respond(
                to: prompt,
                generating: SalesInsight.self
            )
            return response.content
        } catch let error as LanguageModelSession.GenerationError {
            if case .refusal = error {
                throw ConsejeroError.refusal
            }
            throw ConsejeroError.generationFailed(error)
        } catch {
            throw ConsejeroError.generationFailed(error)
        }
    }

    /// Limpia la sesión actual para forzar un nuevo contexto en la próxima llamada.
    func resetSession() {
        session = nil
    }
}
