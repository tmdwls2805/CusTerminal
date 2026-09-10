import SwiftUI

/// 사이드바 하단 창 투명도 진입 버튼.
struct WindowOpacityButton: View {
  @Environment(WindowOpacityStore.self) private var store
  @State private var show: Bool = false

  var body: some View {
    Button {
      show.toggle()
    } label: {
      HStack(spacing: 8) {
        Image(systemName: store.opacity < 1.0 ? "circle.lefthalf.filled" : "circle.fill")
          .foregroundStyle(store.opacity < 1.0 ? Color.accentColor : .secondary)
        VStack(alignment: .leading, spacing: 0) {
          Text("창 투명도").font(.system(size: 12))
          Text("\(Int(store.opacity * 100))%")
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
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
      WindowOpacityPopover()
    }
    .tooltip("창 투명도 (모든 창에 동일 적용). 100% = 불투명, 40% = 많이 투명")
  }
}

struct WindowOpacityPopover: View {
  @Environment(WindowOpacityStore.self) private var store

  var body: some View {
    @Bindable var s = store
    VStack(alignment: .leading, spacing: 10) {
      Text("창 투명도").font(.headline)
      Text("모든 창에 즉시 반영. 뒤 화면이 살짝 비치게.")
        .font(.caption)
        .foregroundStyle(.secondary)

      HStack(spacing: 8) {
        Text("\(Int(s.opacity * 100))%")
          .frame(width: 44, alignment: .trailing)
          .monospacedDigit()
        Slider(value: $s.opacity, in: 0.4...1.0)
      }

      HStack {
        Spacer()
        Button {
          s.opacity = 1.0
        } label: {
          Label("100% 로 되돌리기", systemImage: "arrow.uturn.backward")
            .font(.caption)
        }
        .buttonStyle(.borderless)
      }
    }
    .padding(14)
    .frame(width: 300)
  }
}
