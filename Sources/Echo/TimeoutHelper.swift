import Foundation

/// Corre `operation` com um limite de tempo. Se estourar o prazo, devolve
/// nil em vez de travar pra sempre — proteção pra qualquer chamada externa
/// (processo, framework do sistema) que possa ficar pendurada.
/// `withTaskGroup` cria duas tarefas concorrentes (o trabalho real e um
/// "relógio" que só dorme); pega o que terminar primeiro e cancela o resto.
func withTimeout<T: Sendable>(
    seconds: Double,
    operation: @escaping @Sendable () async throws -> T
) async -> T? {
    await withTaskGroup(of: T?.self) { group in
        group.addTask {
            try? await operation()
        }
        group.addTask {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            return nil
        }
        let result = await group.next() ?? nil
        group.cancelAll()
        return result
    }
}
