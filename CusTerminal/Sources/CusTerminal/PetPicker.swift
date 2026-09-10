import SwiftUI

/// 사이드바 하단 펫 진입 버튼.
struct PetPickerButton: View {
  @Environment(PetStore.self) private var store
  @State private var show: Bool = false

  var body: some View {
    Button {
      show.toggle()
    } label: {
      HStack(spacing: 8) {
        Image(systemName: "pawprint.fill")
          .foregroundStyle(store.totalCount > 0 ? Color.accentColor : .secondary)
        VStack(alignment: .leading, spacing: 0) {
          Text("펫").font(.system(size: 12))
          Text(summary)
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        Spacer()
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 8)
      .background(
        RoundedRectangle(cornerRadius: 8)
          .fill(Color(nsColor: .controlBackgroundColor))
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .popover(isPresented: $show, arrowEdge: .top) {
      PetPickerPopover()
    }
    .tooltip("창 하단에 걸어다니는 픽셀 펫. 종류별 마릿수 조절")
  }

  private var summary: String {
    let entries = PetSpecies.allCases.compactMap { sp -> String? in
      let c = store.count(for: sp)
      return c > 0 ? "\(sp.emoji)×\(c)" : nil
    }
    return entries.isEmpty ? "없음" : entries.joined(separator: " ")
  }
}

struct PetPickerPopover: View {
  @Environment(PetStore.self) private var store

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("펫").font(.headline)
      Text("각 종별 마릿수 (0 ~ 5). 창 하단에서 걸어다녀요.")
        .font(.caption)
        .foregroundStyle(.secondary)

      VStack(spacing: 8) {
        ForEach(PetSpecies.allCases) { species in
          HStack(spacing: 10) {
            Text(species.emoji).font(.title2)
            Text(species.displayName)
              .font(.subheadline)
              .frame(width: 60, alignment: .leading)
            Spacer()
            Stepper(value: Binding(
              get: { store.count(for: species) },
              set: { store.setCount($0, for: species) }
            ), in: 0...5) {
              Text("\(store.count(for: species))")
                .monospacedDigit()
                .frame(width: 24, alignment: .trailing)
            }
            .fixedSize()
          }
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .controlBackgroundColor)))
        }
      }

      HStack {
        Text("총 \(store.totalCount) 마리")
          .font(.caption)
          .foregroundStyle(.secondary)
        Spacer()
        Button {
          for sp in PetSpecies.allCases { store.setCount(0, for: sp) }
        } label: {
          Label("모두 없애기", systemImage: "trash").font(.caption)
        }
        .buttonStyle(.borderless)
        .disabled(store.totalCount == 0)
      }
    }
    .padding(14)
    .frame(width: 300)
  }
}
