import Foundation
import SwiftUI

/// 각 종별 마릿수를 저장. pet.json 에 영속화.
@Observable
final class PetStore {
  var counts: [PetSpecies: Int] = [:] {
    didSet { if oldValue != counts { save() } }
  }

  private let fileURL: URL

  init() {
    let source = URL(fileURLWithPath: #filePath)
    let dir = source
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    self.fileURL = dir.appendingPathComponent("pet.json")
    load()
  }

  var totalCount: Int { counts.values.reduce(0, +) }

  func count(for species: PetSpecies) -> Int { counts[species] ?? 0 }
  func setCount(_ n: Int, for species: PetSpecies) {
    var c = counts
    c[species] = max(0, min(5, n))
    if c[species] == 0 { c.removeValue(forKey: species) }
    counts = c
  }

  private struct Persisted: Codable { var counts: [String: Int] }

  private func load() {
    guard let data = try? Data(contentsOf: fileURL),
          let p = try? JSONDecoder().decode(Persisted.self, from: data) else { return }
    var out: [PetSpecies: Int] = [:]
    for (k, v) in p.counts {
      if let sp = PetSpecies(rawValue: k) { out[sp] = v }
    }
    counts = out
  }

  private func save() {
    let dict = Dictionary(uniqueKeysWithValues: counts.map { ($0.key.rawValue, $0.value) })
    guard let data = try? JSONEncoder().encode(Persisted(counts: dict)) else { return }
    try? data.write(to: fileURL)
  }
}
