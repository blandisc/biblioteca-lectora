import Foundation

/// Convierte las materias de internet («Fiction, general», «Accessible book»,
/// «Spanish Short stories», «nyt:…») en pocos géneros claros y en español.
/// Lo que no se reconoce se descarta: mejor sin etiqueta que con basura.
public enum GenreMap {
    /// Género y las palabras (sin acentos, en minúsculas) que lo delatan. El
    /// orden importa: primero lo específico; «Ficción» solo si no hay otro.
    private static let genres: [(name: String, keys: [String])] = [
        ("Ciencia ficción", ["science fiction", "ciencia ficcion", "sci-fi", "space opera", "ciencia-ficcion"]),
        ("Fantasía", ["fantasy", "fantasia", "fantastic fiction", "magia", "wizards", "dragons"]),
        ("Distopía", ["dystopia", "distopia", "dystopian"]),
        ("Terror", ["horror", "terror"]),
        ("Policiaca", ["detective", "mystery", "misterio", "crime", "policiac", "policial", "murder", "noir"]),
        ("Suspenso", ["thriller", "suspense", "suspenso"]),
        ("Romance", ["romance", "love stories", "romantic", "novela romantica"]),
        ("Novela histórica", ["historical fiction", "novela historica"]),
        ("Aventura", ["adventure", "aventura"]),
        ("Humor", ["humor", "humorous", "humour", "satire", "satira"]),
        ("Realismo mágico", ["magic realism", "magical realism", "realismo magico"]),
        ("Cuento", ["short stories", "cuentos", "relatos", "short story"]),
        ("Poesía", ["poetry", "poesia", "poems", "poemas"]),
        ("Teatro", ["drama", "plays", "teatro", "theater", "theatre"]),
        ("Cómic", ["comics", "graphic novel", "comic", "manga", "historieta"]),
        ("Infantil y juvenil", ["juvenile", "children", "infantil", "juvenil", "young adult", "literatura infantil"]),
        ("Clásicos", ["classics", "clasicos", "classic literature"]),
        ("Biografía y memorias", ["biography", "biografia", "autobiography", "autobiografia", "memoir", "memorias"]),
        ("Historia", ["history", "historia"]),
        ("Filosofía", ["philosophy", "filosofia"]),
        ("Psicología", ["psychology", "psicologia"]),
        ("Desarrollo personal", ["self-help", "autoayuda", "personal growth", "self-improvement", "superacion personal", "habits"]),
        ("Negocios y economía", ["business", "economics", "economia", "negocios", "management", "finance", "finanzas", "empresa"]),
        ("Ciencia", ["science", "ciencia", "physics", "fisica", "biology", "biologia", "evolution", "astronomy", "neuroscience"]),
        ("Tecnología", ["technology", "tecnologia", "computers", "programming", "informatica"]),
        ("Política y sociedad", ["political science", "politics", "politica", "social science", "sociology", "sociologia"]),
        ("Religión y espiritualidad", ["religion", "spirituality", "espiritualidad", "theology", "teologia"]),
        ("Arte", ["art", "arte", "painting", "pintura", "music", "musica", "photography"]),
        ("Viajes", ["travel", "viajes"]),
        ("Cocina", ["cooking", "cocina", "recipes", "recetas"]),
        ("Ensayo", ["essays", "ensayo", "ensayos"]),
    ]

    /// Literaturas nacionales («Argentine fiction», «Literatura mexicana»).
    private static let literatures: [(name: String, keys: [String])] = [
        ("Literatura argentina", ["argentin"]), ("Literatura mexicana", ["mexican", "mexicana", "mexicano"]),
        ("Literatura colombiana", ["colombian"]), ("Literatura chilena", ["chilean", "chilena"]),
        ("Literatura peruana", ["peruvian", "peruana"]), ("Literatura uruguaya", ["uruguay"]),
        ("Literatura cubana", ["cuban"]), ("Literatura española", ["spanish fiction", "spanish literature", "literatura espanola", "novela espanola"]),
        ("Literatura latinoamericana", ["latin american", "latinoamerican", "hispanoamerican"]),
        ("Literatura rusa", ["russian", "rusa"]), ("Literatura francesa", ["french fiction", "french literature", "francesa"]),
        ("Literatura inglesa", ["english fiction", "english literature", "british"]),
        ("Literatura estadounidense", ["american fiction", "american literature", "estadounidense"]),
        ("Literatura japonesa", ["japanese", "japonesa"]), ("Literatura alemana", ["german", "alemana"]),
        ("Literatura portuguesa", ["portuguese", "portuguesa"]), ("Literatura china", ["chinese"]),
    ]

    private static let fiction = ["fiction", "ficcion", "novela", "novel", "novels", "literary"]
    private static let nonfiction = ["nonfiction", "non-fiction", "no ficcion"]

    /// Hasta `limit` géneros en español, del más específico al más general.
    public static func genres(from subjects: [String], limit: Int = 4) -> [String] {
        let folded = subjects.map { TextMatch.fold($0) }
        func matches(_ key: String) -> Bool {
            folded.contains { subject in
                // Palabra completa: «art» no debe encontrarse en «smart» ni en «party».
                subject.range(of: #"(^|[^a-z])"# + NSRegularExpression.escapedPattern(for: key) + #"($|[^a-z])"#,
                              options: .regularExpression) != nil
                    || (key.count >= 7 && subject.contains(key))
            }
        }
        var result: [String] = []
        let isFiction = fiction.contains(where: matches)
        for genre in genres where genre.keys.contains(where: matches) {
            // «History» en una novela suele ser «historical fiction»; «Science» en
            // una novela, ciencia ficción: no se agregan como no ficción.
            if isFiction, ["Historia", "Ciencia", "Política y sociedad", "Psicología"].contains(genre.name) { continue }
            result.append(genre.name)
        }
        if isFiction {
            for literature in literatures where literature.keys.contains(where: matches) { result.append(literature.name) }
        }
        if result.isEmpty, isFiction { result.append("Ficción") }
        if result.isEmpty, nonfiction.contains(where: matches) { result.append("No ficción") }
        var seen = Set<String>()
        return Array(result.filter { seen.insert($0).inserted }.prefix(limit))
    }
}
