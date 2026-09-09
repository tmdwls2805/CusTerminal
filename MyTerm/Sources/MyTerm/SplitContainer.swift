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
      let n = max(1, items.count)
      let total = isVerticalTotal(split: split)
      let each = total / CGFloat(n)
      for (i, item) in items.enumerated() {
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
        // 균등 초기 크기.
        if split.isVertical {
          host.view.frame = NSRect(x: CGFloat(i) * each, y: 0, width: each, height: split.bounds.height)
        } else {
          host.view.frame = NSRect(x: 0, y: CGFloat(i) * each, width: split.bounds.width, height: each)
        }
        split.addArrangedSubview(host.view)
      }
      hosts = newHosts
      split.adjustSubviews()
    }

    private func isVerticalTotal(split: NSSplitView) -> CGFloat {
      let bounds = split.bounds
      return split.isVertical ? max(bounds.width, 1) : max(bounds.height, 1)
    }

    // MARK: - NSSplitViewDelegate: 크기 제약을 명시해줘야 divider 가 자유롭게 움직임.

    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
      // 각 pane 최소 60px 확보.
      return proposedMinimumPosition + 60
    }

    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
      return proposedMaximumPosition - 60
    }

    func splitView(_ splitView: NSSplitView, resizeSubviewsWithOldSize oldSize: NSSize) {
      // 기본 균등 리사이즈 사용.
      splitView.adjustSubviews()
    }
  }
}
