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

  /// 이 스토어 안 모든 세션 (평탄화).
  var allSessions: [TerminalSession] { columns.flatMap(\.sessions) }

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

  /// 드롭 위치 (target pane 기준 어느 쪽에 놓았는지).
  enum DropEdge {
    case top     // 같은 열 안에서 target 위
    case bottom  // 같은 열 안에서 target 아래
    case left    // target 열 왼쪽에 새 열
    case right   // target 열 오른쪽에 새 열
  }

  /// source pane 을 target pane 기준 4방향(top/bottom/left/right)으로 옮김.
  /// - top/bottom: target 이 있는 열에 삽입 → 세로 정렬
  /// - left/right: target 열의 옆에 단일 pane 짜리 새 열 → 가로 정렬
  func move(source sourceID: UUID, target targetID: UUID, edge: DropEdge) {
    guard sourceID != targetID,
          let src = locate(sourceID),
          let dst = locate(targetID)
    else { return }

    // source 를 먼저 떼어냄.
    let session = columns[src.col].sessions.remove(at: src.row)
    var dstCol = dst.col
    var dstRow = dst.row

    // remove 로 인해 target 인덱스가 밀렸는지 보정.
    if src.col == dst.col && src.row < dst.row {
      dstRow -= 1
    }
    let srcColRemoved = columns[src.col].sessions.isEmpty
    if srcColRemoved {
      columns.remove(at: src.col)
      if src.col < dstCol { dstCol -= 1 }
    }

    switch edge {
    case .top:
      columns[dstCol].sessions.insert(session, at: dstRow)
    case .bottom:
      columns[dstCol].sessions.insert(session, at: dstRow + 1)
    case .left:
      columns.insert(TerminalColumn(sessions: [session]), at: dstCol)
    case .right:
      columns.insert(TerminalColumn(sessions: [session]), at: dstCol + 1)
    }
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
