import Foundation
#if os(macOS)
import IOKit
#else
import Security
#endif

/// Una huella de este aparato que no viaja en los respaldos ni con el Asistente de Migración
/// (M7): con ella `DeviceIdentity` sabe si los ajustes vienen de otro dispositivo.
enum DeviceFingerprint {
    /// nil si no se pudo leer ahora (el id de siempre se queda).
    static func current() -> String? {
        #if os(macOS)
        // El número del equipo: otra Mac tiene otro.
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        return IORegistryEntryCreateCFProperty(service, kIOPlatformUUIDKey as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? String
        #else
        return keychainMark()
        #endif
    }

    #if !os(macOS)
    private static let account = "registro.huella"

    /// Una marca al azar en el llavero, solo de este dispositivo: no se sincroniza con iCloud ni
    /// se restaura en otro iPhone.
    private static func keychainMark() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: false,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query.merging([kSecReturnData as String: true]) { $1 } as CFDictionary, &item)
        if status == errSecSuccess, let data = item as? Data { return String(data: data, encoding: .utf8) }
        // Otro error (p. ej. el iPhone aún no se desbloquea): mejor no decidir nada ahora.
        guard status == errSecItemNotFound else { return nil }
        let mark = UUID().uuidString
        let add = query.merging([
            kSecValueData as String: Data(mark.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]) { $1 }
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess ? mark : nil
    }
    #endif
}
