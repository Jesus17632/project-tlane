import FoundationModels

@Generable
struct SalesInsight {
    @Guide(description: """
        Nombre de un SF Symbol de sistema que represente visualmente el consejo. \
        Ejemplos: 'chart.line.uptrend.xyaxis', 'bag.fill', 'exclamationmark.triangle.fill', \
        'arrow.up.right.circle.fill', 'clock.fill', 'tag.fill', 'star.fill', 'person.2.fill'.
        """)
    var icon: String

    @Guide(description: """
        Consejo principal para el comerciante. Máximo 2 oraciones. \
        Tono cercano, español mexicano. Debe mencionar cifras o productos \
        específicos del contexto si los hay.
        """)
    var mainAdvice: String

    @Guide(description: """
        Razón basada en los datos de ventas o inventario proporcionados. \
        Una oración. Cita números concretos cuando sea posible.
        """)
    var reasoning: String

    @Guide(description: """
        Una acción concreta que el comerciante puede hacer HOY. \
        Comienza con verbo en infinitivo. Máximo 15 palabras.
        """)
    var suggestedAction: String

    @Guide(description: """
        Alerta opcional de stock o tendencia negativa. \
        Déjalo vacío ("") si todo está bien. \
        Si hay productos casi agotados o las ventas bajaron, \
        menciona específicamente cuál y cuánto.
        """)
    var alertMessage: String
}
