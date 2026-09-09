import Foundation
import SwiftUI

/// 전체 pane 트리(열 배열) + 조작 API. 뷰들이 여기에 대해서만 mutate 한다.
/// - remove: 특정 pane 제거 (열 비면 열도 제거)
/// - splitVertical:   pane 을 같은 열 안에서 아래에 하나 더 (세로 분할)
/// - splitHorizontal: pane 을 오른쪽으로 새 열로 (가로 분할)
/// - move: 드래그 앤 드롭으로 pane 을 다른 위치로 옮김 (같은 세션 유지)
/// - detach: pane 을 새 창으로 분리 (호출한 쪽에서 새 window 를 연다)
final class LayoutStore: ObservableObject {
  @Published var columns: [TerminalColumn]

  init(columns: [TerminalColumn] = []) {
    self.columns = columns
  }

  // MARK: - 조회

  /// 세션이 속한 (열 index, 행 index) 찾기.
  func locate(_ sessionID: UUID) -> (col: Int, row: Int)? {
    for (c, column) in columns.enumerated() {
      if let r = column.sessions.firstIndex(where: { $0.id == sessionID }) {
        return (c, r)
      }
    }
    return nil
  }

  // MARK: - 변경

  func remove(_ sessionID: UUID) {
    guard let (c, r) = locate(sessionID) else { return }
    columns[c].sessions.remove(at: r)
    if columns[c].sessions.isEmpty {
      columns.remove(at: c)
    }
    objectWillChange.send()
  }

  /// 같은 열 안에서 아래에 새 pane.
  func splitVertical(after sessionID: UUID) {
    guard let (c, r) = locate(sessionID) else { return }
    columns[c].sessions.insert(TerminalSession(), at: r + 1)
    objectWillChange.send()
  }

  /// 오른쪽에 새 열(단일 pane) 추가.
  func splitHorizontal(after sessionID: UUID) {
    guard let (c, _) = locate(sessionID) else { return }
    columns.insert(TerminalColumn(sessions: [TerminalSession()]), at: c + 1)
    objectWillChange.send()
  }

  /// source pane 을 target pane 이 있는 열의 target 자리 앞/뒤로 옮김.
  /// - dropBefore: true 면 target 위, false 면 아래로 삽입.
  func move(source sourceID: UUID, target targetID: UUID, dropBefore: Bool) {
    guard sourceID != targetID,
          let src = locate(sourceID),
          let dst = locate(targetID)
    else { return }
    let session = columns[src.col].sessions.remove(at: src.row)

    // 재계산 필요: 위 remove 로 dst 인덱스가 밀렸을 수 있음.
    // 같은 열에서 src 가 dst 보다 앞이면 dst.row -= 1.
    var dstRow = dst.row
    var dstCol = dst.col
    if src.col == dst.col && src.row < dst.row {
      dstRow -= 1
    }
    // src 열이 dst 열보다 앞이었고 src 열이 비어서 제거됐다면 dstCol -= 1.
    if columns[src.col].sessions.isEmpty {
      columns.remove(at: src.col)
      if src.col < dstCol { dstCol -= 1 }
    }

    let insertAt = dropBefore ? dstRow : dstRow + 1
    columns[dstCol].sessions.insert(session, at: min(insertAt, columns[dstCol].sessions.count))
    objectWillChange.send()
  }

  /// pane 을 트리에서 떼어냄. 세션 객체 자체를 반환 → 호출자가 새 창에 붙임.
  @discardableResult
  func detach(_ sessionID: UUID) -> TerminalSession? {
    guard let (c, r) = locate(sessionID) else { return nil }
    let session = columns[c].sessions.remove(at: r)
    if columns[c].sessions.isEmpty {
      columns.remove(at: c)
    }
    objectWillChange.send()
    return session
  }
}
