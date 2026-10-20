import Foundation

/// Convierte las materias de internet («Fiction, science fiction, general»,
/// «Accessible book», «nyt:…», en cinco idiomas) en pocos géneros claros y en
/// español. Lo que no se reconoce se descarta: mejor sin etiqueta que con basura.
///
/// Open Library junta las materias de todas las ediciones de una obra (cómics,
/// guías de estudio, adaptaciones), así que un género cuenta por votos: las
/// materias al principio de la lista pesan más, y uno que apenas aparece
/// frente al principal se descarta. Afinado con respuestas reales
/// (scripts/sondeo).
public enum GenreMap {
    private struct Genre {
        let name: String
        /// Claves que bastan casi solas (2 puntos).
        let strong: [String]
        /// Claves que necesitan compañía (1 punto).
        let weak: [String]
        /// No se agrega a una obra de ficción («History» en una novela).
        var nonfiction = false
    }

    private static let catalog: [Genre] = [
        Genre(name: "Ciencia ficción", strong: ["science fiction", "ciencia ficcion", "science-fiction", "space opera"], weak: ["sci-fi"]),
        Genre(name: "Fantasía", strong: ["fantasy fiction", "fiction, fantasy", "high fantasy", "epic fantasy", "novela fantastica", "literatura fantastica"],
              weak: ["fantasy", "fantasia", "wizards", "magos"]),
        Genre(name: "Distopía", strong: ["dystopia", "dystopian", "distopia", "fiction, dystopian"], weak: []),
        Genre(name: "Terror", strong: ["horror fiction", "horror tales", "novela de terror", "fiction, horror"], weak: ["horror", "terror"]),
        Genre(name: "Policiaca", strong: ["detective and mystery", "mystery fiction", "novela policiaca", "novela policial", "novela negra", "crime fiction", "fiction, mystery"],
              weak: ["mystery", "detective", "misterio", "crime", "murder"]),
        Genre(name: "Suspenso", strong: ["thriller", "suspense fiction", "fiction, thrillers"], weak: ["suspense", "suspenso"]),
        Genre(name: "Romance", strong: ["love stories", "romance fiction", "fiction, romance", "novela romantica", "novela rosa"], weak: ["romantic"]),
        Genre(name: "Novela histórica", strong: ["historical fiction", "novela historica", "fiction, historical"], weak: []),
        Genre(name: "Aventura", strong: ["adventure fiction", "adventure stories", "relatos de aventura", "novela de aventuras", "action & adventure"],
              weak: ["adventure", "aventura"]),
        Genre(name: "Humor", strong: ["humorous fiction", "humorous stories", "fiction, humorous"], weak: ["humor", "satire", "satira", "satirical"]),
        Genre(name: "Realismo mágico", strong: ["magic realism", "magical realism", "realismo magico"], weak: []),
        Genre(name: "Cuento", strong: ["short stories", "cuentos", "relatos", "short story"], weak: []),
        Genre(name: "Poesía", strong: ["poetry", "poesia", "poems", "poemas"], weak: []),
        Genre(name: "Teatro", strong: ["plays", "teatro", "theater", "theatre"], weak: []),
        Genre(name: "Cómic", strong: ["comic books", "graphic novels", "comics & graphic novels", "novela grafica", "historieta", "manga"], weak: ["comics"]),
        Genre(name: "Infantil y juvenil", strong: ["juvenile fiction", "children's fiction", "literatura infantil", "literatura juvenil", "young adult fiction", "juvenile literature"],
              weak: ["juvenile", "children", "infantil", "juvenil"]),
        Genre(name: "Clásicos", strong: ["classic literature", "fiction classics", "clasicos", "classics"], weak: []),
        Genre(name: "Biografía y memorias", strong: ["biography", "biografia", "autobiography", "autobiografia", "memoir", "memorias", "biographies"], weak: []),
        Genre(name: "Historia", strong: ["world history", "historia universal"], weak: ["history", "historia"], nonfiction: true),
        Genre(name: "Filosofía", strong: ["philosophy", "filosofia"], weak: [], nonfiction: true),
        Genre(name: "Psicología", strong: ["psychology", "psicologia", "cognitive psychology"], weak: [], nonfiction: true),
        Genre(name: "Desarrollo personal", strong: ["self-help", "autoayuda", "personal growth", "self-improvement", "superacion personal", "self-actualization"],
              weak: ["habits", "habit"]),
        Genre(name: "Negocios y economía", strong: ["business & economics", "economics", "economia", "negocios", "management", "finance", "finanzas"],
              weak: ["business"], nonfiction: true),
        Genre(name: "Ciencia", strong: ["popular science", "life sciences", "divulgacion cientifica", "physics", "fisica", "biology", "biologia", "astronomy", "neuroscience"],
              weak: ["science", "ciencia", "evolution"], nonfiction: true),
        Genre(name: "Tecnología", strong: ["computers", "programming", "informatica", "technology & engineering"], weak: ["technology", "tecnologia"], nonfiction: true),
        Genre(name: "Política y sociedad", strong: ["political science", "social science", "sociology", "sociologia", "ciencias sociales"],
              weak: ["politics", "politica"], nonfiction: true),
        Genre(name: "Religión y espiritualidad", strong: ["religion", "spirituality", "espiritualidad", "theology", "teologia"], weak: [], nonfiction: true),
        Genre(name: "Arte", strong: ["art history", "historia del arte", "painting", "pintura", "photography", "fotografia"],
              weak: ["art", "arte", "music", "musica"], nonfiction: true),
        Genre(name: "Viajes", strong: ["travel", "viajes", "guias de viaje"], weak: [], nonfiction: true),
        Genre(name: "Cocina", strong: ["cooking", "cocina", "recipes", "recetas", "cookbooks"], weak: [], nonfiction: true),
        Genre(name: "Ensayo", strong: ["essays", "ensayos", "ensayo"], weak: []),
    ]

    private static let fiction = ["fiction", "ficcion", "novela", "novel", "novels", "literary fiction", "romans"]
    private static let nonfictionKeys = ["nonfiction", "non-fiction", "no ficcion"]

    /// Hasta `limit` géneros en español, del más votado al menos.
    public static func genres(from subjects: [String], limit: Int = 3) -> [String] {
        let folded = subjects.map { TextMatch.fold($0) }
        func weight(_ index: Int) -> Double { index < 20 ? 1 : (index < 40 ? 0.5 : 0.25) }

        // ¿Es ficción? «Non-Fiction» contiene «fiction»: se descarta antes.
        var fictionVotes = 0.0
        for (index, subject) in folded.prefix(40).enumerated()
        where !nonfictionKeys.contains(where: { has(subject, $0) }) && fiction.contains(where: { has(subject, $0) }) {
            fictionVotes += weight(index)
        }
        let isFiction = fictionVotes >= 1

        var scores: [(name: String, score: Double, order: Int)] = []
        for (order, genre) in catalog.enumerated() where !(isFiction && genre.nonfiction) {
            var score = 0.0
            for (index, subject) in folded.enumerated() {
                if genre.strong.contains(where: { has(subject, $0) }) {
                    score += 2 * weight(index)
                } else if genre.weak.contains(where: { has(subject, $0) }) {
                    score += weight(index)
                }
            }
            if score >= 2 { scores.append((genre.name, score, order)) }
        }
        guard let top = scores.map(\.score).max() else {
            if isFiction { return ["Ficción"] }
            if folded.contains(where: { subject in nonfictionKeys.contains { has(subject, $0) } }) { return ["No ficción"] }
            return []
        }
        return scores
            .filter { $0.score >= top / 2 }
            .sorted { $0.score != $1.score ? $0.score > $1.score : $0.order < $1.order }
            .prefix(limit)
            .map(\.name)
    }

    /// Palabra o frase completa: «art» no se encuentra en «smart» ni en «party».
    private static func has(_ subject: String, _ key: String) -> Bool {
        guard let range = subject.range(of: key) else { return false }
        var searchStart = subject.startIndex
        var candidate: Range<String.Index>? = range
        while let found = candidate {
            let before = found.lowerBound == subject.startIndex ? nil : subject[subject.index(before: found.lowerBound)]
            let after = found.upperBound == subject.endIndex ? nil : subject[found.upperBound]
            if !(before?.isLetter ?? false) && !(after?.isLetter ?? false) { return true }
            searchStart = subject.index(after: found.lowerBound)
            candidate = subject.range(of: key, range: searchStart..<subject.endIndex)
        }
        return false
    }
}
