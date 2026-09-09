import SwiftUI
import AppKit

/// SwiftUI 뷰 하나 + 안정적인 id.
struct SplitItem: Identifiable {
  let id: UUID
  let view: AnyView
}

/// 자식들을 각각 별도 NSSplitView subview 로 붙여서 divider 로 크기 조절 가능하게 한다.
/// - isVertical=true → 좌우 분할 (열 배열)
/// - isVertical=false → 상하 분할 (한 열 안 pane 들)
struct SplitContainer: NSViewRepresentable {
  let isVertical: Bool
  let items: [SplitItem]

  func makeNSView(context: Context) -> NSSplitView {
    let split = NSSplitView()
    split.isVertical = isVertical
    split.dividerStyle = .thin
    split.arrangesAllSubviews = false
    split.delegate = context.coordinator
    context.coordinator.sync(split: split, isVertical: isVertical, items: items)
    return split
  }

  func updateNSView(_ nsView: NSSplitView, context: Context) {
    nsView.isVertical = isVertical
    context.coordinator.sync(split: nsView, isVertical: isVertical, items: items)
  }

  func makeCoordinator() -> Coordinator { Coordinator() }

  final class Coordinator: NSObject, NSSplitViewDelegate {
    // id → hosting controller. 같은 세션 pane 은 controller 재사용해서 PTY(NSView) 유지.
    private var hosts: [UUID: NSHostingController<AnyView>] = [:]

    func sync(split: NSSplitView, isVertical: Bool, items: [SplitItem]) {
      let wantedIDs = items.map(\.id)
      let currentIDs = split.arrangedSubviews.compactMap { view -> UUID? in
        hosts.first(where: { $0.value.view === view })?.key
      }

      // 순서/구성이 같으면 rootView 만 새로 바인딩하고 끝.
      if currentIDs == wantedIDs {
        for item in items {
          hosts[item.id]?.rootView = item.view
        }
        return
      }

      // 재구성: 기존 subview 는 떼고, 필요한 host 는 만들거나 재사용해서 순서대로 붙임.
      // NSSplitView 는 arrangedSubviews 를 자기가 프레임 잡으므로
      // translatesAutoresizingMaskIntoConstraints=true (기본값) 유지.
      for view in split.arrangedSubviews {
        split.removeArrangedSubview(view)
        view.removeFromSuperview()
      }

      var newHosts: [UUID: NSHostingController<AnyView>] = [:]
      for item in items {
        let host: NSHostingController<AnyView>
        if let existing = hosts[item.id] {
          existing.rootView = item.view
          host = existing
        } else {
          host = NSHostingController(rootView: item.view)
        }
        newHosts[item.id] = host
        host.view.translatesAutoresizingMaskIntoConstraints = true
        host.view.autoresizingMask = [.width, .height]
        split.addArrangedSubview(host.view)
      }
      hosts = newHosts
      // bounds 가 확정된 다음 프레임 균등 분배. makeNSView 시점엔 bounds=0 이라
      // 나중에 layout 이 잡힐 때 다시 균등화되도록 한 번 더 예약.
      distributeEvenly(split: split)
      DispatchQueue.main.async { [weak split] in
        guard let split else { return }
        self.distributeEvenly(split: split)
      }
    }

    /// arrangedSubviews 를 완전히 균등 크기로 강제.
    private func distributeEvenly(split: NSSplitView) {
      let subs = split.arrangedSubviews
      guard !subs.isEmpty else { return }
      let dividerThickness = split.dividerThickness
      let total = split.isVertical ? split.bounds.width : split.bounds.height
      guard total > 0 else { return }
      let usable = max(0, total - dividerThickness * CGFloat(subs.count - 1))
      let each = usable / CGFloat(subs.count)
      for (i, sub) in subs.enumerated() {
        if split.isVertical {
          sub.frame = NSRect(
            x: CGFloat(i) * (each + dividerThickness),
            y: 0,
            width: each,
            height: split.bounds.height
          )
        } else {
          // NSSplitView 는 상하 분할이라도 좌표계가 좌하단 원점.
          // 위→아래 순서로 배치되게 하려면 첫 subview 가 y 가 큰 위쪽에.
          let y = split.bounds.height - CGFloat(i + 1) * each - CGFloat(i) * dividerThickness
          sub.frame = NSRect(
            x: 0,
            y: y,
            width: split.bounds.width,
            height: each
          )
        }
      }
      split.adjustSubviews()
    }

    // MARK: - NSSplitViewDelegate

    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
      return proposedMinimumPosition + 60
    }

    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
      return proposedMaximumPosition - 60
    }
    // resizeSubviews 는 오버라이드 안 함 → 창 리사이즈 시 기존 비율 유지 (NSSplitView 기본 동작).
  }
}
