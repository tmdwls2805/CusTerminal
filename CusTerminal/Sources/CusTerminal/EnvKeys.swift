import SwiftUI

/// 현재 창의 LayoutStore 를 자식 뷰에서 참조하기 위한 환경값.
/// (팔레트/폰트 팝오버의 "기본값으로 되돌리기" 가 세션 오버라이드를 지울 때 사용)
struct CurrentLayoutStoreKey: EnvironmentKey {
  static let defaultValue: LayoutStore? = nil
}

extension EnvironmentValues {
  var currentLayoutStore: LayoutStore? {
    get { self[CurrentLayoutStoreKey.self] }
    set { self[CurrentLayoutStoreKey.self] = newValue }
  }
}
